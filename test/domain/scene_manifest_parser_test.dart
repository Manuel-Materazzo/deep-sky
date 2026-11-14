import 'dart:io';

import 'package:deep_sky/data/scene_manifest_parser.dart';
import 'package:deep_sky/scene/scene_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const SceneManifestParser parser = SceneManifestParser();

  test('parses base content pack manifest', () {
    final String raw = File('content/packs/base/manifest.json')
        .readAsStringSync();
    final SceneManifest manifest = parser.parseJson(raw);

    expect(manifest.packId, 'base');
    expect(manifest.packVersion, '0.1.0');
    expect(manifest.minAppProtocol, 1);
    expect(manifest.name.resolve('it'), 'Casa base');
    expect(manifest.name.resolve('en'), 'Base Home');
    expect(manifest.slots, isEmpty);
  });

  test('parses example content pack manifest with slots and animations', () {
    final String raw = File('content/packs/example/manifest.json')
        .readAsStringSync();
    final SceneManifest manifest = parser.parseJson(raw);

    expect(manifest.packId, 'example-living-room');
    expect(manifest.slots, hasLength(2));

    final SceneSlot window = manifest.slots.first;
    expect(window.id, 'window');
    expect(window.replaceable, isFalse);
    expect(window.defaultState, 'calm');
    expect(window.states.keys, containsAll(<String>['calm', 'lit']));
    expect(window.animations, hasLength(1));
    expect(window.animations.first.type, 'fade');
  });

  test('rejects manifest when defaultState is missing from states', () {
    const String invalidJson = '''
    {
      "schemaVersion": 1,
      "packId": "broken",
      "packVersion": "0.1.0",
      "minAppProtocol": 1,
      "name": {"it": "Test", "en": "Test"},
      "scene": {"aspectRatio": "9:16"},
      "slots": [
        {
          "id": "lamp",
          "description": "Lamp",
          "zIndex": 1,
          "replaceable": true,
          "bounds": {"x": 0.1, "y": 0.1, "width": 0.2, "height": 0.2},
          "touchArea": {"x": 0.1, "y": 0.1, "width": 0.2, "height": 0.2},
          "accessibilityLabel": {"it": "Lampada", "en": "Lamp"},
          "defaultState": "missing",
          "states": {"off": {"layers": []}},
          "animations": []
        }
      ]
    }
    ''';

    expect(() => parser.parseJson(invalidJson), throwsFormatException);
  });
}
