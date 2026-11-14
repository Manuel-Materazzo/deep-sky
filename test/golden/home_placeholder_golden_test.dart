import 'package:deep_sky/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('Deep Sky placeholder home matches golden snapshot', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const DeepSkyApp());
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DeepSkyApp),
      matchesGoldenFile('goldens/home_placeholder.png'),
    );
  });
}
