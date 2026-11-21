import 'dart:async';
import 'dart:math' as math;

import 'package:deep_sky/data/couple_api_client.dart';
import 'package:deep_sky/data/encrypted_local_cache.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';
import 'package:deep_sky/presentation/deep_sky_controller.dart';
import 'package:deep_sky/presentation/l10n/deep_sky_strings.dart';
import 'package:deep_sky/presentation/screens/settings_page.dart';
import 'package:deep_sky/presentation/theme/deep_sky_theme.dart';
import 'package:deep_sky/presentation/widgets/invite_verification_section.dart';
import 'package:deep_sky/scene/hybrid_scene_canvas.dart';
import 'package:deep_sky/scene/scene_manifest.dart';
import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

/// Authenticated couple space shell (`S3-2`, `F-02`, `F-03`, `DD-04`, `P-07`, `S-05`).
///
/// Header displays only the room title on the left and a single Settings action on the right
/// (zero online presence indicators). Bottom navigation exposes only `Casa` and `Noi` in `S3-2`.
class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key, required this.controller});

  final DeepSkyController controller;

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();
  final TextEditingController _replyNoteController = TextEditingController();
  final FocusNode _replyNoteFocusNode = FocusNode();
  final ScrollController _panController = ScrollController();

  Timer? _skyRefreshTimer;
  Timer? _thoughtSentBannerTimer;
  int _handledThoughtSentSequence = 0;
  int _navIndex = 0;
  bool _panCentered = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncThoughtSentTimer);
    _syncThoughtSentTimer();
    if (widget.controller.enableSkyRefreshTimer) {
      _skyRefreshTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => widget.controller.refreshLocalSkyPeriod(),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.controller.markHomeBootSucceeded();
      _centerPanoramicSceneIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant HomeShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncThoughtSentTimer);
      widget.controller.addListener(_syncThoughtSentTimer);
      _handledThoughtSentSequence = 0;
      _syncThoughtSentTimer();
    }
  }

  void _syncThoughtSentTimer() {
    final DeepSkyController c = widget.controller;
    if (!c.showThoughtSentBanner) {
      _thoughtSentBannerTimer?.cancel();
      _thoughtSentBannerTimer = null;
      return;
    }
    if (c.thoughtSentBannerSequence != _handledThoughtSentSequence) {
      _handledThoughtSentSequence = c.thoughtSentBannerSequence;
      _thoughtSentBannerTimer?.cancel();
      final Duration duration = c.thoughtSentBannerDuration;
      if (duration > Duration.zero) {
        _thoughtSentBannerTimer = Timer(duration, () {
          if (!mounted) {
            return;
          }
          widget.controller.dismissThoughtSentBanner();
        });
      }
    }
  }

  void _centerPanoramicSceneIfNeeded() {
    if (_panCentered || !_panController.hasClients) {
      return;
    }
    final double maxExtent = _panController.position.maxScrollExtent;
    if (maxExtent > 0) {
      _panController.jumpTo(maxExtent / 2);
      _panCentered = true;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncThoughtSentTimer);
    _skyRefreshTimer?.cancel();
    _thoughtSentBannerTimer?.cancel();
    _noteController.dispose();
    _noteFocusNode.dispose();
    _replyNoteController.dispose();
    _replyNoteFocusNode.dispose();
    _panController.dispose();
    super.dispose();
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DeepSkyController c = widget.controller;
    final DeepSkyStrings s = DeepSkyStrings(c.languageCode);
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    final bool isHomeTab = _navIndex == 0;
    final Color headerBg = isHomeTab
        ? tokens.wallHeaderColorFor(c.sceneState.skyPeriod)
        : tokens.skyBackdrop;

    return Scaffold(
      key: const Key('home-shell-page'),
      backgroundColor: isHomeTab
          ? tokens.wallHeaderColorFor(c.sceneState.skyPeriod)
          : tokens.skyBackdrop,
      appBar: AppBar(
        backgroundColor: headerBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primaryContainer
                    .withValues(alpha: 0.18),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primaryContainer
                      .withValues(alpha: 0.35),
                ),
              ),
              child: Icon(
                isHomeTab ? Icons.home_rounded : Icons.favorite_rounded,
                size: 18,
                color: tokens.blushPetal,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                isHomeTab ? s.homeTab : s.usTab,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              key: const Key('open-settings-button'),
              tooltip: s.settingsButtonTooltip,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () => _openSettings(context),
              icon: const Icon(Icons.settings_outlined),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (c.isDeviceRevoked) _buildRevokedBanner(context, c, s, tokens),
          if (c.isOffline && !c.isDeviceRevoked)
            _buildOfflineBanner(context, s, tokens),
          Expanded(
            child: IndexedStack(
              index: _navIndex,
              children: <Widget>[
                _buildHomeTab(context, c, s, tokens),
                _buildUsTab(context, c, s, tokens),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        key: const Key('ds2-bottom-nav'),
        selectedIndex: _navIndex,
        onDestinationSelected: (int index) => setState(() => _navIndex = index),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.cottage_outlined),
            selectedIcon: const Icon(Icons.cottage),
            label: s.homeTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_outline),
            selectedIcon: const Icon(Icons.favorite),
            label: s.usTab,
          ),
        ],
      ),
    );
  }

  Widget _buildRevokedBanner(
    BuildContext context,
    DeepSkyController c,
    DeepSkyStrings s,
    DeepSkyTokens tokens,
  ) {
    return Material(
      key: const Key('revoked-device-banner'),
      color: tokens.offlineBannerSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.link_off,
                    size: 18,
                    color: tokens.offlineBannerInk,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.revokedDeviceBanner,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: tokens.offlineBannerInk),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                key: const Key('reset-revoked-device-button'),
                onPressed: c.busy ? null : c.unlinkCurrentDevice,
                child: Text(s.clearLocalSpaceButton),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(
    BuildContext context,
    DeepSkyStrings s,
    DeepSkyTokens tokens,
  ) {
    return Material(
      key: const Key('offline-readonly-banner'),
      color: tokens.offlineBannerSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.cloud_off_outlined,
              size: 18,
              color: tokens.offlineBannerInk,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                s.offlineReadOnlyBanner,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: tokens.offlineBannerInk),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(
    BuildContext context,
    DeepSkyController c,
    DeepSkyStrings s,
    DeepSkyTokens tokens,
  ) {
    final LocalDeviceIdentity id = c.identity!;
    final bool canWrite =
        !c.busy &&
        !c.isOffline &&
        !c.isDeviceRevoked &&
        id.recoverySavedConfirmed;

    final SceneManifest? manifest = c.sceneManifest;
    final bool isWalllessHome = manifest != null && manifest.background == null;

    return DecoratedBox(
      key: const Key('home-wall-backdrop'),
      decoration: BoxDecoration(
        gradient: tokens.wallGradientFor(c.sceneState.skyPeriod),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints viewport) {
          final double viewportW = viewport.maxWidth;
          final double viewportH = viewport.maxHeight;
          // Panoramic 4:3 framing: slightly wider than compact portrait phones for gentle horizontal pan.
          final double sceneWidth = isWalllessHome
              ? math.max(viewportW, math.min(viewportW * 1.18, 480.0))
              : math.max(0.0, viewportW - 32);
          final double baseSceneH = manifest == null
              ? 0.0
              : sceneWidth / manifest.numericAspectRatio;
          // Ensure the continuous parquet floor fills the rest of the viewport cleanly.
          final double extraFloorH = isWalllessHome
              ? math.max(96.0, viewportH - baseSceneH - 132.0)
              : 0.0;

          return RefreshIndicator(
            onRefresh: c.refreshSync,
            child: SingleChildScrollView(
              key: const Key('home-feed-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewportH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          if (c.shouldShowPushOptInPrompt)
                            _buildPushOptInCard(context, c, s, tokens),
                          if (c.showWelcomeBackBanner)
                            _buildWelcomeBackCard(context, c, s, tokens),
                          Semantics(
                            sortKey: const OrdinalSortKey(0),
                            child: _buildDualStateThoughtCard(
                              context: context,
                              c: c,
                              s: s,
                              tokens: tokens,
                              canWrite: canWrite,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (manifest != null)
                      if (isWalllessHome)
                        SingleChildScrollView(
                          key: const Key('home-scene-pan-scroll'),
                          controller: _panController,
                          scrollDirection: Axis.horizontal,
                          physics: sceneWidth > viewportW
                              ? const BouncingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          child: SizedBox(
                            width: sceneWidth,
                            child: HybridSceneCanvas(
                              key: const Key('ds2-scene-canvas'),
                              manifest: manifest,
                              packAssetRoot: c.activePackAssetRoot,
                              isFileSystem: c.activePackIsFileSystem,
                              isNight: c.isNight,
                              reduceMotion: c.reduceMotion,
                              slotStates: c.sceneState.slotStates,
                              overrides: c.assetOverrides,
                              languageCode: c.languageCode,
                              expandFloorDownward: true,
                              extraFloorHeight: extraFloorH,
                              floorBaseColor: tokens.floorParquetBase,
                              onSlotTapped: (SceneSlot slot) =>
                                  _handleSceneSlotTap(slot, c, canWrite),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: HybridSceneCanvas(
                            key: const Key('ds2-scene-canvas'),
                            manifest: manifest,
                            packAssetRoot: c.activePackAssetRoot,
                            isFileSystem: c.activePackIsFileSystem,
                            isNight: c.isNight,
                            reduceMotion: c.reduceMotion,
                            slotStates: c.sceneState.slotStates,
                            overrides: c.assetOverrides,
                            languageCode: c.languageCode,
                            onSlotTapped: (SceneSlot slot) =>
                                _handleSceneSlotTap(slot, c, canWrite),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleSceneSlotTap(SceneSlot slot, DeepSkyController c, bool canWrite) {
    if (slot.id == 'floor_lamp') {
      if (c.sceneState.hasUnseenRecentPartnerThought && canWrite) {
        _submitReplyThought(c);
      } else if (canWrite) {
        if (c.showThoughtSentBanner) {
          c.dismissThoughtSentBanner();
        }
        _noteFocusNode.requestFocus();
      }
      return;
    }
    if (slot.id == 'pet') {
      c.togglePetOverride();
    }
  }

  Widget _buildWelcomeBackCard(
    BuildContext context,
    DeepSkyController c,
    DeepSkyStrings s,
    DeepSkyTokens tokens,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        key: const Key('welcome-back-card'),
        color: tokens.cardSurface.withValues(alpha: 0.92),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: <Widget>[
              Icon(Icons.wb_twilight_rounded, color: tokens.warmGlow, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      s.welcomeBackTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.welcomeBackSubtitle,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: tokens.mutedInk),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('dismiss-welcome-back-button'),
                tooltip: s.dismissWelcomeBackTooltip,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: c.dismissWelcomeBackBanner,
                icon: Icon(Icons.close_rounded, color: tokens.mutedInk),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Adaptive top "Ti penso" card (`F-03`, `DD-04`, `S2-D05`, `S2-APP-03`):
  /// - State A: unseen partner thought `< 6h` -> `"<Partner> ti ha pensato"` + optional reply note + `♥ Ricambia`.
  /// - State B: brief confirmation banner (`"Pensiero inviato"`) replacing the composer after sending.
  /// - State C: calm default -> quick-send `"Ti penso"` with optional short note.
  Widget _buildDualStateThoughtCard({
    required BuildContext context,
    required DeepSkyController c,
    required DeepSkyStrings s,
    required DeepSkyTokens tokens,
    required bool canWrite,
  }) {
    final CachedEventEntry? unseenThought = c.sceneState.unseenPartnerThought;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool compactStacked =
        MediaQuery.textScalerOf(context).scale(14) > 18 ||
        MediaQuery.sizeOf(context).width < 340;
    final String partnerName = c.partnerDisplayLabel ?? s.partnerFallbackName;

    final Widget activeCard;
    if (unseenThought != null) {
      final Object? rawNote = unseenThought.payload.body['note'];
      final String? note = rawNote is String && rawNote.trim().isNotEmpty
          ? rawNote.trim()
          : null;
      final Duration elapsed = DateTime.now().toUtc().difference(
        unseenThought.payload.createdAtClient.toUtc(),
      );
      final Duration safeElapsed = elapsed.isNegative ? Duration.zero : elapsed;

      activeCard = KeyedSubtree(
        key: const ValueKey<String>('thought-card-received'),
        child: Container(
          key: const Key('ds2-status-card'),
          decoration: BoxDecoration(
            color: tokens.cardSurface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(DeepSkyTheme.radiusXl),
            border: Border.all(
              color: scheme.primaryContainer.withValues(alpha: 0.32),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        DeepSkyTheme.radiusLg,
                      ),
                      color: scheme.primaryContainer.withValues(alpha: 0.2),
                      border: Border.all(
                        color: scheme.primaryContainer.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      Icons.volunteer_activism_rounded,
                      color: tokens.blushPetal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          s.partnerThoughtOfYouTitle(partnerName),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.thoughtRelativeCaption(safeElapsed),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.mutedInk),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (note != null) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.surfaceHigh.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(DeepSkyTheme.radiusMd),
                  ),
                  child: Text(
                    '“$note”',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _buildThoughtComposer(
                compactStacked: compactStacked,
                fieldKey: const Key('reply-thought-note-field'),
                buttonKey: const Key('reply-thought-button'),
                controller: _replyNoteController,
                focusNode: _replyNoteFocusNode,
                hintText: s.replyThoughtNoteHint,
                buttonLabel: s.replyThoughtButton,
                canWrite: canWrite,
                onSubmit: () => _submitReplyThought(c),
              ),
              if (c.errorNotice != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(c.errorNotice!, style: TextStyle(color: scheme.error)),
              ],
            ],
          ),
        ),
      );
    } else if (c.showThoughtSentBanner) {
      final String? sentNote = c.lastSentThoughtNote;
      activeCard = KeyedSubtree(
        key: const ValueKey<String>('thought-card-sent'),
        child: Container(
          key: const Key('ds2-status-card'),
          decoration: BoxDecoration(
            color: tokens.cardSurface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(DeepSkyTheme.radiusXl),
            border: Border.all(color: tokens.warmGlow.withValues(alpha: 0.42)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Column(
            key: const Key('thought-sent-banner'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        DeepSkyTheme.radiusLg,
                      ),
                      color: tokens.warmGlow.withValues(alpha: 0.16),
                      border: Border.all(
                        color: tokens.warmGlow.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: tokens.warmGlow,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          s.thoughtSentBannerTitle,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.thoughtSentBannerSubtitle(partnerName),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.mutedInk),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('dismiss-thought-sent-button'),
                    tooltip: s.thoughtSentBannerCloseTooltip,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: c.dismissThoughtSentBanner,
                    icon: Icon(Icons.close_rounded, color: tokens.mutedInk),
                  ),
                ],
              ),
              if (sentNote != null) ...<Widget>[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.surfaceHigh.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(
                        DeepSkyTheme.radiusMd,
                      ),
                    ),
                    child: Text(
                      '“$sentNote”',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      // State C: Default calm Home quick-send "Ti penso" card
      activeCard = KeyedSubtree(
        key: const ValueKey<String>('thought-card-compose'),
        child: Container(
          key: const Key('ds2-status-card'),
          decoration: BoxDecoration(
            color: tokens.cardSurface.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(DeepSkyTheme.radiusXl),
            border: Border.all(
              color: tokens.cardBorder.withValues(alpha: 0.35),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            key: const Key('ds2-thought-action-card'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.favorite_border_rounded, color: tokens.blushPetal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          s.quickThoughtTitle,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          s.quickThoughtSubtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.mutedInk),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildThoughtComposer(
                compactStacked: compactStacked,
                fieldKey: const Key('thought-note-field'),
                buttonKey: const Key('send-thought-button'),
                controller: _noteController,
                focusNode: _noteFocusNode,
                hintText: s.thoughtNoteHint,
                buttonLabel: s.sendThoughtLabel,
                canWrite: canWrite,
                onSubmit: () => _submitQuickThought(c),
              ),
              if (c.errorNotice != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(c.errorNotice!, style: TextStyle(color: scheme.error)),
              ],
            ],
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: c.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 240),
      child: activeCard,
    );
  }

  Widget _buildThoughtComposer({
    required bool compactStacked,
    required Key fieldKey,
    required Key buttonKey,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required String buttonLabel,
    required bool canWrite,
    required VoidCallback onSubmit,
  }) {
    final Widget field = TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      enabled: canWrite,
      maxLength: 140,
      textInputAction: TextInputAction.send,
      onSubmitted: canWrite ? (_) => onSubmit() : null,
      decoration: InputDecoration(
        hintText: hintText,
        counterText: '',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
    final Widget button = FilledButton.icon(
      key: buttonKey,
      onPressed: canWrite ? onSubmit : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      icon: const Icon(Icons.favorite_rounded, size: 16),
      label: Text(buttonLabel),
    );

    if (compactStacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[field, const SizedBox(height: 8), button],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: field),
        const SizedBox(width: 8),
        button,
      ],
    );
  }

  Future<void> _submitQuickThought(DeepSkyController c) async {
    final String note = _noteController.text;
    await c.sendThinkingOfYou(note: note);
    if (c.errorNotice == null) {
      _noteController.clear();
    }
  }

  Future<void> _submitReplyThought(DeepSkyController c) async {
    final String note = _replyNoteController.text;
    await c.replyToPartnerThought(note: note);
    if (c.errorNotice == null) {
      _replyNoteController.clear();
    }
  }

  Widget _buildPushOptInCard(
    BuildContext context,
    DeepSkyController c,
    DeepSkyStrings s,
    DeepSkyTokens tokens,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        key: const Key('push-optin-card'),
        color: tokens.cardSurface.withValues(alpha: 0.94),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.notifications_active_outlined,
                    size: 20,
                    color: tokens.calmAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.pushPromptTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                s.pushPromptBody,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: tokens.mutedInk),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.tonal(
                    key: const Key('push-optin-enable-button'),
                    onPressed: c.busy ? null : c.enableRuntimePush,
                    child: Text(s.pushPromptEnableButton),
                  ),
                  TextButton(
                    key: const Key('push-optin-later-button'),
                    onPressed: c.busy ? null : c.dismissPushPrompt,
                    child: Text(s.pushPromptLaterButton),
                  ),
                ],
              ),
              if (c.pushFeedback != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  c.pushFeedback!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.pushFeedbackIsError
                        ? Theme.of(context).colorScheme.error
                        : tokens.calmAccent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsTab(
    BuildContext context,
    DeepSkyController c,
    DeepSkyStrings s,
    DeepSkyTokens tokens,
  ) {
    final LocalDeviceIdentity id = c.identity!;
    final bool canMutateServer = !c.busy && !c.isOffline && !c.isDeviceRevoked;
    final String partnerLabel =
        c.partnerDisplayLabel ?? s.spaceSetupPreviewPartnerFallback;

    return ListView(
      key: const Key('us-tab-list'),
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.favorite_rounded, color: tokens.blushPetal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${id.deviceLabel} & $partnerLabel',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      key: const Key('refresh-sync-button'),
                      tooltip: s.usSyncNowButton,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: c.busy ? null : c.refreshSync,
                      icon: const Icon(Icons.sync_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${id.coupleId}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: tokens.mutedInk),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  key: const Key('create-enrollment-invite-button'),
                  onPressed: canMutateServer ? c.createEnrollmentInvite : null,
                  icon: const Icon(Icons.devices),
                  label: Text(
                    c.languageCode == 'it'
                        ? 'Aggiungi un altro telefono'
                        : 'Add another phone',
                  ),
                ),
                if (c.activeInvite != null) ...<Widget>[
                  const SizedBox(height: 12),
                  InviteVerificationSection(
                    invite: c.activeInvite!,
                    serverUrl: id.serverUrl,
                    sasCode: c.activeSasCode,
                    acceptedDeviceLabel: c.activeInviteStatus?.acceptedLabel,
                    busy: !canMutateServer,
                    onPoll: c.pollActiveInvite,
                    onAutoPoll: c.pollActiveInviteSilently,
                    autoPollInterval: c.inviteAutoPollInterval,
                    onConfirmSas: c.confirmSasAndDeliverRootKey,
                    onCancel: c.cancelActiveInvite,
                    onSecureScreenChanged: c.setSecureScreen,
                    tokenLabelPrefix: 'Invito nuovo telefono',
                    waitingStatusLabel: s.waitingForNewDeviceAutoDetect,
                    pollButtonLabel: s.checkPartnerJoinedButton,
                    confirmButtonLabel:
                        'Il codice coincide · Completa arruolamento',
                    tokenKey: const Key('enroll-invite-token'),
                    pollButtonKey: const Key('enroll-poll-invite-button'),
                    sasCodeKey: const Key('enroll-sas-code'),
                    confirmButtonKey: const Key('enroll-confirm-sas-button'),
                  ),
                ],
                if (c.statusNotice != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    c.statusNotice!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: tokens.calmAccent),
                  ),
                ],
                if (c.errorNotice != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    c.errorNotice!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  s.devicesSectionTitle(c.devices.length),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                for (final DeviceSummary dev in c.devices)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(dev.label),
                    subtitle: Text(
                      dev.revokedAt != null
                          ? s.deviceStatusRevoked
                          : (dev.deviceId == id.deviceId
                                ? s.deviceStatusThisPhone
                                : s.deviceStatusActive),
                    ),
                    trailing:
                        (dev.deviceId != id.deviceId && dev.revokedAt == null)
                        ? TextButton(
                            key: Key('revoke-device-${dev.deviceId}'),
                            onPressed: canMutateServer
                                ? () => _confirmActionDialog(
                                    context: context,
                                    title: s.revokeDialogTitle,
                                    body: s.revokeDialogBody(dev.label),
                                    cancelLabel: s.cancel,
                                    confirmLabel: s.revokeDialogConfirm,
                                    confirmKey: Key(
                                      'confirm-revoke-${dev.deviceId}',
                                    ),
                                    onConfirm: () =>
                                        c.revokeDevice(dev.deviceId),
                                  )
                                : null,
                            child: Text(s.revokeDeviceAction),
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('unlink-device-button'),
          onPressed: c.busy
              ? null
              : (c.isDeviceRevoked
                    ? c.unlinkCurrentDevice
                    : () => _confirmActionDialog(
                        context: context,
                        title: s.unlinkDialogTitle,
                        body: c.isOffline
                            ? s.unlinkDialogBodyOffline
                            : s.unlinkDialogBodyOnline,
                        cancelLabel: s.cancel,
                        confirmLabel: s.unlinkDialogConfirm,
                        confirmKey: const Key('confirm-unlink-device-button'),
                        onConfirm: c.unlinkCurrentDevice,
                      )),
          icon: const Icon(Icons.phonelink_erase_outlined),
          label: Text(s.unlinkThisDeviceButton),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const Key('unpair-couple-button'),
          onPressed: canMutateServer
              ? () => _confirmActionDialog(
                  context: context,
                  title: s.unpairDialogTitle,
                  body: s.unpairDialogBody,
                  cancelLabel: s.cancel,
                  confirmLabel: s.unpairDialogConfirm,
                  confirmKey: const Key('confirm-unpair-couple-button'),
                  onConfirm: c.unpairCouple,
                )
              : null,
          icon: const Icon(Icons.link_off),
          label: Text(s.unpairCoupleButton),
        ),
      ],
    );
  }

  Future<void> _confirmActionDialog({
    required BuildContext context,
    required String title,
    required String body,
    required String cancelLabel,
    required String confirmLabel,
    required Key confirmKey,
    required Future<void> Function() onConfirm,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            key: confirmKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await onConfirm();
    }
  }
}
