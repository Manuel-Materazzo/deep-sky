import 'dart:io';

import 'package:deep_sky/data/encrypted_local_cache.dart';
import 'package:deep_sky/data/scene_manifest_parser.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';
import 'package:deep_sky/presentation/theme/deep_sky_theme.dart';
import 'package:deep_sky/scene/asset_override_registry.dart';
import 'package:deep_sky/scene/hybrid_scene_canvas.dart';
import 'package:deep_sky/scene/scene_manifest.dart';
import 'package:deep_sky/scene/scene_state_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const SceneManifestParser parser = SceneManifestParser();
  late SceneManifest manifest;

  setUpAll(() {
    final String rawJson = File('content/packs/ds2_pilot/manifest.json')
        .readAsStringSync();
    manifest = parser.parseJson(rawJson);
  });

  test(
    'DS-2 pilot manifest loads slots, default calm window, and animations',
    () {
      expect(manifest.packId, 'ds2-pilot-room');
      expect(manifest.packVersion, '0.2.0');
      expect(manifest.slots.length, 7);
      expect(manifest.numericAspectRatio, closeTo(9 / 16, 0.001));
      final SceneSlot windowSlot = manifest.slots.firstWhere(
        (SceneSlot s) => s.id == 'window',
      );
      expect(windowSlot.defaultState, 'calm');
      expect(windowSlot.states.keys, containsAll(<String>['calm', 'lit']));
    },
  );

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
    expect(petBody.asset, 'assets/pet_cat.png');

    final AssetOverrideRegistry restored = overridden.withoutOverride(
      slotId: 'pet',
      layerId: 'pet_body',
    );
    expect(restored.resolveAsset('pet', petBody), 'assets/pet_cat.png');
  });

  test(
    'SceneStateMapper activates window lit state when recent thought arrives',
    () {
      const SceneStateMapper mapper = SceneStateMapper();
      final DateTime now = DateTime.utc(2026, 11, 15, 12, 0);

      final SceneStateSnapshot emptyState = mapper.derive(
        events: const <CachedEventEntry>[],
        localDeviceId: 'dev-a',
        nowUtc: now,
      );
      expect(emptyState.windowLit, isFalse);
      expect(emptyState.slotStates['window'], 'calm');

      final CachedEventEntry recentPartnerThought = CachedEventEntry(
        envelopeId: 'env-1',
        coupleId: 'couple-1',
        senderDeviceId: 'dev-b',
        channel: EnvelopeChannel.event,
        keyEpoch: 1,
        seq: 1,
        createdAtServer: now.subtract(const Duration(minutes: 10)),
        payload: DecryptedEnvelopePayload(
          schemaVersion: 1,
          eventType: 'thinking_of_you',
          createdAtClient: now.subtract(const Duration(minutes: 10)),
          authorDeviceId: 'dev-b',
          body: const <String, Object?>{'note': 'Un caffè insieme'},
        ),
      );

      final SceneStateSnapshot litState = mapper.derive(
        events: <CachedEventEntry>[recentPartnerThought],
        localDeviceId: 'dev-a',
        nowUtc: now,
      );
      expect(litState.windowLit, isTrue);
      expect(litState.slotStates['window'], 'lit');
      expect(litState.fromPartner, isTrue);
      expect(litState.latestThought?.payload.body['note'], 'Un caffè insieme');
    },
  );

  for (final ({String label, Size size}) viewport
      in <({String label, Size size})>[
        (label: '9:16 standard phone', size: const Size(390, 693)),
        (label: '9:20 tall phone', size: const Size(360, 800)),
        (label: '16:10 compact tablet landscape', size: const Size(800, 500)),
      ]) {
    testWidgets(
      'HybridSceneCanvas preserves touch areas and card separation at ${viewport.label}',
      (WidgetTester tester) async {
        tester.view.physicalSize = viewport.size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        String? tappedSlotId;
        await tester.pumpWidget(
          MaterialApp(
            theme: DeepSkyTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    const Card(
                      key: Key('ds2-status-card'),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Stato tranquillo'),
                      ),
                    ),
                    HybridSceneCanvas(
                      key: const Key('ds2-scene-canvas'),
                      manifest: manifest,
                      packAssetRoot: 'content/packs/ds2_pilot',
                      reduceMotion: true,
                      onSlotTapped: (SceneSlot slot) {
                        tappedSlotId = slot.id;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final Rect statusRect = tester.getRect(
          find.byKey(const Key('ds2-status-card')),
        );
        final Rect sceneRect = tester.getRect(
          find.byKey(const Key('ds2-scene-canvas')),
        );
        expect(statusRect.overlaps(sceneRect), isFalse);
        expect(
          sceneRect.width / sceneRect.height,
          closeTo(manifest.numericAspectRatio, 0.02),
        );

        final Finder petSlotFinder = find.byKey(const Key('scene-slot-pet'));
        expect(petSlotFinder, findsOneWidget);
        expect(
          sceneRect.contains(tester.getRect(petSlotFinder).center),
          isTrue,
        );

        await tester.ensureVisible(petSlotFinder);
        await tester.tap(petSlotFinder);
        await tester.pumpAndSettle();
        expect(tappedSlotId, 'pet');
      },
    );
  }

  testWidgets(
    'Reduce motion freezes level-1 animations and exposes accessibility semantics',
    (WidgetTester tester) async {
      final SemanticsHandle semanticsHandle = tester.ensureSemantics();
      bool reduceMotion = false;
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: DeepSkyTheme.light(),
            home: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Scaffold(
                  body: Column(
                    children: <Widget>[
                      ElevatedButton(
                        key: const Key('toggle-reduce-motion'),
                        onPressed: () =>
                            setState(() => reduceMotion = !reduceMotion),
                        child: Text('Reduce: $reduceMotion'),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: HybridSceneCanvas(
                            manifest: manifest,
                            packAssetRoot: 'content/packs/ds2_pilot',
                            reduceMotion: reduceMotion,
                            slotStates: const <String, String>{'window': 'lit'},
                            onSlotTapped: (_) {},
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.byKey(const Key('toggle-reduce-motion')));
        await tester.pumpAndSettle();
        expect(find.text('Reduce: true'), findsOneWidget);

        expect(
          find.bySemanticsLabel(
            'Finestra della stanza, indica un pensiero in arrivo o la luce del cielo',
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
