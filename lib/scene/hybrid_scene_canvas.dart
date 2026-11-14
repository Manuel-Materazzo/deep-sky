import 'dart:math' as math;

import 'package:deep_sky/scene/asset_override_registry.dart';
import 'package:deep_sky/scene/scene_manifest.dart';
import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

/// Renders a layered [SceneManifest] room with level-1 declarative animations,
/// reduce-motion compliance, normalized touch hit-testing, and accessibility semantics (SP-04).
class HybridSceneCanvas extends StatelessWidget {
  const HybridSceneCanvas({
    super.key,
    required this.manifest,
    required this.packAssetRoot,
    this.isNight = false,
    this.reduceMotion = false,
    this.slotStates = const <String, String>{},
    this.overrides = const AssetOverrideRegistry(),
    this.languageCode = 'it',
    this.onSlotTapped,
  });

  final SceneManifest manifest;
  final String packAssetRoot;
  final bool isNight;
  final bool reduceMotion;
  final Map<String, String> slotStates;
  final AssetOverrideRegistry overrides;
  final String languageCode;
  final void Function(SceneSlot slot)? onSlotTapped;

  String _fullAssetPath(String relativeAsset) {
    final String root = packAssetRoot.replaceAll(RegExp(r'/+$'), '');
    final String rel = relativeAsset.replaceAll(RegExp(r'^/+'), '');
    return '$root/$rel';
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations =
        reduceMotion || MediaQuery.disableAnimationsOf(context);

    final List<SceneSlot> sortedSlots = List<SceneSlot>.from(manifest.slots)
      ..sort((SceneSlot a, SceneSlot b) => a.zIndex.compareTo(b.zIndex));

    final SceneBackground? bg = manifest.background;
    final String? bgAsset = bg == null
        ? null
        : _fullAssetPath(isNight ? bg.nightAsset : bg.dayAsset);

    return AspectRatio(
      aspectRatio: manifest.numericAspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double sceneW = constraints.maxWidth;
            final double sceneH = constraints.maxHeight;

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (bgAsset != null)
                  Image.asset(
                    bgAsset,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                  )
                else
                  ColoredBox(
                    color: isNight
                        ? const Color(0xFF1A2238)
                        : const Color(0xFFEFE6D6),
                  ),

                // Visual layers ordered by zIndex -> layer zOffset, isolated with RepaintBoundary.
                for (final SceneSlot slot in sortedSlots)
                  ..._buildSlotVisualLayers(
                    slot: slot,
                    sceneW: sceneW,
                    sceneH: sceneH,
                    disableAnimations: disableAnimations,
                  ),

                // Interactive normalized touch areas sorted for predictable screen-reader traversal.
                for (int i = 0; i < sortedSlots.length; i++)
                  _buildSlotTouchTarget(
                    slot: sortedSlots[i],
                    sortIndex: i + 1,
                    sceneW: sceneW,
                    sceneH: sceneH,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildSlotVisualLayers({
    required SceneSlot slot,
    required double sceneW,
    required double sceneH,
    required bool disableAnimations,
  }) {
    final String stateKey = slotStates[slot.id] ?? slot.defaultState;
    final List<SceneLayer> rawLayers =
        slot.states[stateKey] ??
        slot.states[slot.defaultState] ??
        const <SceneLayer>[];
    final List<SceneLayer> layers = List<SceneLayer>.from(rawLayers)
      ..sort((SceneLayer a, SceneLayer b) => a.zOffset.compareTo(b.zOffset));

    final double left = slot.bounds.x * sceneW;
    final double top = slot.bounds.y * sceneH;
    final double width = slot.bounds.width * sceneW;
    final double height = slot.bounds.height * sceneH;

    return layers
        .map((SceneLayer layer) {
          final String assetPath = _fullAssetPath(
            overrides.resolveAsset(slot.id, layer),
          );
          final List<SceneAnimation> anims = slot.animations
              .where((SceneAnimation a) => a.layerId == layer.id)
              .toList(growable: false);

          Widget child = Opacity(
            opacity: layer.opacity.clamp(0.0, 1.0),
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            ),
          );

          if (anims.isNotEmpty) {
            child = RepaintBoundary(
              child: _Level1LayerAnimator(
                animation: anims.first,
                disableAnimations: disableAnimations,
                child: child,
              ),
            );
          }

          return Positioned(
            left: left,
            top: top,
            width: width,
            height: height,
            child: IgnorePointer(child: child),
          );
        })
        .toList(growable: false);
  }

  Widget _buildSlotTouchTarget({
    required SceneSlot slot,
    required int sortIndex,
    required double sceneW,
    required double sceneH,
  }) {
    final NormalizedRect area = slot.touchArea;
    return Positioned(
      left: area.x * sceneW,
      top: area.y * sceneH,
      width: area.width * sceneW,
      height: area.height * sceneH,
      child: Semantics(
        sortKey: OrdinalSortKey(sortIndex.toDouble()),
        button: onSlotTapped != null,
        label: slot.accessibilityLabel.resolve(languageCode),
        child: GestureDetector(
          key: Key('scene-slot-${slot.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: onSlotTapped == null ? null : () => onSlotTapped!(slot),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _Level1LayerAnimator extends StatefulWidget {
  const _Level1LayerAnimator({
    required this.animation,
    required this.disableAnimations,
    required this.child,
  });

  final SceneAnimation animation;
  final bool disableAnimations;
  final Widget child;

  @override
  State<_Level1LayerAnimator> createState() => _Level1LayerAnimatorState();
}

class _Level1LayerAnimatorState extends State<_Level1LayerAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late CurvedAnimation _curved;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.animation.durationMs),
    );
    _curved = CurvedAnimation(
      parent: _controller,
      curve: _resolveCurve(widget.animation.curve),
    );
    _syncPlayback();
  }

  @override
  void didUpdateWidget(covariant _Level1LayerAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation.durationMs != widget.animation.durationMs) {
      _controller.duration = Duration(
        milliseconds: widget.animation.durationMs,
      );
    }
    if (oldWidget.animation.curve != widget.animation.curve) {
      _curved.dispose();
      _curved = CurvedAnimation(
        parent: _controller,
        curve: _resolveCurve(widget.animation.curve),
      );
    }
    if (oldWidget.disableAnimations != widget.disableAnimations ||
        oldWidget.animation.repeat != widget.animation.repeat) {
      _syncPlayback();
    }
  }

  void _syncPlayback() {
    if (widget.disableAnimations || widget.animation.repeat == 'none') {
      _controller.stop();
      _controller.value = 0.0;
      return;
    }
    if (widget.animation.repeat == 'reverse') {
      _controller.repeat(reverse: true);
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  Curve _resolveCurve(String name) {
    switch (name) {
      case 'easeIn':
        return Curves.easeIn;
      case 'easeOut':
        return Curves.easeOut;
      case 'easeInOut':
        return Curves.easeInOut;
      default:
        return Curves.linear;
    }
  }

  @override
  Widget build(BuildContext context) {
    final SceneAnimation anim = widget.animation;

    return AnimatedBuilder(
      animation: _curved,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double v = widget.disableAnimations
            ? anim.from
            : anim.from + (anim.to - anim.from) * _curved.value;
        switch (anim.type) {
          case 'fade':
            return Opacity(opacity: v.clamp(0.0, 1.0), child: child);
          case 'scale':
            return Transform.scale(scale: v, child: child);
          case 'translateY':
            return Transform.translate(offset: Offset(0, v), child: child);
          case 'translateX':
            return Transform.translate(offset: Offset(v, 0), child: child);
          case 'rotate':
            return Transform.rotate(angle: v * math.pi / 180.0, child: child);
          default:
            return child ?? const SizedBox.shrink();
        }
      },
    );
  }
}
