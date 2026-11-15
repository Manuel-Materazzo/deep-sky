import 'dart:async';
import 'dart:io' show Platform;

import 'package:deep_sky/data/apk_update_service.dart';
import 'package:deep_sky/data/couple_api_client.dart';
import 'package:deep_sky/data/encrypted_local_cache.dart';
import 'package:deep_sky/data/pairing_and_sync_repository.dart';
import 'package:deep_sky/data/push_api_client.dart';
import 'package:deep_sky/data/scene_manifest_parser.dart';
import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/domain/crypto/deep_sky_crypto.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';
import 'package:deep_sky/domain/pairing/invite_link_codec.dart';
import 'package:deep_sky/domain/platform_capabilities.dart';
import 'package:deep_sky/domain/push_models.dart';
import 'package:deep_sky/domain/update/apk_update_models.dart';
import 'package:deep_sky/platform/native_bridge.dart';
import 'package:deep_sky/presentation/l10n/deep_sky_strings.dart';
import 'package:deep_sky/scene/asset_override_registry.dart';
import 'package:deep_sky/scene/scene_manifest.dart';
import 'package:deep_sky/scene/scene_state_mapper.dart';
import 'package:flutter/foundation.dart';
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
    this._manifestParser = const SceneManifestParser(),
    this._sceneStateMapper = const SceneStateMapper(),
    Future<String> Function(String path)? loadAssetString,
    Future<PlatformCapabilities> Function()? loadCapabilities,
    this.clientVersionCode = 1,
    this.protocolVersion = 1,
    this.defaultServerUrl = 'https://deepsky.vectevo.com',
    this.defaultUpdateSource = 'Manuel-Materazzo/deep-sky',
    this.trustedUpdatePublicKeyB64 =
        'MCowBQYDK2VwAyEAHDblTk6u65qfWgGXDDULNtIsR9JrXd1u4Pc6y7+Z+WM=',
  }) : _hasCustomNativeBridge = nativeBridge != null,
       _nativeBridge = nativeBridge ?? const NativeBridge(),
       _httpClient = httpClient ?? http.Client(),
       _loadAssetString = loadAssetString ?? rootBundle.loadString,
       _loadCapabilitiesOverride = loadCapabilities {
    final SecureKeyStore resolvedKeyStore = keyStore ?? FlutterSecureKeyStore();
    _keyStore = resolvedKeyStore;
    _crypto = crypto ?? DeepSkyCrypto();
    _repository = PairingAndSyncRepository(
      keyStore: resolvedKeyStore,
      crypto: _crypto,
      clientFactory: _createApiClient,
    );
    _updateService = ApkUpdateService(
      httpClient: _httpClient,
      nativeBridge: _nativeBridge,
    );
  }

  static const String _updateChannelStorageKey = 'deepsky.update.channel';
  static const String _pushPromptDismissedStorageKey =
      'deepsky.push.prompt_dismissed';
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
  final int clientVersionCode;
  final int protocolVersion;
  final String defaultServerUrl;
  final String defaultUpdateSource;
  final String trustedUpdatePublicKeyB64;

  late final SecureKeyStore _keyStore;
  late final DeepSkyCrypto _crypto;
  late final PairingAndSyncRepository _repository;
  late final ApkUpdateService _updateService;

  AppBootPhase phase = AppBootPhase.loading;
  bool busy = false;
  bool isOffline = false;
  bool isDeviceRevoked = false;
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
  UpdateChannel updateChannel = UpdateChannel.stable;
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

    await _loadPilotScene();
    await _loadCapabilities();
    await _loadClientPreferences();
    _nativeBridge.setDeepLinkListener(handleIncomingDeepLink);
    identity = await _repository.loadIdentity();
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

    phase = AppBootPhase.paired;
    await _refreshPairedState();
    await _syncPendingRotatedPushToken();
    notifyListeners();
  }

  Future<void> _loadPilotScene() async {
    try {
      final String raw = await _loadAssetString(pilotManifestPath);
      sceneManifest = _manifestParser.parseJson(raw);
    } catch (_) {
      sceneManifest = null;
    }
  }

  Future<void> _loadClientPreferences() async {
    try {
      updateChannel = UpdateChannel.fromStorage(
        await _keyStore.read(_updateChannelStorageKey),
      );
      pushPromptDismissed =
          (await _keyStore.read(_pushPromptDismissedStorageKey)) == 'true';
    } catch (_) {
      // Fall back to safe defaults if preferences are unavailable.
    }
  }

  /// Parses an incoming invite deep-link (`https://.../join#...` or `deepsky://pair#...`)
  /// and pre-fills the Join flow without persisting raw tokens to backend logs (`S1-APP-01`).
  void handleIncomingDeepLink(String rawUri) {
    final ({String? serverUrl, String inviteToken}) parsed =
        InviteLinkCodec.parseInviteInput(rawUri);
    if (parsed.inviteToken.isEmpty) {
      return;
    }
    if (phase == AppBootPhase.paired || phase == AppBootPhase.waiting) {
      return;
    }
    pendingDeepLinkInvite = rawUri.trim();
    if (parsed.serverUrl != null) {
      activeServerUrl = parsed.serverUrl!;
    }
    onboardingTabIndex = 1;
    errorNotice = null;
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
      events = snap.events;
      isOffline = snap.isOffline;
      if (!isOffline) {
        isDeviceRevoked = false;
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
        errorNotice = '$ex';
      }
    } catch (error) {
      errorNotice = '$error';
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
    sceneState = _sceneStateMapper.derive(
      events: events,
      localDeviceId: deviceId,
    );
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
      defaultServerUrl: defaultServerUrl,
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
    activeInvite = result.invite;
    activeInviteStatus = null;
    activeSasCode = null;
    phase = AppBootPhase.waiting;
  });

  Future<void> regenerateInitialInvite() => _runGuarded(() async {
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
      await Clipboard.setData(ClipboardData(text: uri));
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
    final result = await _repository.checkInviteAndSas(invite.inviteToken);
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

  Future<void> confirmSasAndDeliverRootKey() => _runGuarded(() async {
    final InviteStatusResponse? status = activeInviteStatus;
    if (status == null ||
        !status.accepted ||
        status.acceptedDeviceId == null ||
        status.acceptedKemPublicKey == null) {
      throw StateError('L\'altro telefono non ha ancora aperto l\'invito.');
    }
    _lastKnownPeerLabel = status.acceptedLabel;
    await _repository.confirmSasAndDeliverRootKey(
      targetDeviceId: status.acceptedDeviceId!,
      targetKemPublicKey: status.acceptedKemPublicKey!,
    );
    identity = identity?.copyWith(pairingCompleted: true);
    activeInvite = null;
    activeInviteStatus = null;
    activeSasCode = null;
    phase = AppBootPhase.paired;
    await _refreshPairedState();
    statusNotice = languageCode == 'it'
        ? 'Chiavi inviate in modo cifrato. Ora completa la ricezione sull\'altro telefono.'
        : 'Keys delivered in encrypted form. Now finish receiving on the other phone.';
  });

  Future<void> acceptInvite({
    required String serverUrl,
    required String inviteToken,
    required String deviceLabel,
  }) => _runGuarded(() async {
    final parsed = InviteLinkCodec.parseInviteInput(inviteToken);
    final String resolvedServer = (parsed.serverUrl ?? serverUrl).trim();
    activeServerUrl = resolvedServer;
    final String cleanLabel = deviceLabel.trim().isEmpty
        ? DeepSkyStrings(languageCode).defaultDeviceLabel
        : deviceLabel.trim();
    this.deviceLabel = cleanLabel;
    onboardingTabIndex = 1;
    pendingJoin = await _repository.acceptInvite(
      serverUrl: resolvedServer,
      inviteToken: parsed.inviteToken,
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
    try {
      identity = await _repository.completeKeyDelivery(session: session);
    } on ApiRequestException catch (ex) {
      if (ex.statusCode == 404) {
        throw StateError(
          languageCode == 'it'
              ? 'L\'altro telefono non ha ancora confermato il codice SAS. Conferma prima sull\'altro telefono, poi riprova.'
              : 'The other phone has not confirmed the SAS code yet. Confirm on the other device first, then try again.',
        );
      }
      if (ex.isDeviceUnknownOrRevoked) {
        await _repository.clearIdentity();
        identity = null;
        pendingJoin = null;
        throw StateError(
          languageCode == 'it'
              ? 'Questo invito o dispositivo non è più valido. Chiedi un nuovo invito al partner.'
              : 'This invite or device is no longer valid. Ask your partner for a new invite.',
        );
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
    activeInvite = null;
    activeInviteStatus = null;
    activeSasCode = null;
    phase = AppBootPhase.unpaired;
    autoInviteAttempted = false;
    onboardingTabIndex = 1;
  });

  void returnToInviteScreen() {
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
      activeInvite = result.invite;
      phase = AppBootPhase.waiting;
      statusNotice = notice;
      return;
    }

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
    statusNotice = languageCode == 'it'
        ? 'Pensiero inviato in modo cifrato.'
        : 'Encrypted thought sent.';
  });

  Future<void> refreshSync() => _runGuarded(() async {
    await _refreshPairedState();
  });

  Future<void> createEnrollmentInvite() => _runGuarded(() async {
    activeInvite = await _repository.createEnrollmentInvite();
    activeInviteStatus = null;
    activeSasCode = null;
    statusNotice = languageCode == 'it'
        ? 'Invito pronto: inseriscilo dal nuovo telefono e poi premi Verifica.'
        : 'Invite ready: enter it on the new phone and then tap Verify.';
  });

  void cancelActiveInvite() {
    activeInvite = null;
    activeInviteStatus = null;
    activeSasCode = null;
    statusNotice = null;
    errorNotice = null;
    notifyListeners();
  }

  Future<void> revokeDevice(String targetDeviceId) => _runGuarded(() async {
    await _repository.revokeDevice(targetDeviceId);
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
    activeInvite = null;
    activeInviteStatus = null;
    activeSasCode = null;
    pendingJoin = null;
    _lastKnownPeerLabel = null;
    pushStatus = null;
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
    final PushApiClient pushApi = PushApiClient(
      apiClient: _createApiClient(current.serverUrl),
    );
    final RuntimeFirebaseConfig config = await pushApi.fetchRuntimeConfig();
    if (!config.enabled || !config.isComplete) {
      throw StateError(
        'Le notifiche push runtime non sono attive su questo server.',
      );
    }
    await _nativeBridge.requestNotificationPermission();
    final String fcmToken = await _nativeBridge.configureRuntimePush(config);
    await pushApi.registerToken(identity: current, fcmToken: fcmToken);
    pushStatus = await _nativeBridge.getPushStatus();
    pushPromptDismissed = true;
    await _keyStore.write(_pushPromptDismissedStorageKey, 'true');
    statusNotice = languageCode == 'it'
        ? 'Notifiche discrete attivate su questo dispositivo.'
        : 'Quiet notifications enabled on this device.';
  });

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

  Future<void> checkForUpdates({
    required String source,
    required String trustedKeyB64,
    bool force = true,
  }) => _runGuarded(() async {
    updateFeedback = null;
    final String keyToUse = trustedKeyB64.trim().isNotEmpty
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
        sourceInput: source,
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
          final Uri sourceBaseUri = await _updateService.resolveChannelBaseUri(
            sourceInput: source,
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
        errorNotice = ex.toString();
      }
    } catch (error) {
      errorNotice = error.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Uint8List? get recoverySeed => identity?.recoverySeed;
}

class _CalmUserException implements Exception {
  const _CalmUserException(this.message);

  final String message;

  @override
  String toString() => message;
}
