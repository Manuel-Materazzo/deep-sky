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
  testWidgets('Deep Sky DS-2 onboarding matches golden snapshot', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final String pilotManifestRaw = File(
      'content/packs/ds2_pilot/manifest.json',
    ).readAsStringSync();

    final DeepSkyController controller = DeepSkyController(
      keyStore: InMemorySecureKeyStore(),
      httpClient: MockClient((_) async => http.Response('{}', 503)),
      loadAssetString: (_) async => pilotManifestRaw,
      loadCapabilities: () async => const PlatformCapabilities(
        packageName: 'com.vectevo.deep_sky',
        androidApiLevel: 35,
        versionName: '1.0.0',
        versionCode: 1,
        supportsRequestInstallPackages: false,
      ),
    );

    await tester.pumpWidget(DeepSkyApp(controller: controller));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DeepSkyApp),
      matchesGoldenFile('goldens/onboarding_light.png'),
    );
  });
}
