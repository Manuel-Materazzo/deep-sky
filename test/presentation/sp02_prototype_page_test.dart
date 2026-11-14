import 'package:deep_sky/data/pairing_and_sync_repository.dart';
import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/presentation/deep_sky_app.dart';
import 'package:deep_sky/presentation/pairing/sp02_prototype_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('SP-02 prototype screen renders pairing and recovery actions', (
    WidgetTester tester,
  ) async {
    final PairingAndSyncRepository repo = PairingAndSyncRepository(
      keyStore: InMemorySecureKeyStore(),
    );

    await tester.pumpWidget(
      DeepSkyApp(home: Sp02PrototypePage(repository: repo)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Deep Sky · SP-02 E2EE'), findsOneWidget);
    expect(find.text('Crea invito di abbinamento'), findsOneWidget);
    expect(find.text('Unisciti con invito'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Recupera la casa'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Recupera la casa'), findsOneWidget);
  });
}
