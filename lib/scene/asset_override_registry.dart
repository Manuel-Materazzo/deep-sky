import 'package:deep_sky/scene/scene_manifest.dart';

/// Non-destructive asset override table keyed by `slotId:layerId` (SP04-05, TC-08).
/// Leaves the parsed [SceneManifest] immutable so default assets can be restored anytime.
class AssetOverrideRegistry {
  const AssetOverrideRegistry([
    Map<String, String> overrides = const <String, String>{},
  ]) : _overrides = overrides;

  final Map<String, String> _overrides;

  static String keyFor(String slotId, String layerId) => '$slotId:$layerId';

  bool get isEmpty => _overrides.isEmpty;

  int get length => _overrides.length;

  String resolveAsset(String slotId, SceneLayer layer) {
    return _overrides[keyFor(slotId, layer.id)] ?? layer.asset;
  }

  bool hasOverride(String slotId, String layerId) {
    return _overrides.containsKey(keyFor(slotId, layerId));
  }

  AssetOverrideRegistry withOverride({
    required String slotId,
    required String layerId,
    required String overrideAsset,
  }) {
    final Map<String, String> next = Map<String, String>.from(_overrides);
    next[keyFor(slotId, layerId)] = overrideAsset;
    return AssetOverrideRegistry(Map<String, String>.unmodifiable(next));
  }

  AssetOverrideRegistry withoutOverride({
    required String slotId,
    required String layerId,
  }) {
    final Map<String, String> next = Map<String, String>.from(_overrides);
    next.remove(keyFor(slotId, layerId));
    return AssetOverrideRegistry(Map<String, String>.unmodifiable(next));
  }

  AssetOverrideRegistry cleared() => const AssetOverrideRegistry();
}
