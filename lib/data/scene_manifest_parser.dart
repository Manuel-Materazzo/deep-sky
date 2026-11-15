import 'dart:convert';

import 'package:deep_sky/scene/scene_manifest.dart';

/// Parses and validates a JSON scene pack manifest (CNT-01, TC-08).
class SceneManifestParser {
  const SceneManifestParser();

  SceneManifest parseJson(String rawJson) {
    final Object? decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Manifest root must be a JSON object.');
    }

    final int schemaVersion = _requireInt(decoded, 'schemaVersion');
    final String packId = _requireString(decoded, 'packId');
    final String packVersion = _requireString(decoded, 'packVersion');
    final int minAppProtocol = _requireInt(decoded, 'minAppProtocol');
    final LocalizedText name = _parseLocalized(decoded['name'], 'name');

    final Object? sceneRaw = decoded['scene'];
    if (sceneRaw is! Map<String, Object?>) {
      throw const FormatException('Missing or invalid "scene" object.');
    }
    final String aspectRatio = _requireString(sceneRaw, 'aspectRatio');
    final SceneBackground? background = _parseBackground(
      sceneRaw['background'],
    );

    final Object? slotsRaw = decoded['slots'];
    if (slotsRaw is! List<Object?>) {
      throw const FormatException('Missing or invalid "slots" array.');
    }

    final List<SceneSlot> slots = slotsRaw
        .map((Object? item) => _parseSlot(item))
        .toList(growable: false);

    return SceneManifest(
      schemaVersion: schemaVersion,
      packId: packId,
      packVersion: packVersion,
      minAppProtocol: minAppProtocol,
      name: name,
      aspectRatio: aspectRatio,
      slots: slots,
      background: background,
    );
  }

  SceneBackground? _parseBackground(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is! Map<String, Object?>) {
      throw const FormatException('Invalid "scene.background" object.');
    }
    final String dayAsset = (raw['dayAsset'] as String?)?.trim() ?? '';
    final String nightAsset = (raw['nightAsset'] as String?)?.trim() ?? '';
    if (dayAsset.isEmpty || nightAsset.isEmpty) {
      return null;
    }
    return SceneBackground(dayAsset: dayAsset, nightAsset: nightAsset);
  }

  SceneSlot _parseSlot(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const FormatException('Each slot must be a JSON object.');
    }
    final String id = _requireString(raw, 'id');
    final String description = _requireString(raw, 'description');
    final int zIndex = _requireInt(raw, 'zIndex');
    final Object? replaceableRaw = raw['replaceable'];
    if (replaceableRaw is! bool) {
      throw FormatException('Slot "$id" missing boolean "replaceable".');
    }

    final NormalizedRect bounds = _parseRect(
      raw['bounds'],
      'slots[$id].bounds',
    );
    final NormalizedRect touchArea = _parseRect(
      raw['touchArea'],
      'slots[$id].touchArea',
    );
    final LocalizedText accessibilityLabel = _parseLocalized(
      raw['accessibilityLabel'],
      'slots[$id].accessibilityLabel',
    );
    final String defaultState = _requireString(raw, 'defaultState');
    final Map<String, List<SceneLayer>> states = _parseStates(
      raw['states'],
      id,
      defaultState,
    );
    final List<SceneAnimation> animations = _parseAnimations(
      raw['animations'],
      id,
    );

    return SceneSlot(
      id: id,
      description: description,
      zIndex: zIndex,
      replaceable: replaceableRaw,
      bounds: bounds,
      touchArea: touchArea,
      accessibilityLabel: accessibilityLabel,
      defaultState: defaultState,
      states: states,
      animations: animations,
    );
  }

  Map<String, List<SceneLayer>> _parseStates(
    Object? raw,
    String slotId,
    String defaultState,
  ) {
    if (raw is! Map<String, Object?> || raw.isEmpty) {
      throw FormatException('Slot "$slotId" must define at least one state.');
    }
    if (!raw.containsKey(defaultState)) {
      throw FormatException(
        'Slot "$slotId" defaultState "$defaultState" does not exist in states.',
      );
    }

    final Map<String, List<SceneLayer>> result = <String, List<SceneLayer>>{};
    for (final MapEntry<String, Object?> entry in raw.entries) {
      final Object? stateObj = entry.value;
      if (stateObj is! Map<String, Object?> ||
          stateObj['layers'] is! List<Object?>) {
        throw FormatException(
          'Slot "$slotId" state "${entry.key}" must contain a layers array.',
        );
      }
      final List<Object?> rawLayers = stateObj['layers']! as List<Object?>;
      result[entry.key] = rawLayers
          .map((Object? layerObj) {
            if (layerObj is! Map<String, Object?>) {
              throw FormatException(
                'Invalid layer in slot "$slotId" state "${entry.key}".',
              );
            }
            return SceneLayer(
              id: _requireString(layerObj, 'id'),
              asset: _requireString(layerObj, 'asset'),
              zOffset: _requireInt(layerObj, 'zOffset'),
              opacity: (layerObj['opacity'] as num?)?.toDouble() ?? 1.0,
            );
          })
          .toList(growable: false);
    }
    return Map<String, List<SceneLayer>>.unmodifiable(result);
  }

  List<SceneAnimation> _parseAnimations(Object? raw, String slotId) {
    if (raw is! List<Object?>) {
      throw FormatException('Slot "$slotId" must define an animations array.');
    }
    return raw
        .map((Object? animObj) {
          if (animObj is! Map<String, Object?>) {
            throw FormatException('Invalid animation entry in slot "$slotId".');
          }
          return SceneAnimation(
            layerId: _requireString(animObj, 'layerId'),
            type: _requireString(animObj, 'type'),
            durationMs: _requireInt(animObj, 'durationMs'),
            curve: _requireString(animObj, 'curve'),
            repeat: _requireString(animObj, 'repeat'),
            from: _requireNum(animObj, 'from').toDouble(),
            to: _requireNum(animObj, 'to').toDouble(),
          );
        })
        .toList(growable: false);
  }

  LocalizedText _parseLocalized(Object? raw, String field) {
    if (raw is! Map<String, Object?>) {
      throw FormatException('Missing or invalid localized object "$field".');
    }
    return LocalizedText(
      it: _requireString(raw, 'it'),
      en: _requireString(raw, 'en'),
    );
  }

  NormalizedRect _parseRect(Object? raw, String field) {
    if (raw is! Map<String, Object?>) {
      throw FormatException('Missing or invalid rect "$field".');
    }
    final double x = _requireNum(raw, 'x').toDouble();
    final double y = _requireNum(raw, 'y').toDouble();
    final double width = _requireNum(raw, 'width').toDouble();
    final double height = _requireNum(raw, 'height').toDouble();
    if (x < 0 || x > 1 || y < 0 || y > 1 || width <= 0 || height <= 0) {
      throw FormatException('Rect "$field" has out-of-range coordinates.');
    }
    return NormalizedRect(x: x, y: y, width: width, height: height);
  }

  String _requireString(Map<String, Object?> map, String key) {
    final Object? val = map[key];
    if (val is! String || val.trim().isEmpty) {
      throw FormatException('Missing or empty string field "$key".');
    }
    return val;
  }

  int _requireInt(Map<String, Object?> map, String key) {
    final Object? val = map[key];
    if (val is! int) {
      throw FormatException('Missing or non-integer field "$key".');
    }
    return val;
  }

  num _requireNum(Map<String, Object?> map, String key) {
    final Object? val = map[key];
    if (val is! num) {
      throw FormatException('Missing or non-numeric field "$key".');
    }
    return val;
  }
}
