import 'package:deep_sky/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Deep Sky placeholder home renders title and message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DeepSkyApp());

    expect(find.text('Deep Sky'), findsOneWidget);
    expect(find.text('La nostra casa'), findsOneWidget);
    expect(
      find.text(
        'Uno spazio privato per due persone.\nPiccoli gesti, senza fretta.',
      ),
      findsOneWidget,
    );
  });
}
