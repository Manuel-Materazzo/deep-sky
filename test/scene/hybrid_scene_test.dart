import 'dart:io';

import 'package:deep_sky/data/scene_manifest_parser.dart';
import 'package:deep_sky/presentation/home/sp04_hybrid_home_page.dart';
import 'package:deep_sky/scene/asset_override_registry.dart';
import 'package:deep_sky/scene/scene_manifest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final String rawSp04Manifest = File('content/packs/sp04_room/manifest.json')
      .readAsStringSync();
  final SceneManifest manifest = const SceneManifestParser().parseJson(
    rawSp04Manifest,
  );

  test('parses sp04_room manifest background and animated slots', () {
    expect(manifest.packId, 'sp04-hybrid-room');
    expect(manifest.background?.dayAsset, 'assets/bg_day.png');
    expect(manifest.background?.nightAsset, 'assets/bg_night.png');
    expect(manifest.slots, hasLength(7));
    expect(manifest.numericAspectRatio, closeTo(9 / 16, 0.001));
  });

  test('AssetOverrideRegistry swaps and restores layer asset without mutating manifest', () {
    final SceneSlot petSlot = manifest.slots.firstWhere(
      (SceneSlot s) => s.id == 'pet',
    );
    final SceneLayer petBody = petSlot.states[petSlot.defaultState]!.single;
    expect(petBody.asset, 'assets/pet_cat.png');

    const AssetOverrideRegistry empty = AssetOverrideRegistry();
    expect(empty.resolveAsset('pet', petBody), 'assets/pet_cat.png');

    final AssetOverrideRegistry overridden = empty.withOverride(
      slotId: 'pet',
      layerId: 'pet_body',
      overrideAsset: 'assets/pet_fox_override.png',
    );
    expect(
      overridden.resolveAsset('pet', petBody),
      'assets/pet_fox_override.png',
    );
    // Original manifest stays unmodified.
    expect(petBody.asset, 'assets/pet_cat.png');

    final AssetOverrideRegistry restored = overridden.withoutOverride(
      slotId: 'pet',
      layerId: 'pet_body',
    );
    expect(restored.resolveAsset('pet', petBody), 'assets/pet_cat.png');
  });

  for (final ({String label, Size size}) viewport
      in <({String label, Size size})>[
        (label: '9:16 standard phone', size: const Size(390, 693)),
        (label: '9:20 tall phone', size: const Size(360, 800)),
        (label: '16:10 compact tablet landscape', size: const Size(800, 500)),
      ]) {
    testWidgets(
      'SP-04 hybrid home preserves touch areas and card separation at ${viewport.label}',
      (WidgetTester tester) async {
        tester.view.physicalSize = viewport.size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: Sp04HybridHomePage(
              initialManifest: manifest,
              initialReduceMotion: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('sp04-bottom-nav')), findsOneWidget);
        expect(find.byKey(const Key('sp04-status-card')), findsOneWidget);
        expect(find.byKey(const Key('sp04-scene-canvas')), findsOneWidget);

        final Rect statusRect = tester.getRect(
          find.byKey(const Key('sp04-status-card')),
        );
        final Rect sceneRect = tester.getRect(
          find.byKey(const Key('sp04-scene-canvas')),
        );
        expect(statusRect.overlaps(sceneRect), isFalse);

        // Verify scene aspect ratio and slot touch boxes stay aligned within sceneRect.
        expect(
          sceneRect.width / sceneRect.height,
          closeTo(manifest.numericAspectRatio, 0.02),
        );

        final Finder petSlotFinder = find.byKey(const Key('scene-slot-pet'));
        expect(petSlotFinder, findsOneWidget);
        final Rect petRect = tester.getRect(petSlotFinder);
        expect(sceneRect.contains(petRect.center), isTrue);

        // Scroll scene/slot cleanly above NavigationBar before tapping.
        await tester.drag(
          find.byKey(const Key('sp04-home-scroll')),
          const Offset(0, -160),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(petSlotFinder);
        await tester.tap(petSlotFinder);
        await tester.pumpAndSettle();
        expect(find.textContaining('volpe (override)'), findsOneWidget);

        await tester.tap(petSlotFinder);
        await tester.pumpAndSettle();
        expect(find.textContaining('gatto predefinito'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'Reduce motion freezes level-1 animations and exposes accessibility semantics',
    (WidgetTester tester) async {
      final SemanticsHandle semanticsHandle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Sp04HybridHomePage(
              initialManifest: manifest,
              initialReduceMotion: false,
            ),
          ),
        );
        // Advance repeating animations cleanly.
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // Switch Reduce Motion on: pumpAndSettle now settles completely because Ticker repeating stopped.
        await tester.tap(find.byKey(const Key('sp04-toggle-reduce-motion')));
        await tester.pumpAndSettle();
        expect(find.text('Riduci movimento: true'), findsOneWidget);

        // Check slot accessibility labels are present in semantic tree.
        expect(
          find.bySemanticsLabel(
            'Finestra della stanza, cambia luce giorno o notte',
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            'Animale domestico, tocca per cambiare aspetto',
          ),
          findsOneWidget,
        );
      } finally {
        semanticsHandle.dispose();
      }
    },
  );
}
