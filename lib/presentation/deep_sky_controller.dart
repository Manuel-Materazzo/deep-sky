import 'dart:async';
import 'dart:io' show Platform, SocketException;

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/data/apk_update_service.dart';
import 'package:deep_sky/data/content_pack_service.dart';
import 'package:deep_sky/data/couple_api_client.dart';
import 'package:deep_sky/data/encrypted_local_cache.dart';
import 'package:deep_sky/data/pairing_and_sync_repository.dart';
import 'package:deep_sky/data/push_api_client.dart';
import 'package:deep_sky/data/scene_manifest_parser.dart';
import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/domain/content/content_pack_models.dart';
import 'package:deep_sky/domain/crypto/deep_sky_crypto.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';
import 'package:deep_sky/domain/pairing/invite_link_codec.dart';
import 'package:deep_sky/domain/platform_capabilities.dart';
import 'package:deep_sky/domain/push_models.dart';
import 'package:deep_sky/domain/update/apk_update_models.dart';
import 'package:deep_sky/platform/native_bridge.dart';
import 'package:deep_sky/presentation/l10n/deep_sky_strings.dart';
import 'package:deep_sky/scene/asset_override_registry.dart';
import 'package:deep_sky/scene/local_scene_view_state.dart';
import 'package:deep_sky/scene/scene_manifest.dart';
import 'package:deep_sky/scene/scene_state_mapper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

enum AppBootPhase { loading, unpaired, waiting, paired, upgradeRequired }

/// Application-wide state coordinator for M2 flows:
/// pairing (`F-01`), recovery (`F-20`), thinking-of-you (`F-03`),
/// offline read-only fallback (`TC-07`), push (`SP-01`), and APK updates (`F-19`).
class DeepSkyController extends ChangeNotifier {
  DeepSkyController({
    SecureKeyStore? keyStore,
    DeepSkyCrypto? crypto,
    http.Client? httpClient,
    NativeBridge? nativeBridge,
    ContentPackService? contentPackService,
    Map<String, SimplePublicKey>? trustedContentPublicKeys,
    DateTime Function()? clockUtc,
    DateTime Function()? clockLocal,
    this._manifestParser = const SceneManifestParser(),
    this._sceneStateMapper = const SceneStateMapper(),
    Future<String> Function(String path)? loadAssetString,
    Future<PlatformCapabilities> Function()? loadCapabilities,
    int? clientVersionCode,
    this.protocolVersion = 1,
    this.defaultServerUrl = 'https://deepsky.vectevo.com',
    this.defaultUpdateSource = 'Manuel-Materazzo/deep-sky',
    this.trustedUpdatePublicKeyB64 =
        'MCowBQYDK2VwAyEAHDblTk6u65qfWgGXDDULNtIsR9JrXd1u4Pc6y7+Z+WM=',
    this.inviteAutoPollInterval = const Duration(seconds: 3),
    this.enableSkyRefreshTimer = true,
    this.thoughtSentBannerDuration = const Duration(seconds: 8),
  }) : _hasCustomNativeBridge = nativeBridge != null,
       _nativeBridge = nativeBridge ?? const NativeBridge(),
       _httpClient = httpClient ?? http.Client(),
       _loadAssetString = loadAssetString ?? rootBundle.loadString,
       _loadCapabilitiesOverride = loadCapabilities,
       _clientVersionCodeOverride = clientVersionCode,
       _clockUtc = clockUtc ?? (() => DateTime.now().toUtc()),
       _clockLocal = clockLocal ?? DateTime.now {
    final SecureKeyStore resolvedKeyStore = keyStore ?? FlutterSecureKeyStore();
    _keyStore = resolvedKeyStore;
    _crypto = crypto ?? DeepSkyCrypto();
    _localSceneStore = LocalSceneViewStateStore(resolvedKeyStore);
    _repository = PairingAndSyncRepository(
      keyStore: resolvedKeyStore,
      crypto: _crypto,
      clientFactory: _createApiClient,
      localCache: EncryptedLocalCache(
        keyStore: resolvedKeyStore,
        resolveCacheRootDir: _canQueryNativeChannels
            ? _nativeBridge.getOfflineCacheRootDir
            : null,
      ),
    );
    _updateService = ApkUpdateService(
      httpClient: _httpClient,
      nativeBridge: _nativeBridge,
    );
    _contentPackService =
        contentPackService ??
        ContentPackService(
          keyStore: resolvedKeyStore,
          trustedPublicKeys:
              trustedContentPublicKeys ??
              <String, SimplePublicKey>{
                'v1': ApkUpdateService.parseEd25519PublicKey(
                  trustedUpdatePublicKeyB64,
                ),
              },
          httpClient: _httpClient,
          manifestParser: _manifestParser,
          resolveStorageRootDir: _canQueryNativeChannels
              ? _nativeBridge.getContentPackRootDir
              : null,
          isConnectionUnmetered: _canQueryNativeChannels
              ? _nativeBridge.isConnectionUnmetered
              : null,
          appProtocolVersion: protocolVersion,
          clientVersionCode: clientVersionCode ?? 1,
        );
  }

  static const String _updateChannelStorageKey = 'deepsky.update.channel';
  static const String _pushPromptDismissedStorageKey =
      'deepsky.push.prompt_dismissed';
  static const String homePackManifestPath = 'content/packs/v1/manifest.json';
  static const String homePackAssetRoot = 'content/packs/v1';
  static const String pilotManifestPath =
      'content/packs/ds2_pilot/manifest.json';
  static const String pilotAssetRoot = 'content/packs/ds2_pilot';

  final http.Client _httpClient;
  final bool _hasCustomNativeBridge;
  final NativeBridge _nativeBridge;

  bool get _canQueryNativeChannels =>
      _hasCustomNativeBridge || (!kIsWeb && Platform.isAndroid);
  final SceneManifestParser _manifestParser;
  final SceneStateMapper _sceneStateMapper;
  final Future<String> Function(String path) _loadAssetString;
  final Future<PlatformCapabilities> Function()? _loadCapabilitiesOverride;
  final int? _clientVersionCodeOverride;
  final DateTime Function() _clockUtc;

  /// Current UTC instant from the injectable controller clock (deterministic in tests).
  DateTime get nowUtc => _clockUtc();
  final DateTime Function() _clockLocal;
  DateTime get nowLocal => _clockLocal();
  final bool enableSkyRefreshTimer;
  final Duration thoughtSentBannerDuration;

  /// Effective Android `versionCode` sent in API compatibility headers.
  ///
  /// Uses the runtime value loaded from native [PlatformCapabilities] unless
  /// explicitly overridden (for example in tests).
  int get clientVersionCode =>
      _clientVersionCodeOverride ?? capabilities.versionCode;

  final int protocolVersion;
  final String defaultServerUrl;
  final String defaultUpdateSource;
  final String trustedUpdatePublicKeyB64;
  final Duration inviteAutoPollInterval;

  late final SecureKeyStore _keyStore;
  late final DeepSkyCrypto _crypto;
  late final LocalSceneViewStateStore _localSceneStore;
  late final PairingAndSyncRepository _repository;
  late final ApkUpdateService _updateService;
  late final ContentPackService _contentPackService;

  SceneManifest? _bundledManifest;
  String activePackAssetRoot = homePackAssetRoot;
  bool activePackIsFileSystem = false;
  bool contentPackUpdating = false;
  String? contentPackFeedback;
  String? contentPackRolledBackFrom;
  LocalSceneViewState localSceneViewState = const LocalSceneViewState();
  bool showWelcomeBackBanner = false;
  bool showThoughtSentBanner = false;
  String? lastSentThoughtNote;
  int thoughtSentBannerSequence = 0;

  String get activePackVersion => sceneManifest?.packVersion ?? '1.1.0';

  AppBootPhase phase = AppBootPhase.loading;
  bool busy = false;
  bool isOffline = false;
  bool isDeviceRevoked = false;
  int quarantinedEnvelopeCount = 0;
  bool isNight = true;
  bool reduceMotion = false;
  bool petOverrideActive = false;
  bool autoInviteAttempted = false;
  int onboardingTabIndex = 0;
  String languageCode = 'it';
  late String activeServerUrl = defaultServerUrl;
  String deviceLabel = 'Telefono principale';
  String? statusNotice;
  String? errorNotice;

  LocalDeviceIdentity? identity;
  CreateInviteResponse? activeInvite;
  InviteStatusResponse? activeInviteStatus;
  String? activeSasCode;
  PendingJoinSession? pendingJoin;
  String? _lastKnownPeerLabel;
  bool _autoPollInFlight = false;
  String? _suppressedAutoPollToken;
  List<CachedEventEntry> events = const <CachedEventEntry>[];
  List<DeviceSummary> devices = const <DeviceSummary>[];
  SceneManifest? sceneManifest;
  SceneStateSnapshot sceneState = const SceneStateSnapshot(
    slotStates: <String, String>{'window': 'calm'},
  );
  AssetOverrideRegistry assetOverrides = const AssetOverrideRegistry();

  PlatformCapabilities capabilities = const PlatformCapabilities(
    packageName: 'com.vectevo.deep_sky',
    androidApiLevel: 35,
    versionName: '1.0.0',
    versionCode: 1,
    supportsRequestInstallPackages: false,
  );
  CompatibilityPolicy? compatibilityPolicy;
  NativePushStatus? pushStatus;
  bool pushSupportedOnServer = false;
  bool pushPromptDismissed = false;
  String? pushFeedback;
  bool pushFeedbackIsError = false;
  UpdateChannel updateChannel = UpdateChannel.stable;
  bool allowCustomUpdateTrustAnchor = false;
  ApkReleaseManifest? availableUpdate;
  double? updateDownloadProgress;
  String? updateFeedback;
  String? pendingDeepLinkInvite;

  CoupleApiClient _createApiClient(String baseUrl) {
    return CoupleApiClient(
      baseUrl: baseUrl,
      httpClient: _httpClient,
      crypto: _crypto,
      clientVersionCode: clientVersionCode,
      protocolVersion: protocolVersion,
    );
  }

  Future<void> initialize() async {
    phase = AppBootPhase.loading;
    isOffline = false;
    isDeviceRevoked = false;
    errorNotice = null;
    notifyListeners();

    await _loadHomeScene();
    await _loadCapabilities();
    await _loadClientPreferences();
    _nativeBridge.setDeepLinkListener(handleIncomingDeepLink);
    _nativeBridge.setPushWakeupListener(handleForegroundPushWakeup);
    identity = await _repository.reconcilePendingRotation();
    activeServerUrl = identity?.serverUrl ?? defaultServerUrl;
    if (identity != null && identity!.deviceLabel.trim().isNotEmpty) {
      deviceLabel = identity!.deviceLabel;
    }

    if (identity == null || !identity!.hasCoupleRoot) {
      if (identity != null && !identity!.hasCoupleRoot) {
        await _repository.clearIdentity();
        identity = null;
      }
      await _checkCompatibility(activeServerUrl);
      if (phase != AppBootPhase.upgradeRequired) {
        phase = AppBootPhase.unpaired;
        if (_canQueryNativeChannels) {
          final String? launchDeepLink = await _nativeBridge
              .consumePendingDeepLink();
          if (launchDeepLink != null) {
            handleIncomingDeepLink(launchDeepLink);
          }
        }
      }
      notifyListeners();
      return;
    }

    if (!identity!.pairingCompleted) {
      activeInvite = await _repository.loadPendingInvite();
      autoInviteAttempted = activeInvite != null;
      await _checkCompatibility(identity!.serverUrl);
      if (phase != AppBootPhase.upgradeRequired) {
        phase = AppBootPhase.waiting;
      }
      notifyListeners();
      return;
    }

    await _checkCompatibility(identity!.serverUrl);
    if (phase == AppBootPhase.upgradeRequired) {
      notifyListeners();
      return;
    }

    await _resolveStartupContentPack();
    await _recordLocalHomeOpen();

    phase = AppBootPhase.paired;
    await _refreshPairedState();
    await _syncPendingRotatedPushToken();
    if (!isOffline && !isDeviceRevoked) {
      unawaited(checkContentPackInBackground());
    }
    notifyListeners();
  }

  Future<void> _loadHomeScene() async {
    try {
      final String raw = await _loadAssetString(homePackManifestPath);
      final SceneManifest parsed = _manifestParser.parseJson(raw);
      _bundledManifest = parsed;
      sceneManifest = parsed;
      activePackAssetRoot = parsed.packId == 'ds2-pilot-room'
          ? pilotAssetRoot
          : homePackAssetRoot;
      activePackIsFileSystem = false;
    } catch (_) {
      try {
        final String raw = await _loadAssetString(pilotManifestPath);
        final SceneManifest parsed = _manifestParser.parseJson(raw);
        _bundledManifest = parsed;
        sceneManifest = parsed;
        activePackAssetRoot = pilotAssetRoot;
        activePackIsFileSystem = false;
      } catch (_) {
        sceneManifest = null;
      }
    }
  }

  Future<void> _resolveStartupContentPack() async {
    final SceneManifest? bundled = _bundledManifest;
    if (bundled == null) {
      return;
    }
    try {
      final SemanticVersion? serverMin = SemanticVersion.tryParse(
        compatibilityPolicy?.minPackVersion,
      );
      final ResolvedContentPack resolved = await _contentPackService
          .resolveStartupPack(
            bundledManifest: bundled,
            bundledAssetRoot: activePackAssetRoot,
            serverMinPackVersion: serverMin,
          );
      sceneManifest = resolved.manifest;
      activePackAssetRoot = resolved.assetRootPath;
      activePackIsFileSystem = resolved.isFileSystem;
      contentPackRolledBackFrom = resolved.rolledBackFromVersion;
      if (resolved.rolledBackFromVersion != null) {
        contentPackFeedback = DeepSkyStrings(languageCode)
            .settingsGraphicsRolledBack(resolved.rolledBackFromVersion!);
      }
    } catch (_) {
      // Fall back safely to bundled manifest.
    }
  }

  Future<void> _recordLocalHomeOpen() async {
    final DateTime nowUtc = _clockUtc();
    showWelcomeBackBanner = localSceneViewState.shouldShowWelcomeBack(nowUtc);
    localSceneViewState = localSceneViewState.copyWith(
      lastOpenedAtLocal: nowUtc,
    );
    await _localSceneStore.save(localSceneViewState);
  }

  Future<void> _loadClientPreferences() async {
    try {
      updateChannel = UpdateChannel.fromStorage(
        await _keyStore.read(_updateChannelStorageKey),
      );
      pushPromptDismissed =
          (await _keyStore.read(_pushPromptDismissedStorageKey)) == 'true';
      localSceneViewState = await _localSceneStore.load();
    } catch (_) {
      // Fall back to safe defaults if preferences are unavailable.
    }
  }

  /// Parses an incoming invite deep-link (`https://.../join#...` or `deepsky://pair#...`)
  /// and pre-fills the Join flow without switching [activeServerUrl] until confirmed (`S1-APP-01`, `CA-06`).
  void handleIncomingDeepLink(String rawUri) {
    final parsed = InviteLinkCodec.parseInviteInputChecked(rawUri);
    if (parsed.inviteToken.isEmpty) {
      return;
    }
    if (phase == AppBootPhase.paired || phase == AppBootPhase.waiting) {
      return;
    }
    pendingDeepLinkInvite = rawUri.trim();
    onboardingTabIndex = 1;
    errorNotice = parsed.rejectedServerError != null
        ? DeepSkyStrings(languageCode).customServerInsecureError
        : null;
    notifyListeners();
  }

  String? takePendingDeepLinkInvite() {
    final String? value = pendingDeepLinkInvite;
    pendingDeepLinkInvite = null;
    return value;
  }

  Future<void> _loadCapabilities() async {
    try {
      final Future<PlatformCapabilities> Function() loader =
          _loadCapabilitiesOverride ?? _nativeBridge.getPlatformCapabilities;
      capabilities = await loader();
    } catch (_) {
      // Desktop / headless widget tests run without Android platform channels.
    }
  }

  Future<void> _checkCompatibility(String serverUrl) async {
    try {
      final CompatibilityPolicy policy = await _createApiClient(serverUrl)
          .fetchCompatibilityPolicy();
      compatibilityPolicy = policy;
      if (clientVersionCode < policy.minClientVersionCode ||
          protocolVersion < policy.minProtocolVersion) {
        phase = AppBootPhase.upgradeRequired;
      }
    } on ClientUpgradeRequiredException catch (ex) {
      compatibilityPolicy = CompatibilityPolicy(
        minClientVersionCode: ex.minClientVersionCode,
        minProtocolVersion: ex.minProtocolVersion,
      );
      phase = AppBootPhase.upgradeRequired;
    } catch (_) {
      // Network unreachable on boot: handled gracefully in offline fallback.
    }
  }

  Future<void> _refreshPairedState() async {
    if (identity == null) {
      return;
    }
    if (!identity!.hasCoupleRoot) {
      events = const <CachedEventEntry>[];
      sceneState = const SceneStateSnapshot(
        slotStates: <String, String>{'window': 'calm'},
      );
      return;
    }
    try {
      final SyncEventsSnapshot snap = await _repository
          .syncEventsWithOfflineFallback();
      identity = (await _repository.loadIdentity()) ?? identity;
      events = snap.events;
      isOffline = snap.isOffline;
      quarantinedEnvelopeCount = snap.quarantinedEnvelopes.length;
      if (!isOffline) {
        isDeviceRevoked = false;
      }
      if (quarantinedEnvelopeCount > 0) {
        errorNotice = DeepSkyStrings(languageCode)
            .unreadableEnvelopesNotice(quarantinedEnvelopeCount);
      }
      _recomputeSceneState();
      if (!isOffline) {
        try {
          devices = await _repository.listDevices();
        } on ApiRequestException catch (ex) {
          if (ex.isDeviceUnknownOrRevoked) {
            isDeviceRevoked = true;
            errorNotice = null;
          }
        } catch (_) {
          // Non-fatal: keep cached devices list.
        }
      }
    } on ClientUpgradeRequiredException catch (ex) {
      compatibilityPolicy = CompatibilityPolicy(
        minClientVersionCode: ex.minClientVersionCode,
        minProtocolVersion: ex.minProtocolVersion,
      );
      phase = AppBootPhase.upgradeRequired;
    } on ApiRequestException catch (ex) {
      if (ex.isDeviceUnknownOrRevoked) {
        isDeviceRevoked = true;
        isOffline = false;
        errorNotice = null;
        await _loadCachedEventsBestEffort();
      } else {
        errorNotice = _friendlyErrorMessage(ex);
      }
    } catch (error) {
      errorNotice = _friendlyErrorMessage(error);
    }
  }

  Future<void> _loadCachedEventsBestEffort() async {
    try {
      events = await _repository.loadCachedEvents();
      _recomputeSceneState();
    } catch (_) {
      // Keep existing in-memory events if cache cannot be loaded.
    }
  }

  Future<void> _syncPendingRotatedPushToken() async {
    final LocalDeviceIdentity? current = identity;
    if (current == null || isOffline) {
      return;
    }
    try {
      final RuntimeFirebaseConfig cfg = await PushApiClient(
        apiClient: _createApiClient(current.serverUrl),
      ).fetchRuntimeConfig();
      pushSupportedOnServer = cfg.enabled && cfg.isComplete;
    } catch (_) {
      pushSupportedOnServer = false;
    }
    if (_canQueryNativeChannels) {
      try {
        pushStatus = await _nativeBridge.getPushStatus();
        final String? rotated = await _nativeBridge.consumePendingPushToken();
        if (rotated != null && rotated.isNotEmpty) {
          await PushApiClient(apiClient: _createApiClient(current.serverUrl))
              .registerToken(identity: current, fcmToken: rotated);
          pushStatus = await _nativeBridge.getPushStatus();
        }
      } catch (_) {
        // Desktop / test mode or offline: skip quietly.
      }
    }
  }

  void _recomputeSceneState() {
    final String deviceId = identity?.deviceId ?? '';
    final String coupleId = identity?.coupleId ?? '';
    sceneState = _sceneStateMapper.derive(
      events: events,
      localDeviceId: deviceId,
      coupleId: coupleId,
      localViewState: localSceneViewState,
      nowUtc: _clockUtc(),
      nowLocal: _clockLocal(),
    );
  }

  /// Recomputes the local sky band across midnight or timezone changes (`S2-CTR-02`, `S2-APP-03`).
  void refreshLocalSkyPeriod() {
    final SkyPeriod prev = sceneState.skyPeriod;
    _recomputeSceneState();
    if (sceneState.skyPeriod != prev) {
      notifyListeners();
    }
  }

  Future<void> setSkyPreference(SkyTimePreference pref) async {
    localSceneViewState = localSceneViewState.copyWith(skyPreference: pref);
    await _localSceneStore.save(localSceneViewState);
    if (pref == SkyTimePreference.day) {
      isNight = false;
    } else if (pref == SkyTimePreference.night) {
      isNight = true;
    }
    _recomputeSceneState();
    notifyListeners();
  }

  void dismissWelcomeBackBanner() {
    if (!showWelcomeBackBanner) {
      return;
    }
    showWelcomeBackBanner = false;
    notifyListeners();
  }

  void dismissThoughtSentBanner() {
    if (!showThoughtSentBanner) {
      return;
    }
    showThoughtSentBanner = false;
    lastSentThoughtNote = null;
    notifyListeners();
  }

  /// Marks the latest partner thought as seen strictly on this device (`P-07`, `S-05`).
  Future<void> markLatestPartnerThoughtSeen() async {
    final CachedEventEntry? unseen = sceneState.unseenPartnerThought;
    if (unseen == null) {
      return;
    }
    await _markPartnerThoughtSeen(unseen);
  }

  Future<void> _markPartnerThoughtSeen(CachedEventEntry unseen) async {
    final int nextSeq =
        unseen.seq != null && unseen.seq! > localSceneViewState.lastSeenEventSeq
        ? unseen.seq!
        : localSceneViewState.lastSeenEventSeq;
    localSceneViewState = localSceneViewState.copyWith(
      lastSeenEventSeq: nextSeq,
      lastSeenThoughtEnvelopeId: unseen.envelopeId,
    );
    await _localSceneStore.save(localSceneViewState);
    _recomputeSceneState();
    notifyListeners();
  }

  /// Sends a reciprocal "Ti penso" gesture (with optional short note) and marks
  /// the incoming partner thought as seen locally (`F-03`, `S2-APP-03`).
  Future<void> replyToPartnerThought({String? note}) async {
    final CachedEventEntry? unseen = sceneState.unseenPartnerThought;
    await sendThinkingOfYou(note: note);
    if (errorNotice == null && unseen != null) {
      await _markPartnerThoughtSeen(unseen);
    }
  }

  /// Resets `packBootAttempts` once the first frame that exercises (or deliberately
  /// bypasses) the scene has rendered: Home, or a paired pre-Home page such as space/recovery
  /// setup that never draws the pack, so those boots are not counted as failures (`S2-APP-02`).
  Future<void> markHomeBootSucceeded() =>
      _contentPackService.markHomeBootSucceeded();

  /// Silently checks for signed graphics updates on unmetered networks and stages
  /// them for the next launch (`S2-APP-02`).
  Future<void>? _bgPackCheckFuture;
  DateTime? _lastSilentSyncUtc;
  bool _silentSyncInFlight = false;
  int _secureScreenRefCount = 0;

  /// Reference-counted `FLAG_SECURE` acquisition (`AU-24`) so popping a nested
  /// sensitive page never disables screen protection while another sensitive
  /// page remains visible underneath.
  Future<void> acquireSecureScreen() async {
    _secureScreenRefCount++;
    if (_secureScreenRefCount == 1) {
      await _nativeBridge.setSecureScreen(true);
    }
  }

  Future<void> releaseSecureScreen() async {
    if (_secureScreenRefCount <= 0) {
      _secureScreenRefCount = 0;
      return;
    }
    _secureScreenRefCount--;
    if (_secureScreenRefCount == 0) {
      await _nativeBridge.setSecureScreen(false);
    }
  }

  /// Throttled silent sync triggered on app resume or foreground push wakeup (`AU-18`).
  Future<void> syncOnResumeSilently({bool force = false}) async {
    if (phase != AppBootPhase.paired ||
        identity == null ||
        !identity!.hasCoupleRoot ||
        busy ||
        isDeviceRevoked ||
        _silentSyncInFlight) {
      return;
    }
    final DateTime now = _clockUtc();
    if (!force &&
        _lastSilentSyncUtc != null &&
        now.difference(_lastSilentSyncUtc!) < const Duration(seconds: 10)) {
      return;
    }
    _silentSyncInFlight = true;
    _lastSilentSyncUtc = now;
    try {
      await _refreshPairedState();
      notifyListeners();
    } catch (_) {
      // Silent resume sync never surfaces intrusive errors.
    } finally {
      _silentSyncInFlight = false;
    }
  }

  /// Handles a foreground FCM data-only wakeup forwarded by Android (`AU-18`).
  void handleForegroundPushWakeup(String l10nKey) {
    unawaited(refreshPushStatus());
    if (l10nKey == 'wakeup.pairing_request') {
      unawaited(pollActiveInviteSilently());
    } else {
      unawaited(syncOnResumeSilently(force: true));
    }
  }

  Future<void> checkContentPackInBackground() {
    if (_bgPackCheckFuture != null) {
      return _bgPackCheckFuture!;
    }
    final Future<void> run = _runBackgroundContentPackCheck();
    _bgPackCheckFuture = run.whenComplete(() {
      if (identical(_bgPackCheckFuture, run)) {
        _bgPackCheckFuture = null;
      }
    });
    return _bgPackCheckFuture!;
  }

  Future<void> _runBackgroundContentPackCheck() async {
    final LocalDeviceIdentity? current = identity;
    final SceneManifest? bundled = _bundledManifest;
    final SceneManifest? active = sceneManifest;
    if (current == null || bundled == null || active == null) {
      return;
    }
    try {
      final ContentPackUpdateResult res = await _contentPackService
          .syncFromServer(
            serverBaseUrl: current.serverUrl,
            bundledPackVersion: SemanticVersion.parse(bundled.packVersion),
            currentActivePackVersion: SemanticVersion.parse(active.packVersion),
            serverMinPackVersion: SemanticVersion.tryParse(
              compatibilityPolicy?.minPackVersion,
            ),
            manualForce: false,
          );
      if (res.status == ContentPackUpdateStatus.stagedForNextBoot &&
          res.packVersion != null) {
        contentPackFeedback = DeepSkyStrings(languageCode)
            .settingsGraphicsStagedNextLaunch(res.packVersion!);
        notifyListeners();
      }
    } catch (_) {
      // Silent background sync never surfaces intrusive errors.
    }
  }

  /// Forces an immediate file-by-file content pack download (even on metered networks),
  /// evicts previous textures from `imageCache`, and hot-reloads the Home scene (`S2-D09`, `S2-APP-02`).
  Future<void> forceUpdateContentPack() async {
    final LocalDeviceIdentity? current = identity;
    final SceneManifest? bundled = _bundledManifest;
    final SceneManifest? active = sceneManifest;
    if (current == null || bundled == null || active == null) {
      return;
    }
    final DeepSkyStrings s = DeepSkyStrings(languageCode);
    contentPackUpdating = true;
    contentPackFeedback = null;
    notifyListeners();
    try {
      // AU-07: Join any in-flight startup check before running a manual sync.
      final Future<void>? inFlightBg = _bgPackCheckFuture;
      if (inFlightBg != null) {
        try {
          await inFlightBg;
        } catch (_) {}
      }
      final ContentPackUpdateResult res = await _contentPackService
          .syncFromServer(
            serverBaseUrl: current.serverUrl,
            bundledPackVersion: SemanticVersion.parse(bundled.packVersion),
            currentActivePackVersion: SemanticVersion.parse(active.packVersion),
            serverMinPackVersion: SemanticVersion.tryParse(
              compatibilityPolicy?.minPackVersion,
            ),
            manualForce: true,
          );
      switch (res.status) {
        case ContentPackUpdateStatus.activatedHotReload:
          final ResolvedContentPack? nextPack = res.resolvedPack;
          if (nextPack != null) {
            // Cached providers are wrapped in ResizeImage with size-dependent keys,
            // so dropping the whole cache (and live images) is the reliable eviction.
            PaintingBinding.instance.imageCache
              ..clear()
              ..clearLiveImages();
            sceneManifest = nextPack.manifest;
            activePackAssetRoot = nextPack.assetRootPath;
            activePackIsFileSystem = nextPack.isFileSystem;
            contentPackFeedback = s.settingsGraphicsUpdatedHotReload(
              nextPack.packVersion,
            );
          }
        case ContentPackUpdateStatus.upToDate:
        case ContentPackUpdateStatus.notModified304:
          contentPackFeedback = s.settingsGraphicsUpToDate;
        case ContentPackUpdateStatus.unavailable:
          contentPackFeedback = s.settingsGraphicsUnavailable;
        case ContentPackUpdateStatus.stagedForNextBoot:
          contentPackFeedback = s.settingsGraphicsStagedNextLaunch(
            res.packVersion ?? activePackVersion,
          );
        case ContentPackUpdateStatus.skippedMeteredNetwork:
          contentPackFeedback = s.settingsGraphicsUpToDate;
      }
    } on ContentPackException catch (ex) {
      contentPackFeedback = ex.localizedMessage(languageCode);
    } catch (error) {
      contentPackFeedback = _friendlyErrorMessage(error);
    } finally {
      contentPackUpdating = false;
      notifyListeners();
    }
  }

  bool get isCustomServer =>
      InviteLinkCodec.displayHost(activeServerUrl).toLowerCase() !=
      InviteLinkCodec.displayHost(defaultServerUrl).toLowerCase();

  bool get needsCodeVerification =>
      (phase == AppBootPhase.unpaired || phase == AppBootPhase.waiting) &&
      (pendingJoin != null || activeSasCode != null);

  bool get needsSpaceSetup =>
      phase == AppBootPhase.paired &&
      identity != null &&
      !identity!.nameSetupCompleted &&
      !isDeviceRevoked;

  bool get needsRecoveryKeySetup =>
      phase == AppBootPhase.paired &&
      identity != null &&
      identity!.nameSetupCompleted &&
      !identity!.recoverySavedConfirmed &&
      identity!.recoverySeed != null &&
      !isDeviceRevoked;

  bool get shouldShowPushOptInPrompt =>
      phase == AppBootPhase.paired &&
      !needsSpaceSetup &&
      !needsRecoveryKeySetup &&
      !isOffline &&
      !isDeviceRevoked &&
      !pushPromptDismissed &&
      pushSupportedOnServer &&
      (pushStatus == null || !pushStatus!.firebaseInitialized);

  String? get partnerDisplayLabel {
    final String? myId = identity?.deviceId;
    for (final DeviceSummary dev in devices) {
      if (dev.deviceId != myId &&
          dev.revokedAt == null &&
          dev.label.trim().isNotEmpty) {
        return dev.label.trim();
      }
    }
    final String? fallback =
        _lastKnownPeerLabel ??
        pendingJoin?.peerLabel ??
        activeInviteStatus?.acceptedLabel;
    if (fallback != null && fallback.trim().isNotEmpty) {
      return fallback.trim();
    }
    return null;
  }

  String? get activeInviteUri {
    final CreateInviteResponse? invite = activeInvite;
    if (invite == null) {
      return null;
    }
    return InviteLinkCodec.buildInviteUri(
      serverUrl: activeServerUrl,
      inviteToken: invite.inviteToken,
      sasSecret: invite.sasSecret,
      defaultServerUrl: defaultServerUrl,
    );
  }

  String? get activeInviteDisplayLink {
    final CreateInviteResponse? invite = activeInvite;
    if (invite == null) {
      return null;
    }
    return InviteLinkCodec.formatCompactDisplayLink(
      serverUrl: activeServerUrl,
      inviteToken: invite.inviteToken,
      sasSecret: invite.sasSecret,
      defaultServerUrl: defaultServerUrl,
    );
  }

  String? get activeInviteManualCode {
    final CreateInviteResponse? invite = activeInvite;
    if (invite == null) {
      return null;
    }
    return InviteLinkCodec.formatManualPairingCode(
      inviteToken: invite.inviteToken,
      sasSecret: invite.sasSecret,
    );
  }

  Future<void> ensureInitialInvite() async {
    if (activeInvite != null ||
        busy ||
        autoInviteAttempted ||
        phase == AppBootPhase.paired ||
        phase == AppBootPhase.upgradeRequired) {
      return;
    }
    autoInviteAttempted = true;
    if (identity != null &&
        identity!.hasCoupleRoot &&
        !identity!.pairingCompleted &&
        identity!.serverUrl == activeServerUrl) {
      await regenerateInitialInvite();
    } else {
      await createInitialInvite(
        serverUrl: activeServerUrl,
        deviceLabel: deviceLabel,
      );
    }
  }

  Future<void> retryInitialInvite() async {
    autoInviteAttempted = false;
    await ensureInitialInvite();
  }

  Future<void> createInitialInvite({
    required String serverUrl,
    required String deviceLabel,
  }) => _runGuarded(() async {
    final String cleanServer = serverUrl.trim();
    final String cleanLabel = deviceLabel.trim().isEmpty
        ? DeepSkyStrings(languageCode).defaultDeviceLabel
        : deviceLabel.trim();
    final result = await _repository.createInitialInvite(
      serverUrl: cleanServer,
      deviceLabel: cleanLabel,
    );
    activeServerUrl = cleanServer;
    this.deviceLabel = cleanLabel;
    identity = result.identity;
    _suppressedAutoPollToken = null;
    activeInvite = result.invite;
    activeInviteStatus = null;
    activeSasCode = null;
    phase = AppBootPhase.waiting;
  });

  Future<void> regenerateInitialInvite() => _runGuarded(() async {
    _suppressedAutoPollToken = null;
    final LocalDeviceIdentity? current = identity;
    if (current != null &&
        current.hasCoupleRoot &&
        !current.pairingCompleted &&
        current.serverUrl == activeServerUrl) {
      activeInvite = await _repository.createEnrollmentInvite();
      activeInviteStatus = null;
      activeSasCode = null;
      phase = AppBootPhase.waiting;
      return;
    }
    final String cleanLabel = deviceLabel.trim().isEmpty
        ? DeepSkyStrings(languageCode).defaultDeviceLabel
        : deviceLabel.trim();
    final result = await _repository.createInitialInvite(
      serverUrl: activeServerUrl,
      deviceLabel: cleanLabel,
    );
    identity = result.identity;
    activeInvite = result.invite;
    activeInviteStatus = null;
    activeSasCode = null;
    phase = AppBootPhase.waiting;
  });

  Future<void> updateServerUrl(
    String rawServerAddress, {
    bool createInvite = true,
  }) => _runGuarded(() async {
    final String normalized = InviteLinkCodec.normalizeServerUrl(
      rawServerAddress,
    );
    final bool serverChanged = normalized != activeServerUrl;
    activeServerUrl = normalized;

    if (serverChanged && identity != null && !identity!.pairingCompleted) {
      await _repository.clearIdentity();
      await _repository.clearPendingInvite();
      identity = null;
      _suppressedAutoPollToken = null;
      activeInvite = null;
      activeInviteStatus = null;
      activeSasCode = null;
      phase = AppBootPhase.unpaired;
    }

    if (!createInvite) {
      autoInviteAttempted = false;
      return;
    }

    autoInviteAttempted = true;
    final String cleanLabel = deviceLabel.trim().isEmpty
        ? DeepSkyStrings(languageCode).defaultDeviceLabel
        : deviceLabel.trim();
    final result = await _repository.createInitialInvite(
      serverUrl: activeServerUrl,
      deviceLabel: cleanLabel,
    );
    identity = result.identity;
    _suppressedAutoPollToken = null;
    activeInvite = result.invite;
    activeInviteStatus = null;
    activeSasCode = null;
    phase = AppBootPhase.waiting;
  });

  Future<void> resetToOfficialServer({bool createInvite = true}) =>
      updateServerUrl(defaultServerUrl, createInvite: createInvite);

  Future<void> shareActiveInvite({
    required String messagePrefix,
    required String copiedFallbackNotice,
  }) async {
    final String? uri = activeInviteUri;
    if (uri == null) {
      return;
    }
    final bool launched = await _nativeBridge.shareText(
      text: '$messagePrefix $uri',
      subject: 'Deep Sky',
    );
    if (!launched) {
      await copySensitiveText(uri);
      statusNotice = copiedFallbackNotice;
      notifyListeners();
    }
  }

  Future<String?> scanQrCode({
    required String title,
    required String hint,
    required String cancelLabel,
  }) async {
    final DeepSkyStrings s = DeepSkyStrings(languageCode);
    try {
      final String? payload = await _nativeBridge.scanQrCode(
        title: title,
        hint: hint,
        cancelLabel: cancelLabel,
      );
      return payload;
    } on PlatformException catch (ex) {
      if (ex.code == 'camera_permission_denied') {
        errorNotice = s.cameraPermissionDeniedNotice;
      } else {
        errorNotice = s.cameraUnavailableNotice;
      }
      notifyListeners();
      return null;
    }
  }

  Future<void> pollActiveInvite() => _runGuarded(() async {
    final CreateInviteResponse? invite = activeInvite;
    if (invite == null) {
      return;
    }
    _suppressedAutoPollToken = null;
    final result = await _repository.checkInviteAndSas(
      invite.inviteToken,
      sasSecret: invite.sasSecret,
    );
    activeInviteStatus = result.status;
    activeSasCode = result.sasCode;
    if (result.status.accepted && result.sasCode != null) {
      statusNotice = languageCode == 'it'
          ? 'Dispositivo collegato! Confronta il codice SAS e conferma.'
          : 'Device connected! Compare the SAS code and confirm.';
    } else {
      statusNotice = languageCode == 'it'
          ? 'Nessun nuovo dispositivo collegato ancora. Riprova dopo che ha inserito il codice.'
          : 'No device has joined yet. Try again after it enters the code.';
    }
  });

  /// Silently checks whether the active invite was accepted so the inviting
  /// device advances automatically to SAS verification without manual polling.
  Future<void> pollActiveInviteSilently() async {
    if (busy || _autoPollInFlight) {
      return;
    }
    final CreateInviteResponse? invite = activeInvite;
    final LocalDeviceIdentity? currentIdentity = identity;
    if (invite == null ||
        activeSasCode != null ||
        currentIdentity == null ||
        !currentIdentity.hasCoupleRoot ||
        phase == AppBootPhase.unpaired ||
        phase == AppBootPhase.upgradeRequired ||
        isDeviceRevoked) {
      return;
    }
    if (invite.inviteToken == _suppressedAutoPollToken) {
      return;
    }
    if (!invite.expiresAt.toUtc().isAfter(DateTime.now().toUtc())) {
      notifyListeners();
      return;
    }

    _autoPollInFlight = true;
    final String polledToken = invite.inviteToken;
    try {
      final result = await _repository.checkInviteAndSas(
        polledToken,
        sasSecret: invite.sasSecret,
      );
      if (activeInvite?.inviteToken != polledToken ||
          activeSasCode != null ||
          phase == AppBootPhase.upgradeRequired ||
          isDeviceRevoked) {
        return;
      }
      if (result.status.accepted && result.sasCode != null) {
        activeInviteStatus = result.status;
        activeSasCode = result.sasCode;
        errorNotice = null;
        statusNotice = languageCode == 'it'
            ? 'Dispositivo collegato! Confronta il codice SAS e conferma.'
            : 'Device connected! Compare the SAS code and confirm.';
        notifyListeners();
      }
    } on ClientUpgradeRequiredException catch (ex) {
      compatibilityPolicy = CompatibilityPolicy(
        minClientVersionCode: ex.minClientVersionCode,
        minProtocolVersion: ex.minProtocolVersion,
      );
      phase = AppBootPhase.upgradeRequired;
      notifyListeners();
    } on ApiRequestException catch (ex) {
      if (ex.isDeviceUnknownOrRevoked && phase == AppBootPhase.paired) {
        isDeviceRevoked = true;
        isOffline = false;
        errorNotice = null;
        await _loadCachedEventsBestEffort();
        notifyListeners();
      }
    } catch (_) {
      // Transient network errors are ignored during silent background polling.
    } finally {
      _autoPollInFlight = false;
    }
  }

  Future<void> confirmSasAndDeliverRootKey() => _runGuarded(() async {
    final InviteStatusResponse? status = activeInviteStatus;
    final DeepSkyStrings s = DeepSkyStrings(languageCode);
    if (status == null ||
        !status.accepted ||
        status.acceptedDeviceId == null ||
        status.acceptedKemPublicKey == null) {
      throw _CalmUserException(s.inviteNotAcceptedYetError);
    }
    _lastKnownPeerLabel = status.acceptedLabel;
    await _repository.confirmSasAndDeliverRootKey(
      targetDeviceId: status.acceptedDeviceId!,
      targetKemPublicKey: status.acceptedKemPublicKey!,
    );
    identity = identity?.copyWith(pairingCompleted: true);
    _suppressedAutoPollToken = null;
    activeInvite = null;
    activeInviteStatus = null;
    activeSasCode = null;
    phase = AppBootPhase.paired;
    await _refreshPairedState();
    statusNotice = s.keysDeliveredNotice;
  });

  Future<void> acceptInvite({
    required String serverUrl,
    required String inviteToken,
    required String deviceLabel,
  }) => _runGuarded(() async {
    final parsed = InviteLinkCodec.parseInviteInputChecked(inviteToken);
    if (parsed.rejectedServerError != null) {
      throw _CalmUserException(
        DeepSkyStrings(languageCode).customServerInsecureError,
      );
    }
    final String? sasSecret = parsed.sasSecret;
    if (sasSecret == null || sasSecret.isEmpty) {
      throw _CalmUserException(
        DeepSkyStrings(languageCode).inviteMissingSasSecretError,
      );
    }
    try {
      DeepSkyCrypto.decodeSasSecretB64(sasSecret);
    } catch (_) {
      throw _CalmUserException(
        DeepSkyStrings(languageCode).inviteMissingSasSecretError,
      );
    }
    final String rawServer = (parsed.serverUrl ?? serverUrl).trim();
    final String resolvedServer;
    try {
      resolvedServer = InviteLinkCodec.normalizeServerUrl(rawServer);
    } on FormatException catch (ex) {
      throw _CalmUserException(
        ex.message.contains('HTTPS')
            ? DeepSkyStrings(languageCode).customServerInsecureError
            : DeepSkyStrings(languageCode).invalidServerAddress,
      );
    }
    activeServerUrl = resolvedServer;
    final String cleanLabel = deviceLabel.trim().isEmpty
        ? DeepSkyStrings(languageCode).defaultDeviceLabel
        : deviceLabel.trim();
    this.deviceLabel = cleanLabel;
    onboardingTabIndex = 1;
    pendingJoin = await _repository.acceptInvite(
      serverUrl: resolvedServer,
      inviteToken: parsed.inviteToken,
      sasSecret: sasSecret,
      deviceLabel: cleanLabel,
    );
    _lastKnownPeerLabel = pendingJoin!.peerLabel;
    identity = pendingJoin!.identity;
  });

  Future<void> completeJoinDelivery() => _runGuarded(() async {
    final PendingJoinSession? session = pendingJoin;
    if (session == null) {
      return;
    }
    final DeepSkyStrings s = DeepSkyStrings(languageCode);
    try {
      identity = await _repository.completeKeyDelivery(session: session);
    } on ApiRequestException catch (ex) {
      if (ex.statusCode == 404) {
        throw _CalmUserException(s.partnerNotConfirmedSasYetError);
      }
      if (ex.isClockSkew) {
        throw _CalmUserException(s.clockSkewError);
      }
      // AU-16: Do not wipe joining identity on an ambiguous 401 (could be a
      // proxy path rewrite or temporary auth mismatch); let the user retry or cancel.
      if (ex.statusCode == 401) {
        throw _CalmUserException(s.joinAuthCheckError);
      }
      rethrow;
    }
    _lastKnownPeerLabel = session.peerLabel;
    pendingJoin = null;
    phase = AppBootPhase.paired;
    await _refreshPairedState();
  });

  Future<void> cancelPendingJoin() => _runGuarded(() async {
    await _repository.clearIdentity();
    await _repository.clearPendingInvite();
    identity = null;
    pendingJoin = null;
    _lastKnownPeerLabel = null;
    _suppressedAutoPollToken = null;
    activeInvite = null;
    activeInviteStatus = null;
    activeSasCode = null;
    phase = AppBootPhase.unpaired;
    autoInviteAttempted = false;
    onboardingTabIndex = 1;
  });

  void returnToInviteScreen() {
    _suppressedAutoPollToken = activeInvite?.inviteToken;
    activeSasCode = null;
    activeInviteStatus = null;
    statusNotice = null;
    errorNotice = null;
    notifyListeners();
  }

  void setOnboardingTabIndex(int index) {
    onboardingTabIndex = index.clamp(0, 2);
  }

  /// Aborts an active SAS verification when the codes do not match (`S1-D07`).
  Future<void> cancelVerificationOnMismatch() => _runGuarded(() async {
    final String notice = DeepSkyStrings(languageCode)
        .verificationMismatchCancelledNotice;
    if (pendingJoin != null) {
      await _repository.clearIdentity();
      await _repository.clearPendingInvite();
      identity = null;
      pendingJoin = null;
      _lastKnownPeerLabel = null;
      activeInvite = null;
      activeInviteStatus = null;
      activeSasCode = null;
      phase = AppBootPhase.unpaired;
      autoInviteAttempted = false;
      onboardingTabIndex = 1;
      statusNotice = notice;
      return;
    }

    if (identity != null && !identity!.pairingCompleted) {
      await _repository.clearIdentity();
      await _repository.clearPendingInvite();
      identity = null;
      _lastKnownPeerLabel = null;
      activeInvite = null;
      activeInviteStatus = null;
      activeSasCode = null;
      phase = AppBootPhase.unpaired;
      autoInviteAttempted = true;
      onboardingTabIndex = 0;
      final String cleanLabel = deviceLabel.trim().isEmpty
          ? DeepSkyStrings(languageCode).defaultDeviceLabel
          : deviceLabel.trim();
      final result = await _repository.createInitialInvite(
        serverUrl: activeServerUrl,
        deviceLabel: cleanLabel,
      );
      identity = result.identity;
      _suppressedAutoPollToken = null;
      activeInvite = result.invite;
      phase = AppBootPhase.waiting;
      statusNotice = notice;
      return;
    }

    _suppressedAutoPollToken = null;
    activeInvite = null;
    activeInviteStatus = null;
    activeSasCode = null;
    statusNotice = notice;
  });

  Future<void> completeNameSetup(String rawName) => _runGuarded(() async {
    final String trimmed = rawName.trim();
    final String resolved = trimmed.isEmpty
        ? DeepSkyStrings(languageCode).defaultDeviceLabel
        : trimmed;
    final LocalDeviceIdentity updated = await _repository.updateOwnDeviceLabel(
      deviceLabel: resolved,
      markNameSetupCompleted: true,
      bestEffortRemote: true,
    );
    identity = updated;
    deviceLabel = updated.deviceLabel;
    if (!isOffline && !isDeviceRevoked) {
      try {
        devices = await _repository.listDevices();
      } catch (_) {
        // Keep current cached devices if offline or server unreachable.
      }
    }
  });

  Future<void> skipNameSetup() => completeNameSetup(deviceLabel);

  Future<void> updateDeviceLabelFromSettings(String rawName) =>
      _runGuarded(() async {
        final String trimmed = rawName.trim();
        if (trimmed.isEmpty) {
          return;
        }
        final LocalDeviceIdentity updated = await _repository
            .updateOwnDeviceLabel(
              deviceLabel: trimmed,
              markNameSetupCompleted: true,
              bestEffortRemote: false,
            );
        identity = updated;
        deviceLabel = updated.deviceLabel;
        if (!isOffline && !isDeviceRevoked) {
          try {
            devices = await _repository.listDevices();
          } catch (_) {}
        }
        statusNotice = DeepSkyStrings(languageCode).deviceNameUpdatedNotice;
      });

  Future<void> recoverWithKey({
    required String serverUrl,
    required String recoveryInput,
    required String deviceLabel,
  }) => _runGuarded(() async {
    final String cleanLabel = deviceLabel.trim().isEmpty
        ? DeepSkyStrings(languageCode).defaultDeviceLabel
        : deviceLabel.trim();
    try {
      identity = await _repository.recoverWithRecoveryKey(
        serverUrl: serverUrl.trim(),
        recoveryInput: recoveryInput.trim(),
        deviceLabel: cleanLabel,
      );
    } on ClientUpgradeRequiredException {
      rethrow;
    } on FormatException {
      throw _CalmUserException(
        DeepSkyStrings(languageCode).recoverCalmFailureMessage,
      );
    } on ApiRequestException {
      throw _CalmUserException(
        DeepSkyStrings(languageCode).recoverCalmFailureMessage,
      );
    }
    this.deviceLabel = cleanLabel;
    phase = AppBootPhase.paired;
    await _refreshPairedState();
    await _syncPendingRotatedPushToken();
  });

  Future<void> confirmRecoveryKeySaved() => _runGuarded(() async {
    identity = await _repository.confirmRecoveryKeySaved();
    statusNotice = languageCode == 'it'
        ? 'Chiave di recupero confermata.'
        : 'Recovery key confirmed.';
  });

  Future<void> sendThinkingOfYou({String? note}) => _runGuarded(() async {
    final LocalDeviceIdentity? current = identity;
    if (current == null || !current.recoverySavedConfirmed) {
      throw StateError('Conferma prima di aver salvato la chiave di recupero.');
    }
    if (isOffline) {
      throw StateError('Modalità offline attiva: sola lettura.');
    }
    if (isDeviceRevoked) {
      throw StateError(DeepSkyStrings(languageCode).revokedDeviceBanner);
    }
    final String cleanNote = note?.trim() ?? '';
    await _repository.sendEncryptedEvent(
      eventType: 'thinking_of_you',
      body: <String, Object?>{if (cleanNote.isNotEmpty) 'note': cleanNote},
    );
    try {
      await PushApiClient(apiClient: _createApiClient(current.serverUrl))
          .sendPartnerWakeup(
            identity: current,
            localizationKey: 'wakeup.thinking_of_you',
          );
    } catch (_) {
      // Push wakeup is best-effort; E2EE event is already stored.
    }
    await _refreshPairedState();
    lastSentThoughtNote = cleanNote.isEmpty ? null : cleanNote;
    if (thoughtSentBannerDuration > Duration.zero) {
      showThoughtSentBanner = true;
      thoughtSentBannerSequence++;
    } else {
      showThoughtSentBanner = false;
    }
  });

  Future<void> refreshSync() => _runGuarded(() async {
    await _refreshPairedState();
  });

  Future<void> createEnrollmentInvite() => _runGuarded(() async {
    _suppressedAutoPollToken = null;
    activeInvite = await _repository.createEnrollmentInvite();
    activeInviteStatus = null;
    activeSasCode = null;
    statusNotice = DeepSkyStrings(languageCode).enrollmentInviteReadyNotice;
  });

  void cancelActiveInvite() {
    _suppressedAutoPollToken = null;
    activeInvite = null;
    activeInviteStatus = null;
    activeSasCode = null;
    statusNotice = null;
    errorNotice = null;
    notifyListeners();
  }

  Future<void> revokeDevice(String targetDeviceId) => _runGuarded(() async {
    identity = await _repository.revokeDevice(targetDeviceId);
    devices = await _repository.listDevices();
  });

  /// Unlinks ONLY this device from the couple (if active) and clears local storage.
  ///
  /// Works even if this device is already revoked (`401`) or offline.
  Future<void> unlinkCurrentDevice() => _runGuarded(() async {
    final LocalDeviceIdentity? current = identity;
    final bool skipRemote = isDeviceRevoked || isOffline;
    if (current != null && !skipRemote) {
      try {
        await PushApiClient(apiClient: _createApiClient(current.serverUrl))
            .unregisterToken(identity: current);
      } catch (_) {}
    }
    try {
      await _nativeBridge.clearRuntimePushConfig();
    } catch (_) {}
    await _repository.unlinkCurrentDevice(localOnly: skipRemote);
    _resetToUnpairedState();
    statusNotice = DeepSkyStrings(languageCode).localResetDoneNotice;
  });

  /// Dissolves the entire couple unilaterally (`S-03`) and clears local storage.
  Future<void> unpairCouple() => _runGuarded(() async {
    final LocalDeviceIdentity? current = identity;
    if (current != null) {
      try {
        await PushApiClient(apiClient: _createApiClient(current.serverUrl))
            .unregisterToken(identity: current);
      } catch (_) {}
    }
    try {
      await _nativeBridge.clearRuntimePushConfig();
    } catch (_) {}
    await _repository.unpairCouple();
    _resetToUnpairedState();
  });

  void _resetToUnpairedState() {
    identity = null;
    events = const <CachedEventEntry>[];
    devices = const <DeviceSummary>[];
    _suppressedAutoPollToken = null;
    activeInvite = null;
    activeInviteStatus = null;
    activeSasCode = null;
    pendingJoin = null;
    _lastKnownPeerLabel = null;
    pushStatus = null;
    pushFeedback = null;
    pushFeedbackIsError = false;
    showThoughtSentBanner = false;
    lastSentThoughtNote = null;
    isOffline = false;
    isDeviceRevoked = false;
    autoInviteAttempted = false;
    onboardingTabIndex = 0;
    activeServerUrl = defaultServerUrl;
    sceneState = const SceneStateSnapshot(
      slotStates: <String, String>{'window': 'calm'},
    );
    phase = AppBootPhase.unpaired;
  }

  Future<void> enableRuntimePush() => _runGuarded(() async {
    final LocalDeviceIdentity? current = identity;
    if (current == null) {
      return;
    }
    final DeepSkyStrings s = DeepSkyStrings(languageCode);
    pushFeedback = null;
    pushFeedbackIsError = false;
    try {
      final PushApiClient pushApi = PushApiClient(
        apiClient: _createApiClient(current.serverUrl),
      );
      final RuntimeFirebaseConfig config = await pushApi
          .fetchRuntimeConfig()
          .timeout(const Duration(seconds: 15));
      if (!config.enabled || !config.isComplete) {
        throw _CalmUserException(s.pushServerDisabledError);
      }
      final bool granted = await _nativeBridge.requestNotificationPermission();
      await _refreshNativePushStatusBestEffort();
      if (!granted) {
        throw _CalmUserException(s.pushPermissionDeniedError);
      }
      final String fcmToken = await _nativeBridge.configureRuntimePush(config);
      await pushApi
          .registerToken(identity: current, fcmToken: fcmToken)
          .timeout(const Duration(seconds: 15));
      await _refreshNativePushStatusBestEffort();
      pushPromptDismissed = true;
      await _keyStore.write(_pushPromptDismissedStorageKey, 'true');
      final String okMessage = languageCode == 'it'
          ? 'Notifiche discrete attivate su questo dispositivo.'
          : 'Quiet notifications enabled on this device.';
      pushFeedback = okMessage;
      pushFeedbackIsError = false;
      statusNotice = okMessage;
    } on _CalmUserException catch (ex) {
      pushFeedback = ex.message;
      pushFeedbackIsError = true;
      rethrow;
    } on PlatformException catch (ex) {
      await _refreshNativePushStatusBestEffort();
      final String msg = switch (ex.code) {
        'gms_unavailable' => s.pushGmsUnavailableError,
        'fcm_token_timeout' => s.pushTimeoutError,
        _ => s.pushTokenFailedError(
          (ex.message?.trim().isNotEmpty ?? false)
              ? ex.message!.trim()
              : ex.code,
        ),
      };
      pushFeedback = msg;
      pushFeedbackIsError = true;
      throw _CalmUserException(msg);
    } on TimeoutException {
      await _refreshNativePushStatusBestEffort();
      final String msg = s.pushTimeoutError;
      pushFeedback = msg;
      pushFeedbackIsError = true;
      throw _CalmUserException(msg);
    } catch (ex) {
      await _refreshNativePushStatusBestEffort();
      final String msg = s.pushTokenFailedError(ex.toString());
      pushFeedback = msg;
      pushFeedbackIsError = true;
      throw _CalmUserException(msg);
    }
  });

  Future<void> _refreshNativePushStatusBestEffort() async {
    if (!_canQueryNativeChannels) {
      return;
    }
    try {
      pushStatus = await _nativeBridge.getPushStatus();
    } catch (_) {
      // Ignore on unsupported hosts or transient channel errors.
    }
  }

  Future<void> refreshPushStatus() async {
    if (!_canQueryNativeChannels || phase != AppBootPhase.paired) {
      return;
    }
    await _refreshNativePushStatusBestEffort();
    notifyListeners();
  }

  Future<bool> openNotificationSettings() =>
      _nativeBridge.openNotificationSettings();

  Future<void> dismissPushPrompt() async {
    pushPromptDismissed = true;
    await _keyStore.write(_pushPromptDismissedStorageKey, 'true');
    notifyListeners();
  }

  Future<void> setUpdateChannel(UpdateChannel channel) async {
    if (updateChannel == channel) {
      return;
    }
    updateChannel = channel;
    availableUpdate = null;
    updateFeedback = null;
    await _keyStore.write(_updateChannelStorageKey, channel.storageValue);
    notifyListeners();
  }

  Future<bool> shareText({required String text, String? subject}) =>
      _nativeBridge.shareText(text: text, subject: subject);

  /// Reference-counted `FLAG_SECURE` toggle (`CA-10`, `AU-24`).
  Future<void> setSecureScreen(bool enabled) =>
      enabled ? acquireSecureScreen() : releaseSecureScreen();

  Future<void> copySensitiveText(String text, {int clearAfterSeconds = 45}) =>
      _nativeBridge.copySensitiveText(
        text,
        clearAfterSeconds: clearAfterSeconds,
      );

  void setAllowCustomUpdateTrustAnchor(bool enabled) {
    if (allowCustomUpdateTrustAnchor == enabled) {
      return;
    }
    allowCustomUpdateTrustAnchor = enabled;
    availableUpdate = null;
    updateFeedback = null;
    notifyListeners();
  }

  Future<void> checkForUpdates({
    required String source,
    required String trustedKeyB64,
    bool force = true,
  }) => _runGuarded(() async {
    updateFeedback = null;
    final String effectiveSource =
        (allowCustomUpdateTrustAnchor && source.trim().isNotEmpty)
        ? source.trim()
        : defaultUpdateSource;
    final String keyToUse =
        (allowCustomUpdateTrustAnchor && trustedKeyB64.trim().isNotEmpty)
        ? trustedKeyB64.trim()
        : trustedUpdatePublicKeyB64.trim();
    if (keyToUse.isEmpty) {
      final String message = languageCode == 'it'
          ? 'Inserisci la chiave pubblica Ed25519 delle release firmate.'
          : 'Enter the Ed25519 public key for signed releases.';
      updateFeedback = message;
      throw _CalmUserException(message);
    }
    final Uri sourceBaseUri;
    try {
      sourceBaseUri = await _updateService.resolveChannelBaseUri(
        sourceInput: effectiveSource,
        channel: updateChannel,
      );
    } on FormatException catch (ex) {
      updateFeedback = languageCode == 'it'
          ? 'Sorgente aggiornamenti non valida (${ex.message}).'
          : 'Invalid update source (${ex.message}).';
      rethrow;
    } on ApkUpdateException catch (ex) {
      updateFeedback = ex.localizedMessage(languageCode);
      rethrow;
    }
    final ApkUpdateCheckResult res;
    try {
      res = await _updateService.checkForUpdate(
        sourceBaseUri: sourceBaseUri,
        trustedPublicKey: ApkUpdateService.parseEd25519PublicKey(keyToUse),
        currentApp: capabilities,
        force: force,
      );
    } on FormatException catch (ex) {
      updateFeedback = languageCode == 'it'
          ? 'Chiave pubblica Ed25519 non valida (${ex.message}).'
          : 'Invalid Ed25519 public key (${ex.message}).';
      rethrow;
    }
    availableUpdate = res.manifest;
    final bool isIt = languageCode == 'it';
    switch (res.status) {
      case ApkUpdateCheckStatus.updateAvailable:
        updateFeedback = isIt
            ? 'Nuova versione disponibile (${updateChannel.localizedLabel(languageCode)}): ${res.manifest!.versionName} (${res.manifest!.versionCode}).'
            : 'Update available (${updateChannel.localizedLabel(languageCode)}): ${res.manifest!.versionName} (${res.manifest!.versionCode}).';
      case ApkUpdateCheckStatus.upToDate:
        updateFeedback = isIt
            ? 'Hai già l\'ultima versione disponibile.'
            : 'You already have the latest version.';
      case ApkUpdateCheckStatus.notModified304:
        updateFeedback = res.manifest != null
            ? (isIt
                  ? 'Aggiornamento già pronto: ${res.manifest!.versionName}.'
                  : 'Update already ready: ${res.manifest!.versionName}.')
            : (isIt
                  ? 'Nessun nuovo rilascio rispetto all\'ultimo controllo.'
                  : 'No new release since the last check.');
      case ApkUpdateCheckStatus.throttledByCooldown:
        updateFeedback = isIt
            ? 'Controllo recente già eseguito.'
            : 'Already checked recently.';
    }
  });

  Future<void> downloadAndInstallUpdate({required String source}) =>
      _runGuarded(() async {
        final ApkReleaseManifest? manifest = availableUpdate;
        if (manifest == null) {
          return;
        }
        final bool canInstall = await _nativeBridge.canRequestPackageInstalls();
        if (!canInstall) {
          await _nativeBridge.openInstallPermissionSettings();
          updateFeedback = languageCode == 'it'
              ? 'Abilita "Installa app sconosciute" per Deep Sky e riprova.'
              : 'Enable "Install unknown apps" for Deep Sky and try again.';
          return;
        }
        final UpdateStorageInfo storage = await _nativeBridge
            .getUpdateStorageInfo();
        updateDownloadProgress = 0.0;
        notifyListeners();
        try {
          final String effectiveSource =
              (allowCustomUpdateTrustAnchor && source.trim().isNotEmpty)
              ? source.trim()
              : defaultUpdateSource;
          final Uri sourceBaseUri = await _updateService.resolveChannelBaseUri(
            sourceInput: effectiveSource,
            channel: updateChannel,
          );
          final file = await _updateService.downloadAndVerifyApk(
            sourceBaseUri: sourceBaseUri,
            manifest: manifest,
            stagingDir: storage.stagingDir,
            availableBytes: storage.availableBytes,
            onProgress: (int received, int total) {
              if (total > 0) {
                updateDownloadProgress = (received / total).clamp(0.0, 1.0);
                notifyListeners();
              }
            },
          );
          final String result = await _updateService.installApkFile(file);
          updateFeedback = languageCode == 'it'
              ? 'Installazione avviata ($result).'
              : 'Installation started ($result).';
        } finally {
          updateDownloadProgress = null;
        }
      });

  void toggleNightMode() {
    isNight = !isNight;
    if (localSceneViewState.skyPreference != SkyTimePreference.auto) {
      localSceneViewState = localSceneViewState.copyWith(
        skyPreference: isNight
            ? SkyTimePreference.night
            : SkyTimePreference.day,
      );
      unawaited(_localSceneStore.save(localSceneViewState));
    }
    _recomputeSceneState();
    notifyListeners();
  }

  void toggleReduceMotion() {
    reduceMotion = !reduceMotion;
    notifyListeners();
  }

  void togglePetOverride() {
    petOverrideActive = !petOverrideActive;
    assetOverrides = petOverrideActive
        ? assetOverrides.withOverride(
            slotId: 'pet',
            layerId: 'pet_body',
            overrideAsset: 'assets/pet_fox_override.png',
          )
        : assetOverrides.withoutOverride(slotId: 'pet', layerId: 'pet_body');
    notifyListeners();
  }

  void setLanguageCode(String code) {
    languageCode = code == 'en' ? 'en' : 'it';
    notifyListeners();
  }

  void setDeviceLabel(String label) {
    final String trimmed = label.trim();
    if (trimmed.isEmpty) {
      return;
    }
    deviceLabel = trimmed;
    notifyListeners();
  }

  void setErrorNotice(String message) {
    errorNotice = message;
    notifyListeners();
  }

  void clearNotices() {
    statusNotice = null;
    errorNotice = null;
    notifyListeners();
  }

  Future<void> _runGuarded(Future<void> Function() action) async {
    busy = true;
    statusNotice = null;
    errorNotice = null;
    notifyListeners();
    try {
      await action();
    } on ClientUpgradeRequiredException catch (ex) {
      compatibilityPolicy = CompatibilityPolicy(
        minClientVersionCode: ex.minClientVersionCode,
        minProtocolVersion: ex.minProtocolVersion,
      );
      phase = AppBootPhase.upgradeRequired;
    } on ApkUpdateException catch (ex) {
      final String msg = ex.localizedMessage(languageCode);
      errorNotice = msg;
      updateFeedback = msg;
    } on _CalmUserException catch (ex) {
      errorNotice = ex.message;
    } on ApiRequestException catch (ex) {
      if (ex.isDeviceUnknownOrRevoked && phase == AppBootPhase.paired) {
        isDeviceRevoked = true;
        isOffline = false;
        errorNotice = null;
        await _loadCachedEventsBestEffort();
      } else {
        errorNotice = _friendlyErrorMessage(ex);
      }
    } catch (error) {
      errorNotice = _friendlyErrorMessage(error);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Maps raw exceptions to calm localized user-facing copy (`AU-16`, `AU-17`).
  String _friendlyErrorMessage(Object error) {
    final DeepSkyStrings s = DeepSkyStrings(languageCode);
    if (error is _CalmUserException) {
      return error.message;
    }
    if (error is ContentPackException) {
      return error.localizedMessage(languageCode);
    }
    if (error is ApkUpdateException) {
      return error.localizedMessage(languageCode);
    }
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return s.networkErrorGeneric;
    }
    if (error is ApiRequestException) {
      if (error.isClockSkew) {
        return s.clockSkewError;
      }
      if (error.statusCode == 429) {
        return s.rateLimitedError;
      }
      if (error.statusCode == 413) {
        return s.payloadTooLargeError;
      }
      if (error.statusCode == 409) {
        return s.conflictErrorGeneric;
      }
      if (error.statusCode >= 500) {
        return s.serverErrorGeneric;
      }
      if (error.statusCode == 401) {
        return s.joinAuthCheckError;
      }
      return s.unexpectedErrorGeneric;
    }
    return s.unexpectedErrorGeneric;
  }

  Uint8List? get recoverySeed => identity?.recoverySeed;
}

class _CalmUserException implements Exception {
  const _CalmUserException(this.message);

  final String message;

  @override
  String toString() => message;
}
