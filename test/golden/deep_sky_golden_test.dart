import 'dart:convert';
import 'dart:io';

import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/domain/platform_capabilities.dart';
import 'package:deep_sky/presentation/deep_sky_app.dart';
import 'package:deep_sky/presentation/deep_sky_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'Deep Sky Intimate Sanctuary welcome screen matches dark & light golden snapshots',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final String pilotManifestRaw = File(
        'content/packs/ds2_pilot/manifest.json',
      ).readAsStringSync();

      final MockClient mockHttp = MockClient((http.Request req) async {
        if (req.method == 'POST' && req.url.path == '/api/v1/pairing/invites') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'coupleId': 'couple-golden',
              'deviceId': 'dev-golden',
              'inviteToken': 'golden_tok_8492a1f',
              'expiresAt': DateTime.now()
                  .toUtc()
                  .add(const Duration(minutes: 15))
                  .toIso8601String(),
            }),
            201,
            headers: const <String, String>{'Content-Type': 'application/json'},
          );
        }
        return http.Response('{}', 503);
      });

      final DeepSkyController controller = DeepSkyController(
        keyStore: InMemorySecureKeyStore(),
        httpClient: mockHttp,
        loadAssetString: (_) async => pilotManifestRaw,
        loadCapabilities: () async => const PlatformCapabilities(
          packageName: 'com.vectevo.deep_sky',
          androidApiLevel: 35,
          versionName: '1.0.0',
          versionCode: 1,
          supportsRequestInstallPackages: false,
        ),
      );
      controller.reduceMotion = true;

      await tester.pumpWidget(DeepSkyApp(controller: controller));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DeepSkyApp),
        matchesGoldenFile('goldens/onboarding_dark.png'),
      );

      controller.toggleNightMode();
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DeepSkyApp),
        matchesGoldenFile('goldens/onboarding_light.png'),
      );
    },
  );
}
