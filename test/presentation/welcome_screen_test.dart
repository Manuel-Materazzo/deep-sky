import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/data/secure_key_store.dart';
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

  const PlatformCapabilities testCaps = PlatformCapabilities(
    packageName: 'com.vectevo.deep_sky',
    androidApiLevel: 35,
    versionName: '1.0.0',
    versionCode: 1,
    supportsRequestInstallPackages: false,
  );

  DeepSkyController makeController({
    required http.Client httpClient,
    InMemorySecureKeyStore? keyStore,
  }) {
    final DeepSkyController c = DeepSkyController(
      keyStore: keyStore ?? InMemorySecureKeyStore(),
      httpClient: httpClient,
      loadAssetString: (_) async => pilotManifestRaw,
      loadCapabilities: () async => testCaps,
    );
    c.reduceMotion = true;
    return c;
  }

  testWidgets(
    'Welcome screen auto-creates invite, copies link, customizes server, and switches theme/language',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      String? copiedClipboardText;
      const MethodChannel platformChannel = MethodChannel(
        NativeBridge.channelName,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platformChannel, (MethodCall call) async {
            return null;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall call,
          ) async {
            if (call.method == 'Clipboard.setData') {
              final Map<Object?, Object?> args =
                  call.arguments as Map<Object?, Object?>;
              copiedClipboardText = args['text'] as String?;
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(platformChannel, null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final List<Uri> requestedUrls = <Uri>[];
      int inviteSeq = 0;
      final MockClient httpClient = MockClient((http.Request req) async {
        requestedUrls.add(req.url);
        if (req.method == 'POST' && req.url.path == '/api/v1/pairing/invites') {
          final String token = 'tok-welcome-${++inviteSeq}';
          return http.Response(
            jsonEncode(<String, Object?>{
              'coupleId': 'couple-$inviteSeq',
              'deviceId': 'dev-$inviteSeq',
              'inviteToken': token,
              'expiresAt': DateTime.now()
                  .toUtc()
                  .add(const Duration(minutes: 15))
                  .toIso8601String(),
            }),
            201,
            headers: const <String, String>{'Content-Type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      final DeepSkyController controller = makeController(
        httpClient: httpClient,
      );
      await tester.pumpWidget(DeepSkyApp(controller: controller));
      await tester.pumpAndSettle();

      // Auto-invite state (`S1-D02`, `S1-D03`, `S1-D05`)
      expect(find.byKey(const Key('onboarding-page')), findsOneWidget);
      expect(find.text('La vostra casa'), findsOneWidget);
      expect(find.byKey(const Key('invite-qr-view')), findsOneWidget);
      expect(find.byKey(const Key('share-invite-button')), findsOneWidget);
      expect(find.textContaining('Scade tra'), findsOneWidget);
      expect(find.text('Ufficiale (deepsky.vectevo.com)'), findsOneWidget);
      expect(
        find.text('Crittografia punto a punto • Solo per voi due'),
        findsOneWidget,
      );
      final List<Uri> inviteRequests = requestedUrls
          .where((Uri u) => u.path == '/api/v1/pairing/invites')
          .toList();
      expect(inviteRequests, hasLength(1));
      expect(
        inviteRequests.first.toString(),
        'https://deepsky.vectevo.com/api/v1/pairing/invites',
      );

      // Copy link bar copies full fragment link and flips badge to Copiato!
      await tester.ensureVisible(
        find.byKey(const Key('copy-invite-link-button')),
      );
      await tester.tap(find.byKey(const Key('copy-invite-link-button')));
      await tester.pumpAndSettle();
      expect(
        copiedClipboardText,
        'https://deepsky.vectevo.com/join#token=tok-welcome-1',
      );
      expect(find.text('Copiato!'), findsOneWidget);

      // Expand server drawer and save custom LAN IP
      await tester.ensureVisible(
        find.byKey(const Key('toggle-server-drawer-button')),
      );
      await tester.tap(find.byKey(const Key('toggle-server-drawer-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding-server-field')), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('onboarding-server-field')),
      );
      await tester.enterText(
        find.byKey(const Key('onboarding-server-field')),
        '192.168.1.50:8080',
      );
      await tester.ensureVisible(find.byKey(const Key('save-server-button')));
      await tester.tap(find.byKey(const Key('save-server-button')));
      await tester.pumpAndSettle();

      expect(controller.activeServerUrl, 'http://192.168.1.50:8080');
      expect(
        requestedUrls.last.toString(),
        'http://192.168.1.50:8080/api/v1/pairing/invites',
      );
      expect(
        controller.activeInviteUri,
        'https://deepsky.vectevo.com/join#server=http%3A%2F%2F192.168.1.50%3A8080&token=tok-welcome-2',
      );
      expect(find.text('Personalizzato (192.168.1.50:8080)'), findsOneWidget);

      // Re-open server drawer (save collapses it cleanly) and reset to official server
      await tester.ensureVisible(
        find.byKey(const Key('toggle-server-drawer-button')),
      );
      await tester.tap(find.byKey(const Key('toggle-server-drawer-button')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('reset-server-button')));
      await tester.tap(find.byKey(const Key('reset-server-button')));
      await tester.pumpAndSettle();
      expect(controller.activeServerUrl, 'https://deepsky.vectevo.com');
      expect(find.text('Ufficiale (deepsky.vectevo.com)'), findsOneWidget);

      // Preferences sheet switches theme & language live
      await tester.ensureVisible(
        find.byKey(const Key('welcome-preferences-button')),
      );
      await tester.tap(find.byKey(const Key('welcome-preferences-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('preferences-theme-switch')), findsOneWidget);

      await tester.tap(find.byKey(const Key('preferences-theme-switch')));
      await tester.pumpAndSettle();
      expect(controller.isNight, isFalse);

      await tester.tap(find.byKey(const Key('preferences-lang-en')));
      await tester.pumpAndSettle();
      expect(controller.languageCode, 'en');

      // Dismiss bottom sheet and check English welcome copy
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('Your home'), findsOneWidget);
      expect(find.text('Share invite link'), findsOneWidget);

      // Help sheet explains privacy & pairing calmly
      await tester.ensureVisible(find.byKey(const Key('welcome-help-button')));
      await tester.tap(find.byKey(const Key('welcome-help-button')));
      await tester.pumpAndSettle();
      expect(find.text('How Deep Sky works'), findsOneWidget);
      expect(find.text('End-to-end encryption'), findsOneWidget);
    },
  );

  testWidgets(
    'Welcome screen handles initial server failure calmly and recovers on retry',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      bool failServer = true;
      final MockClient httpClient = MockClient((http.Request req) async {
        if (failServer) {
          return http.Response('{"message":"unavailable"}', 503);
        }
        return http.Response(
          jsonEncode(<String, Object?>{
            'coupleId': 'couple-retry',
            'deviceId': 'dev-retry',
            'inviteToken': 'tok-retry-1',
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 15))
                .toIso8601String(),
          }),
          201,
          headers: const <String, String>{'Content-Type': 'application/json'},
        );
      });

      final DeepSkyController controller = makeController(
        httpClient: httpClient,
      );
      await tester.pumpWidget(DeepSkyApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Non riusciamo a preparare l\'invito'), findsOneWidget);
      expect(find.byKey(const Key('create-invite-button')), findsOneWidget);
      expect(find.byKey(const Key('invite-qr-view')), findsNothing);

      failServer = false;
      await tester.ensureVisible(find.byKey(const Key('create-invite-button')));
      await tester.tap(find.byKey(const Key('create-invite-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('invite-qr-view')), findsOneWidget);
      expect(find.textContaining('tok-retry-1'), findsOneWidget);
    },
  );

  testWidgets(
    'Switching tabs updates hero title/description and QR scanner fills Unisciti and Recupera inputs',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      String? scanMode;
      const MethodChannel platformChannel = MethodChannel(
        NativeBridge.channelName,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platformChannel, (MethodCall call) async {
            if (call.method == 'scanQrCode') {
              if (scanMode == 'denied') {
                throw PlatformException(
                  code: 'camera_permission_denied',
                  message: 'Denied',
                );
              }
              if (scanMode == 'invite') {
                return 'https://deepsky.vectevo.com/join#server=http%3A%2F%2F192.168.1.99%3A8080&token=tok_qr_joined';
              }
              if (scanMode == 'recovery') {
                return 'stella notte cammino lanterna';
              }
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(platformChannel, null);
      });

      final SimpleKeyPair peerAuth = await Ed25519().newKeyPair();
      final SimplePublicKey peerAuthPub = await peerAuth.extractPublicKey();
      final SimpleKeyPair peerKem = await X25519().newKeyPair();
      final SimplePublicKey peerKemPub = await peerKem.extractPublicKey();

      final List<Uri> acceptRequests = <Uri>[];
      final MockClient httpClient = MockClient((http.Request req) async {
        if (req.method == 'POST' && req.url.path == '/api/v1/pairing/invites') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'coupleId': 'c-1',
              'deviceId': 'd-1',
              'inviteToken': 'tok-init',
              'expiresAt': DateTime.now()
                  .toUtc()
                  .add(const Duration(minutes: 15))
                  .toIso8601String(),
            }),
            201,
            headers: const <String, String>{'Content-Type': 'application/json'},
          );
        }
        if (req.method == 'POST' &&
            req.url.path == '/api/v1/pairing/invites/tok_qr_joined/accept') {
          acceptRequests.add(req.url);
          return http.Response(
            jsonEncode(<String, Object?>{
              'coupleId': 'c-qr',
              'deviceId': 'd-join-qr',
              'peerDeviceId': 'd-inviter-qr',
              'peerLabel': 'Partner QR',
              'peerAuthPublicKeyB64': base64UrlEncode(peerAuthPub.bytes),
              'peerKemPublicKeyB64': base64UrlEncode(peerKemPub.bytes),
            }),
            200,
            headers: const <String, String>{'Content-Type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      final DeepSkyController controller = makeController(
        httpClient: httpClient,
      );
      await tester.pumpWidget(DeepSkyApp(controller: controller));
      await tester.pumpAndSettle();

      // Invita hero
      expect(find.text('La vostra casa'), findsOneWidget);
      expect(
        find.text('Uno spazio intimo e privato, solo per voi due'),
        findsOneWidget,
      );

      // Switch to Recupera tab -> dynamic hero title & description + QR scan button
      await tester.tap(find.byKey(const Key('welcome-tab-recover')));
      await tester.pumpAndSettle();
      expect(find.text('Ritrova la tua stanza'), findsOneWidget);
      expect(find.textContaining('24 parole segrete'), findsOneWidget);

      scanMode = 'recovery';
      await tester.ensureVisible(
        find.byKey(const Key('scan-recovery-qr-button')),
      );
      await tester.tap(find.byKey(const Key('scan-recovery-qr-button')));
      await tester.pumpAndSettle();
      final TextField recoveryField = tester.widget<TextField>(
        find.byKey(const Key('recovery-words-field')),
      );
      expect(recoveryField.controller?.text, 'stella notte cammino lanterna');

      // Switch to Unisciti tab -> dynamic hero title & description + QR camera card
      await tester.ensureVisible(find.byKey(const Key('welcome-tab-join')));
      await tester.tap(find.byKey(const Key('welcome-tab-join')));
      await tester.pumpAndSettle();
      expect(find.text('Raggiungi chi ami'), findsOneWidget);
      expect(find.textContaining('inquadra il suo schermo'), findsOneWidget);
      expect(find.byKey(const Key('scan-invite-qr-button')), findsOneWidget);

      // Camera permission denied shows calm notice
      scanMode = 'denied';
      await tester.ensureVisible(
        find.byKey(const Key('scan-invite-qr-button')),
      );
      await tester.tap(find.byKey(const Key('scan-invite-qr-button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Permesso fotocamera'), findsOneWidget);

      // Valid QR scan parses server + token and transitions to SAS verification
      scanMode = 'invite';
      await tester.ensureVisible(
        find.byKey(const Key('scan-invite-qr-button')),
      );
      await tester.tap(find.byKey(const Key('scan-invite-qr-button')));
      await tester.pumpAndSettle();
      expect(acceptRequests, hasLength(1));
      expect(
        acceptRequests.first.toString(),
        'http://192.168.1.99:8080/api/v1/pairing/invites/tok_qr_joined/accept',
      );
      expect(find.byKey(const Key('joiner-sas-code')), findsOneWidget);
    },
  );
}
