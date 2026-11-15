import 'dart:convert';
import 'dart:io';

import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/domain/crypto/recovery_key_codec.dart';
import 'package:deep_sky/domain/platform_capabilities.dart';
import 'package:deep_sky/platform/native_bridge.dart';
import 'package:deep_sky/presentation/deep_sky_app.dart';
import 'package:deep_sky/presentation/deep_sky_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final String pilotManifestRaw = File('content/packs/ds2_pilot/manifest.json')
      .readAsStringSync();

  testWidgets(
    'E2E client-UI flow: pairing + SAS, recovery gate, thinking-of-you, offline read-only, 24-word recovery, and 426 upgrade screen',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Future<void> tapVisible(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      final _FakeM2Server server = _FakeM2Server();
      final MockClient httpClient = MockClient(server.handle);

      final InMemorySecureKeyStore storeA = InMemorySecureKeyStore();
      final InMemorySecureKeyStore storeB = InMemorySecureKeyStore();

      const PlatformCapabilities testCaps = PlatformCapabilities(
        packageName: 'com.vectevo.deep_sky',
        androidApiLevel: 35,
        versionName: '1.0.0',
        versionCode: 1,
        supportsRequestInstallPackages: false,
      );

      final DeepSkyController ctrlA = DeepSkyController(
        keyStore: storeA,
        httpClient: httpClient,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
      );
      ctrlA.reduceMotion = true;

      await tester.pumpWidget(DeepSkyApp(controller: ctrlA));
      await tester.pumpAndSettle();

      // 1) Onboarding -> Partner A creates initial invite.
      expect(find.byKey(const Key('onboarding-page')), findsOneWidget);
      await tapVisible(find.byKey(const Key('create-invite-button')));
      expect(find.byKey(const Key('active-invite-token')), findsOneWidget);
      final String inviteToken = server.lastInviteToken!;

      // 2) Partner B joins via controller B + computes matching SAS code.
      final DeepSkyController ctrlB = DeepSkyController(
        keyStore: storeB,
        httpClient: httpClient,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
      );
      ctrlB.reduceMotion = true;
      await ctrlB.initialize();
      await ctrlB.acceptInvite(
        serverUrl: 'https://couple.example.test',
        inviteToken: inviteToken,
        deviceLabel: 'Telefono B',
      );
      expect(ctrlB.pendingJoin?.sasCode, isNotEmpty);

      // Partner A polls invite, verifies matching SAS, and delivers wrapped key.
      await tapVisible(find.byKey(const Key('poll-invite-button')));
      expect(
        find.text('Codice di verifica SAS: ${ctrlB.pendingJoin!.sasCode}'),
        findsOneWidget,
      );
      await tapVisible(find.byKey(const Key('confirm-sas-button')));

      // Complete Partner B join too.
      await ctrlB.completeJoinDelivery();

      // 3) Partner A lands on Home with mandatory Recovery Key confirmation gate (S-06).
      expect(find.byKey(const Key('home-shell-page')), findsOneWidget);
      expect(find.byKey(const Key('recovery-gate-card')), findsOneWidget);

      final FilledButton disabledSend = tester.widget<FilledButton>(
        find.byKey(const Key('send-thought-button')),
      );
      expect(disabledSend.onPressed, isNull);

      final String recoverySentence = RecoveryKeyCodec.toSentence(
        ctrlA.recoverySeed!,
      );
      await tapVisible(find.byKey(const Key('recovery-saved-checkbox')));
      await tapVisible(find.byKey(const Key('confirm-recovery-button')));
      expect(find.byKey(const Key('recovery-gate-card')), findsNothing);

      // 4) Partner A sends "Ti penso" -> Partner B receives "Hai un pensiero in arrivo." + lit window.
      await tester.ensureVisible(find.byKey(const Key('thought-note-field')));
      await tester.enterText(
        find.byKey(const Key('thought-note-field')),
        'Pensiero della sera',
      );
      await tapVisible(find.byKey(const Key('send-thought-button')));
      expect(server.pushWakeupsDispatched, 1);
      expect(server.lastPushLocalizationKey, 'wakeup.thinking_of_you');

      await ctrlB.refreshSync();
      expect(ctrlB.sceneState.windowLit, isTrue);
      expect(ctrlB.sceneState.fromPartner, isTrue);
      expect(ctrlB.events.single.payload.body['note'], 'Pensiero della sera');

      // Render Partner B UI and confirm status card copy & lit scene.
      await tester.pumpWidget(
        DeepSkyApp(controller: ctrlB, autoInitialize: false),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hai un pensiero in arrivo.'), findsOneWidget);

      // 5) Simulate offline mode -> calm read-only banner + cached timeline preserved + writes disabled.
      server.simulateOffline = true;
      await tapVisible(find.byKey(const Key('refresh-sync-button')));
      expect(find.byKey(const Key('offline-readonly-banner')), findsOneWidget);
      expect(find.textContaining('Pensiero della sera'), findsWidgets);
      final FilledButton offlineSend = tester.widget<FilledButton>(
        find.byKey(const Key('send-thought-button')),
      );
      expect(offlineSend.onPressed, isNull);

      // 6) Recover onto a third fresh device using the 24 BIP-39 words (F-20).
      server.simulateOffline = false;
      final DeepSkyController ctrlC = DeepSkyController(
        keyStore: InMemorySecureKeyStore(),
        httpClient: httpClient,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
      );
      ctrlC.reduceMotion = true;
      await ctrlC.initialize();
      await ctrlC.recoverWithKey(
        serverUrl: 'https://couple.example.test',
        recoveryInput: recoverySentence,
        deviceLabel: 'Telefono C',
      );
      expect(ctrlC.phase, AppBootPhase.paired);
      expect(ctrlC.events.single.payload.body['note'], 'Pensiero della sera');

      // 7) Cross-device enrollment from Devices tab UI -> Phone D (F-20).
      // Render Phone A back in HomeShellPage and switch to Dispositivi tab.
      await tester.pumpWidget(
        DeepSkyApp(controller: ctrlA, autoInitialize: false),
      );
      await tester.pumpAndSettle();
      await tapVisible(find.text('Dispositivi'));
      await tapVisible(
        find.byKey(const Key('create-enrollment-invite-button')),
      );
      expect(find.byKey(const Key('enroll-invite-token')), findsOneWidget);
      final String enrollToken = server.lastInviteToken!;

      // Phone D opens Onboarding -> Unisciti tab and accepts the enrollment invite.
      final DeepSkyController ctrlD = DeepSkyController(
        keyStore: InMemorySecureKeyStore(),
        httpClient: httpClient,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
      );
      ctrlD.reduceMotion = true;
      await tester.pumpWidget(DeepSkyApp(controller: ctrlD));
      await tester.pumpAndSettle();
      await tapVisible(find.text('Unisciti'));
      await tester.enterText(
        find.byKey(const Key('join-token-field')),
        enrollToken,
      );
      await tapVisible(find.byKey(const Key('accept-invite-button')));
      expect(find.byKey(const Key('joiner-sas-code')), findsOneWidget);
      final String enrollSas = ctrlD.pendingJoin!.sasCode;

      // If Phone D taps "Completa ricezione chiavi" before Phone A confirms SAS,
      // it gets a clear friendly message instead of a raw 404 exception.
      await tapVisible(find.byKey(const Key('complete-join-button')));
      expect(
        find.textContaining('non ha ancora confermato il codice SAS'),
        findsOneWidget,
      );

      // Phone A (Dispositivi tab) polls, sees the matching SAS, and delivers keys.
      await tester.pumpWidget(
        DeepSkyApp(controller: ctrlA, autoInitialize: false),
      );
      await tester.pumpAndSettle();
      await tapVisible(find.text('Dispositivi'));
      await tapVisible(find.byKey(const Key('enroll-poll-invite-button')));
      expect(find.text('Codice di verifica SAS: $enrollSas'), findsOneWidget);
      await tapVisible(find.byKey(const Key('enroll-confirm-sas-button')));
      expect(find.byKey(const Key('enroll-invite-token')), findsNothing);
      expect(find.text('Telefono B'), findsWidgets);

      // Phone D completes key reception and lands on Home with decrypted thoughts.
      await tester.pumpWidget(
        DeepSkyApp(controller: ctrlD, autoInitialize: false),
      );
      await tester.pumpAndSettle();
      await tapVisible(find.byKey(const Key('complete-join-button')));
      expect(find.byKey(const Key('home-shell-page')), findsOneWidget);
      expect(find.textContaining('Pensiero della sera'), findsWidgets);

      // 8) Server enforces minimum version (HTTP 426) -> UpgradeRequiredPage (F-19).
      server.minClientVersionCode = 5;
      await tapVisible(find.byKey(const Key('refresh-sync-button')));
      expect(find.byKey(const Key('upgrade-required-page')), findsOneWidget);
      expect(find.text('Aggiornamento richiesto'), findsOneWidget);
    },
  );

  testWidgets(
    'Unlink this device leaves couple active; revoked device sees calm banner and can reset locally; unpairCouple dissolves couple',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const MethodChannel platformChannel = MethodChannel(
        NativeBridge.channelName,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platformChannel, (MethodCall call) async {
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(platformChannel, null);
      });

      Future<void> tapVisible(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      Future<void> settleController(DeepSkyController c) async {
        for (int i = 0; i < 40 && c.busy; i++) {
          await tester.pump(const Duration(milliseconds: 25));
        }
        await tester.pumpAndSettle();
      }

      final _FakeM2Server server = _FakeM2Server();
      final MockClient httpClient = MockClient(server.handle);

      const PlatformCapabilities testCaps = PlatformCapabilities(
        packageName: 'com.vectevo.deep_sky',
        androidApiLevel: 35,
        versionName: '1.0.0',
        versionCode: 1,
        supportsRequestInstallPackages: false,
      );

      DeepSkyController makeController(InMemorySecureKeyStore store) {
        final DeepSkyController c = DeepSkyController(
          keyStore: store,
          httpClient: httpClient,
          loadAssetString: (_) async => pilotManifestRaw,
          loadCapabilities: () async => testCaps,
          defaultServerUrl: 'https://couple.example.test',
        );
        c.reduceMotion = true;
        return c;
      }

      final InMemorySecureKeyStore storeA = InMemorySecureKeyStore();
      final InMemorySecureKeyStore storeB = InMemorySecureKeyStore();
      final InMemorySecureKeyStore storeC = InMemorySecureKeyStore();

      final DeepSkyController ctrlA = makeController(storeA);
      final DeepSkyController ctrlB = makeController(storeB);
      final DeepSkyController ctrlC = makeController(storeC);

      // Pair A + B, confirm recovery on A, recover C
      await ctrlA.initialize();
      await ctrlA.createInitialInvite(
        serverUrl: 'https://couple.example.test',
        deviceLabel: 'Telefono A',
      );
      await ctrlB.initialize();
      await ctrlB.acceptInvite(
        serverUrl: 'https://couple.example.test',
        inviteToken: server.lastInviteToken!,
        deviceLabel: 'Telefono B',
      );
      await ctrlA.pollActiveInvite();
      await ctrlA.confirmSasAndDeliverRootKey();
      await ctrlB.completeJoinDelivery();
      await ctrlB.confirmRecoveryKeySaved();
      await ctrlA.confirmRecoveryKeySaved();

      final String recoverySentence = RecoveryKeyCodec.toSentence(
        ctrlA.recoverySeed!,
      );
      await ctrlC.initialize();
      await ctrlC.recoverWithKey(
        serverUrl: 'https://couple.example.test',
        recoveryInput: recoverySentence,
        deviceLabel: 'Telefono C',
      );

      // 1) Phone B unlinks ONLY itself via Dispositivi -> "Scollega questo dispositivo e pulisci spazio locale"
      await tester.pumpWidget(
        DeepSkyApp(controller: ctrlB, autoInitialize: false),
      );
      await tester.pumpAndSettle();
      await tapVisible(find.text('Dispositivi'));
      await tapVisible(find.byKey(const Key('unlink-device-button')));
      await tapVisible(find.byKey(const Key('confirm-unlink-device-button')));
      await settleController(ctrlB);

      expect(ctrlB.errorNotice, isNull);
      expect(ctrlB.busy, isFalse);
      expect(ctrlB.phase, AppBootPhase.unpaired);
      expect(find.byKey(const Key('onboarding-page')), findsOneWidget);
      expect(ctrlB.phase, AppBootPhase.unpaired);
      expect(await storeB.read('deep_sky.device_identity.v1'), isNull);
      expect(server.coupleUnpaired, isFalse);

      // Phone A and Phone C remain active and can keep exchanging thoughts!
      await ctrlA.sendThinkingOfYou(note: 'Ancora connessi');
      await ctrlC.refreshSync();
      expect(ctrlC.isDeviceRevoked, isFalse);
      expect(ctrlC.events.single.payload.body['note'], 'Ancora connessi');

      // 2) Phone A revokes Phone C -> Phone C gets 401 -> calm banner + 1-tap reset works
      await ctrlA.revokeDevice(ctrlC.identity!.deviceId);
      await ctrlC.refreshSync();
      expect(ctrlC.isDeviceRevoked, isTrue);
      expect(ctrlC.errorNotice, isNull);

      await tester.pumpWidget(
        DeepSkyApp(controller: ctrlC, autoInitialize: false),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('revoked-device-banner')), findsOneWidget);
      final FilledButton revokedSend = tester.widget<FilledButton>(
        find.byKey(const Key('send-thought-button')),
      );
      expect(revokedSend.onPressed, isNull);

      await tapVisible(find.byKey(const Key('reset-revoked-device-button')));
      await settleController(ctrlC);
      expect(find.byKey(const Key('onboarding-page')), findsOneWidget);
      expect(ctrlC.phase, AppBootPhase.unpaired);
      expect(await storeC.read('deep_sky.device_identity.v1'), isNull);

      // 3) Re-recover Phone D, then Phone A invokes S-03 "Interrompi abbinamento per entrambi"
      final InMemorySecureKeyStore storeD = InMemorySecureKeyStore();
      final DeepSkyController ctrlD = makeController(storeD);
      await ctrlD.initialize();
      await ctrlD.recoverWithKey(
        serverUrl: 'https://couple.example.test',
        recoveryInput: recoverySentence,
        deviceLabel: 'Telefono D',
      );
      expect(ctrlD.phase, AppBootPhase.paired);

      await tester.pumpWidget(
        DeepSkyApp(controller: ctrlA, autoInitialize: false),
      );
      await tester.pumpAndSettle();
      await tapVisible(find.text('Dispositivi'));
      await tapVisible(find.byKey(const Key('unpair-couple-button')));
      await tapVisible(find.byKey(const Key('confirm-unpair-couple-button')));
      await settleController(ctrlA);

      expect(find.byKey(const Key('onboarding-page')), findsOneWidget);
      expect(server.coupleUnpaired, isTrue);

      // Phone D sees the revoked/unpaired banner and can wipe local data via Dispositivi tab too
      await ctrlD.refreshSync();
      expect(ctrlD.isDeviceRevoked, isTrue);
      await tester.pumpWidget(
        DeepSkyApp(controller: ctrlD, autoInitialize: false),
      );
      await tester.pumpAndSettle();
      await tapVisible(find.text('Dispositivi'));
      await tapVisible(find.byKey(const Key('unlink-device-button')));
      await settleController(ctrlD);
      expect(find.byKey(const Key('onboarding-page')), findsOneWidget);
      expect(await storeD.read('deep_sky.device_identity.v1'), isNull);
    },
  );
}

class _FakeM2Server {
  bool simulateOffline = false;
  bool coupleUnpaired = false;
  int minClientVersionCode = 1;
  int minProtocolVersion = 1;

  String? lastInviteToken;
  int _inviteSeq = 0;
  int _deviceSeq = 0;
  String? coupleId;
  String? recoveryAuthKeyB64;
  String? inviterDeviceId;
  String? inviterLabel;
  String? inviterAuthB64;
  String? inviterKemB64;
  String? acceptedDeviceId;
  String? acceptedLabel;
  String? acceptedAuthB64;
  String? acceptedKemB64;
  final Map<String, Map<String, Object?>> devices =
      <String, Map<String, Object?>>{};
  final Map<String, Map<String, Object?>> keyDeliveries =
      <String, Map<String, Object?>>{};
  final List<Map<String, Object?>> envelopes = <Map<String, Object?>>[];
  String? lastChallengeId;
  String? lastChallengeNonce;
  int pushWakeupsDispatched = 0;
  String? lastPushLocalizationKey;

  Future<http.Response> handle(http.Request req) async {
    if (simulateOffline) {
      throw const SocketException('Simulated offline');
    }
    final int clientVersion =
        int.tryParse(req.headers['X-Client-Version-Code'] ?? '1') ?? 1;
    final int protocolVersion =
        int.tryParse(req.headers['X-Protocol-Version'] ?? '1') ?? 1;
    if (clientVersion < minClientVersionCode ||
        protocolVersion < minProtocolVersion) {
      return http.Response(
        jsonEncode(<String, Object?>{
          'error': 'CLIENT_UPGRADE_REQUIRED',
          'minClientVersionCode': minClientVersionCode,
          'minProtocolVersion': minProtocolVersion,
        }),
        426,
      );
    }

    final String path = req.url.path;
    final Map<String, Object?> body = req.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(req.body) as Map<String, Object?>;

    if (req.method == 'GET' && path == '/api/v1/system/compatibility') {
      return _json(<String, Object?>{
        'minClientVersionCode': minClientVersionCode,
        'minProtocolVersion': minProtocolVersion,
      });
    }

    if (req.method == 'POST' && path == '/api/v1/pairing/invites') {
      coupleUnpaired = false;
      coupleId = 'couple-1';
      inviterDeviceId = 'dev-a';
      inviterLabel = body['deviceLabel'] as String;
      inviterAuthB64 = body['deviceAuthPublicKeyB64'] as String;
      inviterKemB64 = body['deviceKemPublicKeyB64'] as String;
      recoveryAuthKeyB64 = body['recoveryAuthPublicKeyB64'] as String;
      lastInviteToken = 'inv-tok-123';
      devices[inviterDeviceId!] = <String, Object?>{
        'deviceId': inviterDeviceId,
        'label': inviterLabel,
        'enrolledVia': 'PAIRING_INVITER',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'revokedAt': null,
      };
      return _json(<String, Object?>{
        'coupleId': coupleId,
        'deviceId': inviterDeviceId,
        'inviteToken': lastInviteToken,
        'expiresAt': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 15))
            .toIso8601String(),
      }, status: 201);
    }

    if (req.method == 'POST' &&
        path == '/api/v1/pairing/invites/$lastInviteToken/accept') {
      acceptedDeviceId = 'dev-join-${++_deviceSeq}';
      acceptedLabel = body['deviceLabel'] as String;
      acceptedAuthB64 = body['deviceAuthPublicKeyB64'] as String;
      acceptedKemB64 = body['deviceKemPublicKeyB64'] as String;
      devices[acceptedDeviceId!] = <String, Object?>{
        'deviceId': acceptedDeviceId,
        'label': acceptedLabel,
        'enrolledVia': _deviceSeq == 1 ? 'PAIRING_JOINER' : 'ENROLLMENT',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'revokedAt': null,
      };
      return _json(<String, Object?>{
        'coupleId': coupleId,
        'deviceId': acceptedDeviceId,
        'peerDeviceId': inviterDeviceId,
        'peerLabel': inviterLabel,
        'peerAuthPublicKeyB64': inviterAuthB64,
        'peerKemPublicKeyB64': inviterKemB64,
      });
    }

    if (req.method == 'POST' && path == '/api/v1/recovery/challenges') {
      if (coupleUnpaired) {
        return _json(<String, Object?>{
          'code': 'CONFLICT',
          'message': 'Couple has been unpaired',
        }, status: 409);
      }
      lastChallengeId = 'chal-1';
      lastChallengeNonce = base64UrlEncode(
        List<int>.generate(32, (int i) => i + 1),
      );
      return _json(<String, Object?>{
        'challengeId': lastChallengeId,
        'coupleId': coupleId,
        'nonceB64': lastChallengeNonce,
        'expiresAt': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 5))
            .toIso8601String(),
      });
    }

    if (req.method == 'POST' && path == '/api/v1/recovery/complete') {
      if (coupleUnpaired) {
        return _json(<String, Object?>{
          'code': 'CONFLICT',
          'message': 'Couple has been unpaired',
        }, status: 409);
      }
      final String devId = 'dev-recovered-${++_deviceSeq}';
      devices[devId] = <String, Object?>{
        'deviceId': devId,
        'label': body['deviceLabel'],
        'enrolledVia': 'RECOVERY_KEY',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'revokedAt': null,
      };
      return _json(<String, Object?>{
        'coupleId': coupleId,
        'deviceId': devId,
      }, status: 201);
    }

    // Authenticated endpoints: enforce DeviceAuthFilter semantics
    final String? callerId = req.headers['X-Device-Id'];
    if (callerId != null) {
      final Map<String, Object?>? callerDev = devices[callerId];
      if (coupleUnpaired ||
          callerDev == null ||
          callerDev['revokedAt'] != null) {
        return _json(<String, Object?>{
          'code': 'UNAUTHORIZED',
          'message': 'Device unknown or revoked',
        }, status: 401);
      }
    }

    if (req.method == 'POST' && path == '/api/v1/pairing/enrollment-invites') {
      final String caller = req.headers['X-Device-Id']!;
      final Map<String, Object?> creator = devices[caller]!;
      inviterDeviceId = caller;
      inviterLabel = creator['label'] as String;
      acceptedDeviceId = null;
      acceptedLabel = null;
      acceptedAuthB64 = null;
      acceptedKemB64 = null;
      lastInviteToken = 'enroll-tok-${++_inviteSeq}';
      return _json(<String, Object?>{
        'coupleId': coupleId,
        'deviceId': caller,
        'inviteToken': lastInviteToken,
        'expiresAt': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 15))
            .toIso8601String(),
      }, status: 201);
    }

    if (req.method == 'GET' &&
        path == '/api/v1/pairing/invites/$lastInviteToken/status') {
      return _json(<String, Object?>{
        'accepted': acceptedDeviceId != null,
        'acceptedDeviceId': acceptedDeviceId,
        'acceptedLabel': acceptedLabel,
        'acceptedAuthPublicKeyB64': acceptedAuthB64,
        'acceptedKemPublicKeyB64': acceptedKemB64,
      });
    }

    if (req.method == 'POST' && path == '/api/v1/pairing/key-deliveries') {
      final String target = body['toDeviceId'] as String;
      keyDeliveries[target] = <String, Object?>{
        'coupleId': coupleId,
        'fromDeviceId': inviterDeviceId,
        'toDeviceId': target,
        'nonceB64': body['nonceB64'],
        'ciphertextB64': body['ciphertextB64'],
      };
      return _json(<String, Object?>{'status': 'DELIVERED'}, status: 201);
    }

    if (req.method == 'GET' && path == '/api/v1/pairing/key-deliveries/me') {
      final String caller = req.headers['X-Device-Id']!;
      final Map<String, Object?>? pending = keyDeliveries[caller];
      if (pending == null) {
        return _json(<String, Object?>{
          'message': 'No key delivery ready for this device',
        }, status: 404);
      }
      return _json(pending);
    }

    if (req.method == 'POST' && path == '/api/v1/pairing/confirm-recovery') {
      return http.Response('', 204);
    }

    if (req.method == 'POST' && path == '/api/v1/sync/envelopes') {
      final Map<String, Object?> record = <String, Object?>{
        'envelopeId': body['envelopeId'],
        'coupleId': coupleId,
        'senderDeviceId': req.headers['X-Device-Id'],
        'channel': body['channel'],
        'keyEpoch': body['keyEpoch'],
        'seq': envelopes.length + 1,
        'nonceB64': body['nonceB64'],
        'ciphertextB64': body['ciphertextB64'],
        'createdAtServer': DateTime.now().toUtc().toIso8601String(),
      };
      envelopes.add(record);
      return _json(record, status: 201);
    }

    if (req.method == 'GET' && path == '/api/v1/sync/envelopes') {
      return _json(envelopes);
    }

    if (req.method == 'GET' && path == '/api/v1/pairing/devices') {
      return _json(devices.values.toList());
    }

    if (req.method == 'POST' &&
        path.startsWith('/api/v1/pairing/devices/') &&
        path.endsWith('/revoke')) {
      final String targetId = path.split('/')[5];
      final Map<String, Object?>? target = devices[targetId];
      if (target == null) {
        return _json(<String, Object?>{
          'message': 'Device not found',
        }, status: 404);
      }
      target['revokedAt'] ??= DateTime.now().toUtc().toIso8601String();
      return http.Response('', 204);
    }

    if (req.method == 'POST' && path == '/api/v1/pairing/unpair') {
      coupleUnpaired = true;
      final String now = DateTime.now().toUtc().toIso8601String();
      for (final Map<String, Object?> dev in devices.values) {
        dev['revokedAt'] ??= now;
      }
      return http.Response('', 204);
    }

    if (req.method == 'POST' && path == '/api/v1/push/wakeup') {
      pushWakeupsDispatched++;
      lastPushLocalizationKey = body['localizationKey'] as String?;
      return _json(<String, Object?>{
        'localizationKey': lastPushLocalizationKey ?? 'wakeup.generic',
        'attempted': 1,
        'delivered': 1,
        'unregisteredRemoved': 0,
      });
    }

    if (req.method == 'DELETE' && path == '/api/v1/push/register') {
      return http.Response('', 204);
    }

    return http.Response('not found: ${req.method} $path', 404);
  }

  static http.Response _json(Object body, {int status = 200}) {
    return http.Response(
      jsonEncode(body),
      status,
      headers: const <String, String>{'Content-Type': 'application/json'},
    );
  }
}
