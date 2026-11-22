import 'dart:convert';
import 'dart:io';

import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/domain/platform_capabilities.dart';
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

  const PlatformCapabilities testCaps = PlatformCapabilities(
    packageName: 'com.vectevo.deep_sky',
    androidApiLevel: 35,
    versionName: '1.0.0',
    versionCode: 1,
    supportsRequestInstallPackages: false,
  );

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      final Finder scrollable = find.byType(Scrollable).last;
      if (scrollable.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(finder, 200, scrollable: scrollable);
      }
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'S1-D07 inviter verification: shows 6-digit SAS, copies code, and mismatch cancels with calm notice',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      String? copiedClipboard;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall call,
          ) async {
            if (call.method == 'Clipboard.setData') {
              final Map<Object?, Object?> args =
                  call.arguments as Map<Object?, Object?>;
              copiedClipboard = args['text'] as String?;
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final _MiniPairingServer server = _MiniPairingServer();
      final MockClient httpClient = MockClient(server.handle);

      final DeepSkyController ctrlA = DeepSkyController(
        keyStore: InMemorySecureKeyStore(),
        httpClient: httpClient,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
      );
      ctrlA.reduceMotion = true;

      final DeepSkyController ctrlB = DeepSkyController(
        keyStore: InMemorySecureKeyStore(),
        httpClient: httpClient,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
      );
      ctrlB.reduceMotion = true;

      await tester.pumpWidget(DeepSkyApp(controller: ctrlA));
      await tester.pumpAndSettle();

      final String firstInviteToken = server.lastInviteToken!;
      final String firstInviteUri = ctrlA.activeInviteUri!;

      await ctrlB.initialize();
      await ctrlB.acceptInvite(
        serverUrl: 'https://couple.example.test',
        inviteToken: firstInviteUri,
        deviceLabel: 'Telefono B',
      );
      final String expectedSas = ctrlB.pendingJoin!.sasCode;

      await tapVisible(tester, find.byKey(const Key('poll-invite-button')));
      expect(find.byKey(const Key('code-verification-page')), findsOneWidget);
      expect(find.byKey(const Key('inviter-sas-code')), findsOneWidget);
      expect(find.bySemanticsLabel('SAS $expectedSas'), findsOneWidget);
      // CA-10: SAS code must not be copyable to clipboard
      expect(find.byKey(const Key('copy-sas-button')), findsNothing);
      expect(copiedClipboard, isNull);

      // Mismatch button opens confirmation dialog and then resets with a calm notice & fresh invite.
      await tapVisible(tester, find.byKey(const Key('mismatch-sas-button')));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tapVisible(
        tester,
        find.byKey(const Key('confirm-mismatch-cancel-button')),
      );

      expect(find.byKey(const Key('onboarding-page')), findsOneWidget);
      expect(server.lastInviteToken, isNot(firstInviteToken));
      expect(ctrlA.statusNotice, isNotNull);
      expect(ctrlA.statusNotice, contains('nuovo invito'));
    },
  );

  testWidgets(
    'S1-D07 joiner verification: mismatch returns to Join tab with calm warning',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final _MiniPairingServer server = _MiniPairingServer();
      final MockClient httpClient = MockClient(server.handle);

      final DeepSkyController ctrlA = DeepSkyController(
        keyStore: InMemorySecureKeyStore(),
        httpClient: httpClient,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
      );
      ctrlA.reduceMotion = true;
      await ctrlA.initialize();
      await ctrlA.createInitialInvite(
        serverUrl: 'https://couple.example.test',
        deviceLabel: 'Giulia',
      );

      final DeepSkyController ctrlB = DeepSkyController(
        keyStore: InMemorySecureKeyStore(),
        httpClient: httpClient,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
      );
      ctrlB.reduceMotion = true;
      await ctrlB.initialize();
      await ctrlB.acceptInvite(
        serverUrl: 'https://couple.example.test',
        inviteToken: ctrlA.activeInviteUri!,
        deviceLabel: 'Telefono B',
      );

      await tester.pumpWidget(
        DeepSkyApp(controller: ctrlB, autoInitialize: false),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('code-verification-page')), findsOneWidget);
      expect(find.byKey(const Key('joiner-sas-code')), findsOneWidget);
      expect(
        find.bySemanticsLabel('SAS ${ctrlB.pendingJoin!.sasCode}'),
        findsOneWidget,
      );

      await tapVisible(tester, find.byKey(const Key('mismatch-sas-button')));
      await tapVisible(
        tester,
        find.byKey(const Key('confirm-mismatch-cancel-button')),
      );

      expect(find.byKey(const Key('onboarding-page')), findsOneWidget);
      expect(ctrlB.onboardingTabIndex, 1);
      expect(find.byKey(const Key('join-token-field')), findsOneWidget);
      expect(ctrlB.statusNotice, isNotNull);
    },
  );

  testWidgets(
    'S1-D07-2 space setup + Settings name editor: dark & light themes, IT & EN, syncs to server',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final _MiniPairingServer server = _MiniPairingServer();
      final MockClient httpClient = MockClient(server.handle);

      final DeepSkyController ctrlA = DeepSkyController(
        keyStore: InMemorySecureKeyStore(),
        httpClient: httpClient,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
      );
      ctrlA.reduceMotion = true;

      final DeepSkyController ctrlB = DeepSkyController(
        keyStore: InMemorySecureKeyStore(),
        httpClient: httpClient,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
      );
      ctrlB.reduceMotion = true;

      await ctrlA.initialize();
      await ctrlA.createInitialInvite(
        serverUrl: 'https://couple.example.test',
        deviceLabel: 'Telefono principale',
      );
      await ctrlB.initialize();
      await ctrlB.acceptInvite(
        serverUrl: 'https://couple.example.test',
        inviteToken: ctrlA.activeInviteUri!,
        deviceLabel: 'Sofia',
      );
      await ctrlA.pollActiveInvite();
      await ctrlA.confirmSasAndDeliverRootKey();
      await ctrlB.completeJoinDelivery();

      await tester.pumpWidget(
        DeepSkyApp(controller: ctrlA, autoInitialize: false),
      );
      await tester.pumpAndSettle();

      // Should land on SpaceSetupPage and show partner's name ('Sofia') + default 'Tu' fallback.
      expect(find.byKey(const Key('space-setup-page')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('preview-partner-tag'))).data,
        'Sofia',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('preview-user-tag'))).data,
        'Tu',
      );

      // Verify English + Light theme render cleanly without layout issues too.
      ctrlA.setLanguageCode('en');
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('preview-user-tag'))).data,
        'You',
      );
      expect(find.text('How should your partner see you?'), findsOneWidget);

      ctrlA.setLanguageCode('it');
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('space-setup-name-field')),
        'Marco',
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('preview-user-tag'))).data,
        'Marco',
      );

      await tapVisible(
        tester,
        find.byKey(const Key('space-setup-submit-button')),
      );
      expect(find.byKey(const Key('recovery-key-setup-page')), findsOneWidget);
      await tapVisible(
        tester,
        find.byKey(const Key('recovery-saved-checkbox')),
      );
      await tapVisible(
        tester,
        find.byKey(const Key('confirm-recovery-button')),
      );
      expect(find.byKey(const Key('home-shell-page')), findsOneWidget);
      expect(ctrlA.deviceLabel, 'Marco');
      expect(server.deviceLabels[ctrlA.identity!.deviceId], 'Marco');

      // Update name again from Settings screen and check server + Noi tab stay in sync.
      await tapVisible(tester, find.byKey(const Key('open-settings-button')));
      await tester.enterText(
        find.byKey(const Key('settings-device-label-field')),
        'Marco P.',
      );
      await tapVisible(
        tester,
        find.byKey(const Key('settings-save-device-label-button')),
      );
      expect(ctrlA.deviceLabel, 'Marco P.');
      expect(server.deviceLabels[ctrlA.identity!.deviceId], 'Marco P.');

      await tapVisible(tester, find.byKey(const Key('settings-back-button')));
      await tapVisible(tester, find.text('Noi'));
      expect(find.text('Marco P.'), findsWidgets);
    },
  );

  testWidgets(
    'S1-D05/S1-D07 auto-detects partner join without pressing poll button, respects back, and resumes after regenerate',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final _MiniPairingServer server = _MiniPairingServer();
      final MockClient httpClient = MockClient(server.handle);

      final DeepSkyController ctrlA = DeepSkyController(
        keyStore: InMemorySecureKeyStore(),
        httpClient: httpClient,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
        inviteAutoPollInterval: const Duration(milliseconds: 250),
      );
      ctrlA.reduceMotion = true;

      final DeepSkyController ctrlB = DeepSkyController(
        keyStore: InMemorySecureKeyStore(),
        httpClient: httpClient,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
      );
      ctrlB.reduceMotion = true;

      await tester.pumpWidget(DeepSkyApp(controller: ctrlA));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding-page')), findsOneWidget);
      final String firstToken = server.lastInviteToken!;
      final String firstInviteUri = ctrlA.activeInviteUri!;

      // Before partner joins, automatic poll ticks quietly without errors or busy lock.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding-page')), findsOneWidget);
      expect(ctrlA.errorNotice, isNull);
      expect(ctrlA.statusNotice, isNull);
      expect(server.statusPollCount, greaterThanOrEqualTo(1));

      // Partner B joins -> next automatic poll moves Partner A to CodeVerificationPage.
      await ctrlB.initialize();
      await ctrlB.acceptInvite(
        serverUrl: 'https://couple.example.test',
        inviteToken: firstInviteUri,
        deviceLabel: 'Telefono B',
      );
      final String firstSas = ctrlB.pendingJoin!.sasCode;

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('code-verification-page')), findsOneWidget);
      expect(find.bySemanticsLabel('SAS $firstSas'), findsOneWidget);

      // Going back suppresses auto-reentry on the dismissed token.
      await tapVisible(
        tester,
        find.byKey(const Key('verification-back-button')),
      );
      expect(find.byKey(const Key('onboarding-page')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding-page')), findsOneWidget);

      // Regenerating creates a new invite and resumes automatic detection.
      await tapVisible(
        tester,
        find.byKey(const Key('regenerate-invite-button')),
      );
      final String secondToken = server.lastInviteToken!;
      expect(secondToken, isNot(firstToken));

      final DeepSkyController ctrlB2 = DeepSkyController(
        keyStore: InMemorySecureKeyStore(),
        httpClient: httpClient,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
      );
      ctrlB2.reduceMotion = true;
      await ctrlB2.initialize();
      await ctrlB2.acceptInvite(
        serverUrl: 'https://couple.example.test',
        inviteToken: ctrlA.activeInviteUri!,
        deviceLabel: 'Telefono B2',
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('code-verification-page')), findsOneWidget);
      expect(
        find.bySemanticsLabel('SAS ${ctrlB2.pendingJoin!.sasCode}'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Enrollment in Devices tab auto-detects new phone and app resume checks immediately',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final _MiniPairingServer server = _MiniPairingServer();
      final MockClient httpClient = MockClient(server.handle);

      final DeepSkyController ctrlA = DeepSkyController(
        keyStore: InMemorySecureKeyStore(),
        httpClient: httpClient,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
        inviteAutoPollInterval: const Duration(seconds: 5),
      );
      ctrlA.reduceMotion = true;

      final DeepSkyController ctrlB = DeepSkyController(
        keyStore: InMemorySecureKeyStore(),
        httpClient: httpClient,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
      );
      ctrlB.reduceMotion = true;

      // Test immediate check on AppLifecycleState.resumed during initial pairing.
      await tester.pumpWidget(DeepSkyApp(controller: ctrlA));
      await tester.pumpAndSettle();

      await ctrlB.initialize();
      await ctrlB.acceptInvite(
        serverUrl: 'https://couple.example.test',
        inviteToken: ctrlA.activeInviteUri!,
        deviceLabel: 'Telefono B',
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('code-verification-page')), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('confirm-sas-button')));
      await tapVisible(
        tester,
        find.byKey(const Key('space-setup-skip-button')),
      );
      await tapVisible(
        tester,
        find.byKey(const Key('recovery-saved-checkbox')),
      );
      await tapVisible(
        tester,
        find.byKey(const Key('confirm-recovery-button')),
      );
      expect(find.byKey(const Key('home-shell-page')), findsOneWidget);

      // Switch to Noi tab and create an enrollment invite.
      await tapVisible(tester, find.text('Noi'));
      await tapVisible(
        tester,
        find.byKey(const Key('create-enrollment-invite-button')),
      );
      expect(find.byKey(const Key('enroll-invite-token')), findsOneWidget);
      final String enrollCode = ctrlA.activeInviteManualCode!;

      // New phone C accepts the enrollment invite.
      final DeepSkyController ctrlC = DeepSkyController(
        keyStore: InMemorySecureKeyStore(),
        httpClient: httpClient,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => testCaps,
        defaultServerUrl: 'https://couple.example.test',
      );
      ctrlC.reduceMotion = true;
      await ctrlC.initialize();
      await ctrlC.acceptInvite(
        serverUrl: 'https://couple.example.test',
        inviteToken: enrollCode,
        deviceLabel: 'Telefono C',
      );
      final String expectedEnrollSas = ctrlC.pendingJoin!.sasCode;

      // Advance past the 5s auto-poll interval without pressing enroll-poll-invite-button.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('enroll-sas-code')), findsOneWidget);
      expect(
        find.text('Codice di verifica SAS: $expectedEnrollSas'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('enroll-confirm-sas-button')),
        findsOneWidget,
      );
    },
  );
}

class _MiniInviteRecord {
  _MiniInviteRecord({
    required this.token,
    required this.coupleId,
    required this.inviterDeviceId,
    required this.inviterLabel,
    required this.inviterAuthB64,
    required this.inviterKemB64,
  });

  final String token;
  final String coupleId;
  final String inviterDeviceId;
  final String inviterLabel;
  final String inviterAuthB64;
  final String inviterKemB64;

  String? acceptedDeviceId;
  String? acceptedLabel;
  String? acceptedAuthB64;
  String? acceptedKemB64;
}

class _MiniPairingServer {
  String? lastInviteToken;
  int _counter = 0;
  int statusPollCount = 0;

  final Map<String, Map<String, Object?>> _devices =
      <String, Map<String, Object?>>{};
  final Map<String, ({String authB64, String kemB64})> _deviceKeys =
      <String, ({String authB64, String kemB64})>{};
  final Map<String, String> deviceLabels = <String, String>{};
  final Map<String, _MiniInviteRecord> _invites = <String, _MiniInviteRecord>{};
  final Map<String, Map<String, Object?>> _keyDeliveries =
      <String, Map<String, Object?>>{};

  Future<http.Response> handle(http.Request req) async {
    final String path = req.url.path;
    final String? deviceId =
        req.headers['X-Device-Id'] ?? req.headers['x-device-id'];
    final Map<String, Object?> body = req.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(req.body) as Map<String, Object?>;

    if (req.method == 'POST' && path == '/api/v1/pairing/invites') {
      _counter += 1;
      const String coupleId = 'couple-1';
      final String inviterId = 'dev-$_counter';
      final String label = body['deviceLabel'] as String? ?? 'Device';
      _devices[inviterId] = <String, Object?>{
        'deviceId': inviterId,
        'label': label,
        'enrolledVia': 'PAIRING_INVITER',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'revokedAt': null,
      };
      deviceLabels[inviterId] = label;
      final String authB64 = body['deviceAuthPublicKeyB64'] as String;
      final String kemB64 = body['deviceKemPublicKeyB64'] as String;
      _deviceKeys[inviterId] = (authB64: authB64, kemB64: kemB64);

      final String inviteToken = 'TOK$_counter';
      lastInviteToken = inviteToken;
      _invites[inviteToken] = _MiniInviteRecord(
        token: inviteToken,
        coupleId: coupleId,
        inviterDeviceId: inviterId,
        inviterLabel: label,
        inviterAuthB64: authB64,
        inviterKemB64: kemB64,
      );
      return _json(<String, Object?>{
        'coupleId': coupleId,
        'deviceId': inviterId,
        'inviteToken': inviteToken,
        'expiresAt': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 15))
            .toIso8601String(),
      }, status: 201);
    }

    if (req.method == 'POST' && path == '/api/v1/pairing/enrollment-invites') {
      _counter += 1;
      final String inviterId = deviceId!;
      final String inviteToken = 'ENROLL$_counter';
      lastInviteToken = inviteToken;
      final keys = _deviceKeys[inviterId]!;
      _invites[inviteToken] = _MiniInviteRecord(
        token: inviteToken,
        coupleId: 'couple-1',
        inviterDeviceId: inviterId,
        inviterLabel: deviceLabels[inviterId] ?? 'Device',
        inviterAuthB64: keys.authB64,
        inviterKemB64: keys.kemB64,
      );
      return _json(<String, Object?>{
        'coupleId': 'couple-1',
        'deviceId': inviterId,
        'inviteToken': inviteToken,
        'expiresAt': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 15))
            .toIso8601String(),
      }, status: 201);
    }

    if (req.method == 'POST' && path == '/api/v1/pairing/invites/accept') {
      final _MiniInviteRecord invite = _invites[body['inviteToken'] as String]!;
      _counter += 1;
      final String joinerId = 'dev-$_counter';
      final String label = body['deviceLabel'] as String? ?? 'Device';
      invite.acceptedDeviceId = joinerId;
      invite.acceptedLabel = label;
      invite.acceptedAuthB64 = body['deviceAuthPublicKeyB64'] as String;
      invite.acceptedKemB64 = body['deviceKemPublicKeyB64'] as String;
      _devices[joinerId] = <String, Object?>{
        'deviceId': joinerId,
        'label': label,
        'enrolledVia': 'PAIRING_JOINER',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'revokedAt': null,
      };
      deviceLabels[joinerId] = label;
      return _json(<String, Object?>{
        'coupleId': invite.coupleId,
        'deviceId': joinerId,
        'peerDeviceId': invite.inviterDeviceId,
        'peerLabel': invite.inviterLabel,
        'peerAuthPublicKeyB64': invite.inviterAuthB64,
        'peerKemPublicKeyB64': invite.inviterKemB64,
      });
    }

    if (req.method == 'POST' && path == '/api/v1/pairing/invites/status') {
      statusPollCount += 1;
      final _MiniInviteRecord invite = _invites[body['inviteToken'] as String]!;
      return _json(<String, Object?>{
        'accepted': invite.acceptedDeviceId != null,
        'acceptedDeviceId': invite.acceptedDeviceId,
        'acceptedLabel': invite.acceptedLabel,
        'acceptedAuthPublicKeyB64': invite.acceptedAuthB64,
        'acceptedKemPublicKeyB64': invite.acceptedKemB64,
      });
    }

    if (req.method == 'POST' && path == '/api/v1/pairing/key-deliveries') {
      final String toDeviceId = body['toDeviceId'] as String;
      _keyDeliveries[toDeviceId] = <String, Object?>{
        'coupleId': 'couple-1',
        'fromDeviceId': deviceId,
        'toDeviceId': toDeviceId,
        'nonceB64': body['nonceB64'],
        'ciphertextB64': body['ciphertextB64'],
      };
      return _json(<String, Object?>{'status': 'DELIVERED'}, status: 201);
    }

    if (req.method == 'GET' && path == '/api/v1/pairing/key-deliveries/me') {
      final Map<String, Object?>? pending = _keyDeliveries[deviceId];
      if (pending == null) {
        return http.Response('', 204);
      }
      return _json(pending);
    }

    if (req.method == 'POST' && path == '/api/v1/pairing/key-deliveries/ack') {
      _keyDeliveries.remove(deviceId);
      return http.Response('', 204);
    }

    if (req.method == 'GET' && path == '/api/v1/pairing/devices') {
      return _json(_devices.values.toList());
    }

    if (req.method == 'PATCH' && path == '/api/v1/pairing/devices/me') {
      final String nextLabel = (body['deviceLabel'] as String? ?? '').trim();
      final Map<String, Object?> target = _devices[deviceId!]!;
      if (nextLabel.isNotEmpty) {
        target['label'] = nextLabel;
        deviceLabels[deviceId] = nextLabel;
      }
      return _json(target);
    }

    if (req.method == 'GET' && path == '/api/v1/sync/envelopes') {
      return _json(<String, Object?>{
        'items': const <Object?>[],
        'nextAfterSeq': 0,
        'hasMore': false,
      });
    }

    return _json(<String, Object?>{
      'message': 'Unhandled ${req.method} $path',
    }, status: 404);
  }

  http.Response _json(Object body, {int status = 200}) {
    return http.Response(
      jsonEncode(body),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );
  }
}
