import 'dart:io';
import 'dart:math' as math;

import 'package:deep_sky/presentation/theme/deep_sky_theme.dart';
import 'package:deep_sky/scene/asset_override_registry.dart';
import 'package:deep_sky/scene/scene_manifest.dart';
import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

/// Renders a layered [SceneManifest] room with level-1 declarative animations,
/// reduce-motion compliance, normalized touch hit-testing, accessibility semantics,
/// bounded image decoding, and explicit sky-variant cache eviction (`SP-04`, `ADR-0007`, `S2-APP-03`).
///
/// Supports both APK-bundled assets (`isFileSystem: false`) and verified file-system
/// content packs (`isFileSystem: true`). When `manifest.background == null`, transparent
/// PNG slots render directly over the dynamic wall-backdrop of the Home screen without
/// opaque borders or vignette boxes (`S2-D02`).
class HybridSceneCanvas extends StatefulWidget {
  const HybridSceneCanvas({
    super.key,
    required this.manifest,
    required this.packAssetRoot,
    this.isFileSystem = false,
    this.isNight = false,
    this.reduceMotion = false,
    this.slotStates = const <String, String>{},
    this.overrides = const AssetOverrideRegistry(),
    this.languageCode = 'it',
    this.onSlotTapped,
    this.expandFloorDownward = false,
    this.extraFloorHeight = 0.0,
    this.floorBaseColor,
  });

  final SceneManifest manifest;
  final String packAssetRoot;
  final bool isFileSystem;
  final bool isNight;
  final bool reduceMotion;
  final Map<String, String> slotStates;
  final AssetOverrideRegistry overrides;
  final String languageCode;
  final void Function(SceneSlot slot)? onSlotTapped;

  /// When true (`S3-2` Home), extends the `floor` slot seamlessly downward below
  /// the logical scene bounds so the floor continues to the bottom of the screen.
  final bool expandFloorDownward;
  final double extraFloorHeight;
  final Color? floorBaseColor;

  static ImageProvider _buildProvider({
    required String packAssetRoot,
    required String relativeAsset,
    required bool isFileSystem,
  }) {
    final String cleanRel = relativeAsset.replaceAll(RegExp(r'^/+'), '');
    if (isFileSystem) {
      final String fullPath = <String>[
        packAssetRoot.replaceAll(RegExp(r'[/\\]+$'), ''),
        ...cleanRel.split('/'),
      ].join(Platform.pathSeparator);
      return FileImage(File(fullPath));
    }
    final String root = packAssetRoot.replaceAll(RegExp(r'/+$'), '');
    return AssetImage('$root/$cleanRel');
  }

  @override
  State<HybridSceneCanvas> createState() => _HybridSceneCanvasState();
}

class _HybridSceneCanvasState extends State<HybridSceneCanvas> {
  final Map<String, ImageProvider> _activeSkyProviders =
      <String, ImageProvider>{};

  @override
  void didUpdateWidget(covariant HybridSceneCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String? oldWindowState = oldWidget.slotStates['window'];
    final String? newWindowState = widget.slotStates['window'];
    final bool packChanged =
        oldWidget.packAssetRoot != widget.packAssetRoot ||
        oldWidget.isFileSystem != widget.isFileSystem ||
        oldWidget.manifest.packVersion != widget.manifest.packVersion;

    // ADR-0007: evict outgoing window sky variant immediately so only one sky
    // variant stays decoded in RAM at a time.
    if (packChanged || oldWindowState != newWindowState) {
      for (final ImageProvider provider in _activeSkyProviders.values) {
        provider.evict();
      }
      _activeSkyProviders.clear();
    }
  }

  ImageProvider _resolveLayerProvider({
    required SceneSlot slot,
    required SceneLayer layer,
    required int? cacheWidth,
    required int? cacheHeight,
  }) {
    final String resolvedAsset = widget.overrides.resolveAsset(slot.id, layer);
    final ImageProvider base = HybridSceneCanvas._buildProvider(
      packAssetRoot: widget.packAssetRoot,
      relativeAsset: resolvedAsset,
      isFileSystem: widget.isFileSystem,
    );
    // Always preserve intrinsic PNG aspect ratio when downscaling to slot bounds
    // (`policy: ResizeImagePolicy.fit`): default `exact` would squash portrait
    // assets like the 3:4 window into a square on smaller screens/lower DPRs.
    final ImageProvider sized = (cacheWidth != null || cacheHeight != null)
        ? ResizeImage(
            base,
            width: cacheWidth,
            height: cacheHeight,
            policy: ResizeImagePolicy.fit,
          )
        : base;
    if (slot.id == 'window' && layer.id.startsWith('sky')) {
      _activeSkyProviders['${slot.id}:${layer.id}'] = sized;
    }
    return sized;
  }

  String _resolveSlotStateKey(SceneSlot slot) {
    final String? requested = widget.slotStates[slot.id];
    if (requested != null && slot.states.containsKey(requested)) {
      return requested;
    }
    // Legacy compatibility: if a pilot pack's window only defines calm/lit
    // and floor_lamp is lit, light the legacy window.
    if (slot.id == 'window' &&
        widget.slotStates['floor_lamp'] == 'lit' &&
        slot.states.containsKey('lit')) {
      return 'lit';
    }
    return slot.defaultState;
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations =
        widget.reduceMotion || MediaQuery.disableAnimationsOf(context);
    final double dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);

    final List<SceneSlot> sortedSlots = List<SceneSlot>.from(
      widget.manifest.slots,
    )..sort((SceneSlot a, SceneSlot b) => a.zIndex.compareTo(b.zIndex));

    final SceneBackground? bg = widget.manifest.background;
    final bool hasOpaqueBackground = bg != null;
    final ImageProvider? bgProvider = bg == null
        ? null
        : HybridSceneCanvas._buildProvider(
            packAssetRoot: widget.packAssetRoot,
            relativeAsset: widget.isNight ? bg.nightAsset : bg.dayAsset,
            isFileSystem: widget.isFileSystem,
          );

    final double extraFloor = widget.expandFloorDownward
        ? math.max(0.0, widget.extraFloorHeight)
        : 0.0;

    Widget canvas = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double sceneW = constraints.maxWidth;
        final double sceneH = sceneW / widget.manifest.numericAspectRatio;
        final double totalH = sceneH + extraFloor;

        return SizedBox(
          width: sceneW,
          height: totalH,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              if (bgProvider != null)
                Positioned(
                  left: 0,
                  top: 0,
                  width: sceneW,
                  height: sceneH,
                  child: Image(
                    image: ResizeImage.resizeIfNeeded(
                      (sceneW * dpr).round().clamp(64, 1600),
                      null,
                      bgProvider,
                    ),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                  ),
                ),

              // Continuous warm parquet continuation beneath floor.png on tall displays (`S2-D02`)
              if (widget.expandFloorDownward)
                for (final SceneSlot slot in sortedSlots)
                  if (slot.id == 'floor')
                    Positioned(
                      left: 0,
                      right: 0,
                      top: (slot.bounds.y + 0.14) * sceneH,
                      bottom: 0,
                      child: ColoredBox(
                        color: widget.floorBaseColor ?? tokens.floorParquetBase,
                      ),
                    ),

              // Visual layers ordered by zIndex -> layer zOffset, isolated with RepaintBoundary.
              for (final SceneSlot slot in sortedSlots)
                ..._buildSlotVisualLayers(
                  slot: slot,
                  sceneW: sceneW,
                  sceneH: sceneH,
                  totalH: totalH,
                  dpr: dpr,
                  tokens: tokens,
                  disableAnimations: disableAnimations,
                ),

              // Interactive normalized touch areas sorted for predictable TalkBack traversal.
              for (int i = 0; i < sortedSlots.length; i++)
                if (sortedSlots[i].id != 'floor')
                  _buildSlotTouchTarget(
                    slot: sortedSlots[i],
                    sortIndex: i + 1,
                    sceneW: sceneW,
                    sceneH: sceneH,
                  ),
            ],
          ),
        );
      },
    );

    if (hasOpaqueBackground) {
      canvas = AspectRatio(
        aspectRatio: widget.manifest.numericAspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: canvas,
        ),
      );
    }

    return canvas;
  }

  List<Widget> _buildSlotVisualLayers({
    required SceneSlot slot,
    required double sceneW,
    required double sceneH,
    required double totalH,
    required double dpr,
    required DeepSkyTokens tokens,
    required bool disableAnimations,
  }) {
    final String stateKey = _resolveSlotStateKey(slot);
    final List<SceneLayer> rawLayers =
        slot.states[stateKey] ??
        slot.states[slot.defaultState] ??
        const <SceneLayer>[];
    final List<SceneLayer> layers = List<SceneLayer>.from(rawLayers)
      ..sort((SceneLayer a, SceneLayer b) => a.zOffset.compareTo(b.zOffset));

    final bool isContinuousFloor =
        slot.id == 'floor' && widget.expandFloorDownward;
    final double left = isContinuousFloor ? 0 : slot.bounds.x * sceneW;
    final double top = slot.bounds.y * sceneH;
    final double width = isContinuousFloor
        ? sceneW
        : slot.bounds.width * sceneW;
    final double height = isContinuousFloor
        ? math.max(slot.bounds.height * sceneH, totalH - top)
        : slot.bounds.height * sceneH;

    final int decodeW = (width * dpr).round().clamp(32, 1600);
    final int? decodeH = isContinuousFloor
        ? null
        : (height * dpr).round().clamp(32, 1600);

    final List<Widget> widgets = <Widget>[];

    // DD-10 §6.3 hybrid lamp lighting: soft ambient radial amber/rose bloom behind
    // floor_lamp_lit.png directly on the wall-backdrop without extra texture RAM.
    if (slot.id == 'floor_lamp' && stateKey == 'lit') {
      final double glowRadius = math.max(width, height) * 0.9;
      widgets.add(
        Positioned(
          left: left + (width - glowRadius) / 2,
          top: top - glowRadius * 0.12,
          width: glowRadius,
          height: glowRadius,
          child: IgnorePointer(
            child: DecoratedBox(
              key: const Key('floor-lamp-ambient-glow'),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    tokens.amberGlow.withValues(alpha: 0.34),
                    tokens.calmAccent.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                  stops: const <double>[0.0, 0.48, 1.0],
                ),
              ),
            ),
          ),
        ),
      );
    }

    for (final SceneLayer layer in layers) {
      final ImageProvider provider = _resolveLayerProvider(
        slot: slot,
        layer: layer,
        cacheWidth: decodeW,
        cacheHeight: decodeH,
      );
      final List<SceneAnimation> anims = slot.animations
          .where((SceneAnimation a) => a.layerId == layer.id)
          .toList(growable: false);

      Widget child = Opacity(
        opacity: layer.opacity.clamp(0.0, 1.0),
        child: Image(
          image: provider,
          fit: isContinuousFloor ? BoxFit.cover : BoxFit.contain,
          alignment: isContinuousFloor ? Alignment.topCenter : Alignment.center,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          filterQuality: FilterQuality.medium,
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

      widgets.add(
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: IgnorePointer(child: child),
        ),
      );
    }

    return widgets;
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
        button: widget.onSlotTapped != null,
        label: slot.accessibilityLabel.resolve(widget.languageCode),
        child: GestureDetector(
          key: Key('scene-slot-${slot.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onSlotTapped == null
              ? null
              : () => widget.onSlotTapped!(slot),
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
