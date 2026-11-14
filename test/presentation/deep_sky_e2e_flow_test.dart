import 'dart:convert';
import 'dart:io';

import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/domain/crypto/recovery_key_codec.dart';
import 'package:deep_sky/domain/platform_capabilities.dart';
import 'package:deep_sky/presentation/deep_sky_app.dart';
import 'package:deep_sky/presentation/deep_sky_controller.dart';
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

      // 7) Server enforces minimum version (HTTP 426) -> UpgradeRequiredPage (F-19).
      server.minClientVersionCode = 5;
      await tapVisible(find.byKey(const Key('refresh-sync-button')));
      expect(find.byKey(const Key('upgrade-required-page')), findsOneWidget);
      expect(find.text('Aggiornamento richiesto'), findsOneWidget);
    },
  );
}

class _FakeM2Server {
  bool simulateOffline = false;
  int minClientVersionCode = 1;
  int minProtocolVersion = 1;

  String? lastInviteToken;
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
      acceptedDeviceId = 'dev-b';
      acceptedLabel = body['deviceLabel'] as String;
      acceptedAuthB64 = body['deviceAuthPublicKeyB64'] as String;
      acceptedKemB64 = body['deviceKemPublicKeyB64'] as String;
      devices[acceptedDeviceId!] = <String, Object?>{
        'deviceId': acceptedDeviceId,
        'label': acceptedLabel,
        'enrolledVia': 'PAIRING_JOINER',
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
      return _json(keyDeliveries[caller]!);
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

    if (req.method == 'POST' && path == '/api/v1/recovery/challenges') {
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
      const String devId = 'dev-recovered';
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
