/// Data models representing a Deep Sky scene content pack manifest (TC-08, CNT-01).
class LocalizedText {
  const LocalizedText({required this.it, required this.en});

  final String it;
  final String en;

  String resolve(String languageCode) => languageCode == 'it' ? it : en;
}

/// Normalized rectangle in scene coordinates `[0.0, 1.0]`.
class NormalizedRect {
  const NormalizedRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Level-1 declarative slot layer animation descriptor (TC-09).
class SceneAnimation {
  const SceneAnimation({
    required this.layerId,
    required this.type,
    required this.durationMs,
    required this.curve,
    required this.repeat,
    required this.from,
    required this.to,
  });

  final String layerId;
  final String type;
  final int durationMs;
  final String curve;
  final String repeat;
  final double from;
  final double to;
}

/// Single visual layer within a slot state.
class SceneLayer {
  const SceneLayer({
    required this.id,
    required this.asset,
    required this.zOffset,
    this.opacity = 1.0,
  });

  final String id;
  final String asset;
  final int zOffset;
  final double opacity;
}

/// Interactive or decorative slot in the shared home scene (A-09).
class SceneSlot {
  const SceneSlot({
    required this.id,
    required this.description,
    required this.zIndex,
    required this.replaceable,
    required this.bounds,
    required this.touchArea,
    required this.accessibilityLabel,
    required this.defaultState,
    required this.states,
    required this.animations,
  });

  final String id;
  final String description;
  final int zIndex;
  final bool replaceable;
  final NormalizedRect bounds;
  final NormalizedRect touchArea;
  final LocalizedText accessibilityLabel;
  final String defaultState;
  final Map<String, List<SceneLayer>> states;
  final List<SceneAnimation> animations;
}

/// Day and night room background assets declared in `scene.background` (SP-04).
class SceneBackground {
  const SceneBackground({required this.dayAsset, required this.nightAsset});

  final String dayAsset;
  final String nightAsset;
}

/// Root manifest for a Deep Sky scene content pack.
class SceneManifest {
  const SceneManifest({
    required this.schemaVersion,
    required this.packId,
    required this.packVersion,
    required this.minAppProtocol,
    required this.name,
    required this.aspectRatio,
    required this.slots,
    this.background,
  });

  final int schemaVersion;
  final String packId;
  final String packVersion;
  final int minAppProtocol;
  final LocalizedText name;
  final String aspectRatio;
  final List<SceneSlot> slots;
  final SceneBackground? background;

  double get numericAspectRatio {
    final List<String> parts = aspectRatio.split(':');
    if (parts.length != 2) {
      return 9 / 16;
    }
    final double? w = double.tryParse(parts[0]);
    final double? h = double.tryParse(parts[1]);
    if (w == null || h == null || w <= 0 || h <= 0) {
      return 9 / 16;
    }
    return w / h;
  }
}
