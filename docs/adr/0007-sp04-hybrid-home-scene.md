# ADR-0007: Hybrid Home Scene Composition, Animations, and Asset Overrides (`SP-04`)

- **Status:** Accepted
- **Date:** 2026-11-14
- **Reference IDs:** `AR-07`, `AR-08`, `TC-08`, `TC-09`, `A-09`, `V-07..V-10`, `SP-04`

## Context

The main Home view embeds an illustrated, interactive two-partner shared room alongside standard Flutter cards (status summary, countdown, bottom navigation). We needed to verify declarative pack loading (`content/packs/*`), non-destructive asset overrides, level-1 layered animations, accessibility traversal, reduce-motion compliance, and layout stability across diverse screen aspect ratios without semi-transparent card overlays harming legibility or frame rate.

## Decision

The prototype on branch `proto/sp-04` validates the scene engine (`docs/sp-04-hybrid-home.md`):

- **Schema-Validated Manifest & Background Support:** `SceneManifestParser` and `SceneManifest` parse `scene.aspectRatio`, optional `scene.background` (`dayAsset` / `nightAsset`), z-ordered slots, state layers, and level-1 animations (`fade`, `scale`, `translateX`, `translateY`, `rotate`), remaining 100% validated by `scripts/validate_content.py`.
- **Composed Hybrid Home Without Card Overlap (`SP04-03`, `V-07`):** The fixed top `AppBar`, scrollable solid status card, bounded `HybridSceneCanvas`, solid countdown card, and fixed `NavigationBar` sit in non-overlapping vertical regions inside a `SingleChildScrollView`.
- **Level-1 Animation Isolation & Reduce Motion:** Each animated layer is wrapped in `RepaintBoundary` and driven by a single `AnimationController` + cached `CurvedAnimation` that halts immediately when `reduceMotion` or `MediaQuery.disableAnimationsOf(context)` is enabled.
- **Asset Overrides (`SP04-05`):** `AssetOverrideRegistry` resolves `"slotId:layerId"` overrides externally so pack manifests stay immutable and defaults restore cleanly.
- **Pre-Agreed Physical Thresholds:** Target >= 95% frames <= 16.7 ms (60 Hz) during home scrolling + animations and peak RSS <= 180 MB on the oldest/lowest-RAM test phone.

## Alternatives Considered

- **Floating semi-transparent cards over full-screen Rive/Lottie canvas:** Increases GPU overdraw/blur cost and fails legibility/aspect-ratio predictability (`SP-04` explicitly forbids semi-transparent overlap on animated layers).

## Consequences

- **Verified and signed off at M1 exit (`G-1`):** `test/scene/hybrid_scene_test.dart` passed all automated geometry, normalized hit-testing, `AssetOverrideRegistry`, `Semantics` + `OrdinalSortKey`, and reduce-motion tests across `9:16` (`390x693`), `9:20` (`360x800`), and `16:10` (`800x500`); `validate_content.py` (`3` packs) and `flutter build apk --debug` succeeded; promoter verified M1 performance/RSS thresholds, screen-reader traversal, and designer composition approval in `docs/m0-m1-operative-plan.md`.
- **Promotion into M2:** `scene_manifest.dart`, `scene_manifest_parser.dart`, `asset_override_registry.dart`, and `hybrid_scene_canvas.dart` promote cleanly to `development` alongside the DS-2 pilot pack (`docs/m2-operative-plan.md`).
