import 'package:deep_sky/data/scene_manifest_parser.dart';
import 'package:deep_sky/scene/asset_override_registry.dart';
import 'package:deep_sky/scene/hybrid_scene_canvas.dart';
import 'package:deep_sky/scene/scene_manifest.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Hybrid Home screen prototype (SP-04, AR-07, AR-08, V-07..V-10).
///
/// Layout structure:
/// - Fixed top AppBar (pack info & quick toggles)
/// - Scrollable feed: opaque Status Card -> non-overlapped Scene Canvas -> opaque Countdown Card -> Prototype Controls
/// - Fixed bottom NavigationBar (Home, Timeline, Capsule, Spazio)
class Sp04HybridHomePage extends StatefulWidget {
  const Sp04HybridHomePage({
    super.key,
    this.initialManifest,
    this.packAssetRoot = 'content/packs/sp04_room',
    this.manifestAssetPath = 'content/packs/sp04_room/manifest.json',
    this.initialReduceMotion = false,
  });

  final SceneManifest? initialManifest;
  final String packAssetRoot;
  final String manifestAssetPath;
  final bool initialReduceMotion;

  @override
  State<Sp04HybridHomePage> createState() => _Sp04HybridHomePageState();
}

class _Sp04HybridHomePageState extends State<Sp04HybridHomePage> {
  static const SceneManifestParser _parser = SceneManifestParser();

  SceneManifest? _manifest;
  String? _loadError;
  bool _isNight = false;
  late bool _reduceMotion = widget.initialReduceMotion;
  bool _windowLit = true;
  AssetOverrideRegistry _overrides = const AssetOverrideRegistry();
  int _navIndex = 0;
  String _lastSlotEvent = 'Nessuno slot toccato';

  int _totalFrames = 0;
  int _framesWithinBudget = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialManifest != null) {
      _manifest = widget.initialManifest;
    } else {
      _loadBundledManifest();
    }
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    super.dispose();
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!mounted || timings.isEmpty) {
      return;
    }
    const int budgetMicros = 16700;
    int totalDelta = 0;
    int okDelta = 0;
    for (final FrameTiming timing in timings) {
      totalDelta++;
      if (timing.totalSpan.inMicroseconds <= budgetMicros) {
        okDelta++;
      }
    }
    setState(() {
      _totalFrames += totalDelta;
      _framesWithinBudget += okDelta;
    });
  }

  Future<void> _loadBundledManifest() async {
    try {
      final String raw = await rootBundle.loadString(widget.manifestAssetPath);
      final SceneManifest parsed = _parser.parseJson(raw);
      if (!mounted) {
        return;
      }
      setState(() {
        _manifest = parsed;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error.toString();
      });
    }
  }

  void _handleSlotTap(SceneSlot slot) {
    setState(() {
      _lastSlotEvent = 'Slot "${slot.id}" (${slot.accessibilityLabel.it})';
      if (slot.id == 'window') {
        _windowLit = !_windowLit;
      } else if (slot.id == 'pet') {
        _togglePetOverride();
      }
    });
  }

  void _togglePetOverride() {
    const String slotId = 'pet';
    const String layerId = 'pet_body';
    if (_overrides.hasOverride(slotId, layerId)) {
      _overrides = _overrides.withoutOverride(slotId: slotId, layerId: layerId);
    } else {
      _overrides = _overrides.withOverride(
        slotId: slotId,
        layerId: layerId,
        overrideAsset: 'assets/pet_fox_override.png',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final SceneManifest? manifest = _manifest;
    final double budgetPct = _totalFrames == 0
        ? 100.0
        : (_framesWithinBudget / _totalFrames) * 100.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deep Sky · Home'),
        actions: <Widget>[
          IconButton(
            key: const Key('sp04-toggle-night'),
            tooltip: _isNight ? 'Passa al giorno' : 'Passa alla notte',
            icon: Icon(_isNight ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _isNight = !_isNight),
          ),
          IconButton(
            key: const Key('sp04-toggle-reduce-motion'),
            tooltip: 'Riduci movimento',
            icon: Icon(
              _reduceMotion
                  ? Icons.motion_photos_off
                  : Icons.motion_photos_auto,
            ),
            onPressed: () => setState(() => _reduceMotion = !_reduceMotion),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        key: const Key('sp04-bottom-nav'),
        selectedIndex: _navIndex,
        onDestinationSelected: (int index) => setState(() => _navIndex = index),
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            label: 'Timeline',
          ),
          NavigationDestination(
            icon: Icon(Icons.hourglass_bottom_outlined),
            label: 'Capsule',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            label: 'Spazio',
          ),
        ],
      ),
      body: SafeArea(
        child: manifest == null
            ? Center(
                child: _loadError != null
                    ? Text('Errore manifest: $_loadError')
                    : const CircularProgressIndicator(),
              )
            : LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  // Bound scene width gracefully across narrow 9:20 phones and wide 16:10 tablets
                  // so touch targets stay reachable and vertical scroll remains comfortable.
                  final double maxSceneWidth = constraints.maxWidth > 520
                      ? 360
                      : constraints.maxWidth - 32;

                  return SingleChildScrollView(
                    key: const Key('sp04-home-scroll'),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Card(
                          key: const Key('sp04-status-card'),
                          elevation: 1,
                          child: ListTile(
                            leading: const Icon(Icons.wb_twilight),
                            title: const Text('Stato condiviso'),
                            subtitle: Text(
                              _isNight
                                  ? 'Sera tranquilla · finestra ${_windowLit ? "accesa" : "spenta"}'
                                  : 'Pomeriggio insieme · ${_overrides.isEmpty ? "gatto predefinito" : "volpe (override)"}',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: SizedBox(
                            width: maxSceneWidth,
                            child: HybridSceneCanvas(
                              key: const Key('sp04-scene-canvas'),
                              manifest: manifest,
                              packAssetRoot: widget.packAssetRoot,
                              isNight: _isNight,
                              reduceMotion: _reduceMotion,
                              slotStates: <String, String>{
                                'window': _windowLit ? 'lit' : 'calm',
                              },
                              overrides: _overrides,
                              onSlotTapped: _handleSlotTap,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Card(
                          key: Key('sp04-countdown-card'),
                          elevation: 1,
                          child: ListTile(
                            leading: Icon(Icons.calendar_today_outlined),
                            title: Text('Prossimo incontro'),
                            subtitle: Text('Fra 12 giorni · Roma'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          key: const Key('sp04-controls-card'),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Controlli SP-04 (${manifest.packId} v${manifest.packVersion})',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 6),
                                Text('Ultimo evento: $_lastSlotEvent'),
                                Text(
                                  'Frame <= 16.7ms: ${budgetPct.toStringAsFixed(1)}% ($_framesWithinBudget/$_totalFrames)',
                                ),
                                Text('Riduci movimento: $_reduceMotion'),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    FilledButton.tonal(
                                      key: const Key('sp04-override-pet-btn'),
                                      onPressed: () =>
                                          setState(_togglePetOverride),
                                      child: Text(
                                        _overrides.hasOverride(
                                              'pet',
                                              'pet_body',
                                            )
                                            ? 'Ripristina Pet Predefinito'
                                            : 'Override Pet -> Volpe',
                                      ),
                                    ),
                                    OutlinedButton(
                                      key: const Key('sp04-reset-all-btn'),
                                      onPressed: () => setState(() {
                                        _overrides = _overrides.cleared();
                                        _windowLit = true;
                                        _isNight = false;
                                        _reduceMotion = false;
                                      }),
                                      child: const Text('Reset scena'),
                                    ),
                                  ],
                                ),
                              ],
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
  }
}
