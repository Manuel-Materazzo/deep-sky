import 'package:deep_sky/presentation/deep_sky_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

export 'package:deep_sky/presentation/deep_sky_app.dart';

/// Maximum decoded image cache size enforced on mobile (`ADR-0007`, `S2-APP-03`).
const int kDeepSkyImageCacheMaxBytes = 48 * 1024 * 1024;

void _registerBundledFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final String plusJakartaOfl = await rootBundle.loadString(
      'assets/fonts/plus_jakarta_sans/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(const <String>[
      'Plus Jakarta Sans',
    ], plusJakartaOfl);

    final String nunitoOfl = await rootBundle.loadString(
      'assets/fonts/nunito_sans/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(const <String>['Nunito Sans'], nunitoOfl);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      kDeepSkyImageCacheMaxBytes;
  _registerBundledFontLicenses();
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  runApp(const DeepSkyApp());
}
