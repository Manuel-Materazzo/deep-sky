import 'dart:async';

import 'package:deep_sky/data/apk_update_service.dart';
import 'package:deep_sky/data/couple_api_client.dart';
import 'package:deep_sky/data/encrypted_local_cache.dart';
import 'package:deep_sky/data/pairing_and_sync_repository.dart';
import 'package:deep_sky/data/push_api_client.dart';
import 'package:deep_sky/data/scene_manifest_parser.dart';
import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/domain/crypto/deep_sky_crypto.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';
import 'package:deep_sky/domain/platform_capabilities.dart';
import 'package:deep_sky/domain/push_models.dart';
import 'package:deep_sky/domain/update/apk_update_models.dart';
import 'package:deep_sky/platform/native_bridge.dart';
import 'package:deep_sky/scene/asset_override_registry.dart';
import 'package:deep_sky/scene/scene_manifest.dart';
import 'package:deep_sky/scene/scene_state_mapper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

enum AppBootPhase { loading, unpaired, paired, upgradeRequired }

/// Application-wide state coordinator for M2 flows:
/// pairing (`F-01`), recovery (`F-20`), thinking-of-you (`F-03`),
/// offline read-only fallback (`TC-07`), push (`SP-01`), and APK updates (`F-19`).
class DeepSkyController extends ChangeNotifier {
  DeepSkyController({
    SecureKeyStore? keyStore,
    DeepSkyCrypto? crypto,
    http.Client? httpClient,
    this._nativeBridge = const NativeBridge(),
    this._manifestParser = const SceneManifestParser(),
    this._sceneStateMapper = const SceneStateMapper(),
    Future<String> Function(String path)? loadAssetString,
    Future<PlatformCapabilities> Function()? loadCapabilities,
    this.clientVersionCode = 1,
    this.protocolVersion = 1,
    this.defaultServerUrl = 'https://deepsky.vectevo.com',
    this.defaultUpdateSource = 'manuel-materazzo/deep_sky',
    this.trustedUpdatePublicKeyB64 =
        'MCowBQYDK2VwAyEAHDblTk6u65qfWgGXDDULNtIsR9JrXd1u4Pc6y7+Z+WM=',
  }) : _httpClient = httpClient ?? http.Client(),
       _loadAssetString = loadAssetString ?? rootBundle.loadString,
       _loadCapabilitiesOverride = loadCapabilities {
    final SecureKeyStore resolvedKeyStore = keyStore ?? FlutterSecureKeyStore();
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

  static const String pilotManifestPath =
      'content/packs/ds2_pilot/manifest.json';
  static const String pilotAssetRoot = 'content/packs/ds2_pilot';

  final http.Client _httpClient;
  final NativeBridge _nativeBridge;
  final SceneManifestParser _manifestParser;
  final SceneStateMapper _sceneStateMapper;
  final Future<String> Function(String path) _loadAssetString;
  final Future<PlatformCapabilities> Function()? _loadCapabilitiesOverride;
  final int clientVersionCode;
  final int protocolVersion;
  final String defaultServerUrl;
  final String defaultUpdateSource;
  final String trustedUpdatePublicKeyB64;

  late final DeepSkyCrypto _crypto;
  late final PairingAndSyncRepository _repository;
  late final ApkUpdateService _updateService;

  AppBootPhase phase = AppBootPhase.loading;
  bool busy = false;
  bool isOffline = false;
  bool isNight = false;
  bool reduceMotion = false;
  bool petOverrideActive = false;
  String languageCode = 'it';
  String? statusNotice;
  String? errorNotice;

  LocalDeviceIdentity? identity;
  CreateInviteResponse? activeInvite;
  InviteStatusResponse? activeInviteStatus;
  String? activeSasCode;
  PendingJoinSession? pendingJoin;
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
  ApkReleaseManifest? availableUpdate;
  String? updateFeedback;

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
    errorNotice = null;
    notifyListeners();

    await _loadPilotScene();
    await _loadCapabilities();
    identity = await _repository.loadIdentity();

    if (identity == null || !identity!.hasCoupleRoot) {
      if (identity != null && !identity!.hasCoupleRoot) {
        await _repository.clearIdentity();
        identity = null;
      }
      await _checkCompatibility(defaultServerUrl);
      if (phase != AppBootPhase.upgradeRequired) {
        phase = AppBootPhase.unpaired;
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
      _recomputeSceneState();
      if (!isOffline) {
        try {
          devices = await _repository.listDevices();
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
    } catch (error) {
      errorNotice = '$error';
    }
  }

  Future<void> _syncPendingRotatedPushToken() async {
    final LocalDeviceIdentity? current = identity;
    if (current == null || isOffline) {
      return;
    }
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

  void _recomputeSceneState() {
    final String deviceId = identity?.deviceId ?? '';
    sceneState = _sceneStateMapper.derive(
      events: events,
      localDeviceId: deviceId,
    );
  }

  Future<void> createInitialInvite({
    required String serverUrl,
    required String deviceLabel,
  }) => _runGuarded(() async {
    final result = await _repository.createInitialInvite(
      serverUrl: serverUrl.trim(),
      deviceLabel: deviceLabel.trim(),
    );
    identity = result.identity;
    activeInvite = result.invite;
    activeInviteStatus = null;
    activeSasCode = null;
  });

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
    await _repository.confirmSasAndDeliverRootKey(
      targetDeviceId: status.acceptedDeviceId!,
      targetKemPublicKey: status.acceptedKemPublicKey!,
    );
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
    pendingJoin = await _repository.acceptInvite(
      serverUrl: serverUrl.trim(),
      inviteToken: _extractInviteToken(inviteToken),
      deviceLabel: deviceLabel.trim(),
    );
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
      rethrow;
    }
    pendingJoin = null;
    phase = AppBootPhase.paired;
    await _refreshPairedState();
  });

  Future<void> cancelPendingJoin() => _runGuarded(() async {
    await _repository.clearIdentity();
    identity = null;
    pendingJoin = null;
  });

  Future<void> recoverWithKey({
    required String serverUrl,
    required String recoveryInput,
    required String deviceLabel,
  }) => _runGuarded(() async {
    identity = await _repository.recoverWithRecoveryKey(
      serverUrl: serverUrl.trim(),
      recoveryInput: recoveryInput.trim(),
      deviceLabel: deviceLabel.trim(),
    );
    phase = AppBootPhase.paired;
    await _refreshPairedState();
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
    identity = null;
    events = const <CachedEventEntry>[];
    devices = const <DeviceSummary>[];
    activeInvite = null;
    activeInviteStatus = null;
    activeSasCode = null;
    pendingJoin = null;
    phase = AppBootPhase.unpaired;
  });

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
    statusNotice = languageCode == 'it'
        ? 'Notifiche discrete attivate su questo dispositivo.'
        : 'Quiet notifications enabled on this device.';
  });

  Future<void> checkForUpdates({
    required String source,
    required String trustedKeyB64,
    bool force = true,
  }) => _runGuarded(() async {
    final String keyToUse = trustedKeyB64.trim().isNotEmpty
        ? trustedKeyB64.trim()
        : trustedUpdatePublicKeyB64.trim();
    if (keyToUse.isEmpty) {
      throw StateError(
        'Inserisci la chiave pubblica Ed25519 delle release firmate.',
      );
    }
    final ApkUpdateCheckResult res = await _updateService.checkForUpdate(
      sourceBaseUri: ApkUpdateService.resolveSourceBaseUri(source),
      trustedPublicKey: ApkUpdateService.parseEd25519PublicKey(keyToUse),
      currentApp: capabilities,
      force: force,
    );
    availableUpdate = res.manifest;
    switch (res.status) {
      case ApkUpdateCheckStatus.updateAvailable:
        updateFeedback =
            'Nuova versione disponibile: ${res.manifest!.versionName} (${res.manifest!.versionCode}).';
      case ApkUpdateCheckStatus.upToDate:
        updateFeedback = 'Hai già l\'ultima versione disponibile.';
      case ApkUpdateCheckStatus.notModified304:
        updateFeedback = res.manifest != null
            ? 'Aggiornamento già pronto: ${res.manifest!.versionName}.'
            : 'Nessun nuovo rilascio rispetto all\'ultimo controllo.';
      case ApkUpdateCheckStatus.throttledByCooldown:
        updateFeedback = 'Controllo recente già eseguito.';
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
          updateFeedback =
              'Abilita "Installa app sconosciute" per Deep Sky e riprova.';
          return;
        }
        final UpdateStorageInfo storage = await _nativeBridge
            .getUpdateStorageInfo();
        final file = await _updateService.downloadAndVerifyApk(
          sourceBaseUri: ApkUpdateService.resolveSourceBaseUri(source),
          manifest: manifest,
          stagingDir: storage.stagingDir,
          availableBytes: storage.availableBytes,
        );
        final String result = await _updateService.installApkFile(file);
        updateFeedback = 'Installazione avviata ($result).';
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
      errorNotice = ex.friendlyMessage;
      updateFeedback = ex.friendlyMessage;
    } catch (error) {
      errorNotice = error.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  static String _extractInviteToken(String raw) {
    final String trimmed = raw.trim();
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri != null && uri.queryParameters.containsKey('token')) {
      return uri.queryParameters['token']!.trim();
    }
    return trimmed;
  }

  Uint8List? get recoverySeed => identity?.recoverySeed;
}
