import 'package:deep_sky/presentation/deep_sky_controller.dart';
import 'package:deep_sky/presentation/l10n/deep_sky_strings.dart';
import 'package:deep_sky/presentation/theme/deep_sky_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Dedicated post-verification name/space setup step (`S1-D07-2`, `S1-D09`).
///
/// Gives the user a warm, visible moment to set the name their partner sees in
/// the couple space rather than burying it inside onboarding settings.
class SpaceSetupPage extends StatefulWidget {
  const SpaceSetupPage({super.key, required this.controller});

  final DeepSkyController controller;

  @override
  State<SpaceSetupPage> createState() => _SpaceSetupPageState();
}

class _SpaceSetupPageState extends State<SpaceSetupPage> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final String initial = _isDefaultDeviceLabel(widget.controller.deviceLabel)
        ? ''
        : widget.controller.deviceLabel.trim();
    _nameController = TextEditingController(text: initial);
    _nameController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onTextChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  static bool _isDefaultDeviceLabel(String raw) {
    final String lower = raw.trim().toLowerCase();
    return lower.isEmpty ||
        lower == 'telefono principale' ||
        lower == 'primary phone' ||
        lower == 'android device';
  }

  @override
  Widget build(BuildContext context) {
    final DeepSkyController c = widget.controller;
    final DeepSkyStrings s = DeepSkyStrings(c.languageCode);
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String typedName = _nameController.text.trim();
    final String previewUserName = typedName.isNotEmpty
        ? typedName
        : s.spaceSetupPreviewYouFallback;

    final String? rawPartner = c.partnerDisplayLabel;
    final String previewPartnerName =
        (rawPartner != null && !_isDefaultDeviceLabel(rawPartner))
        ? rawPartner
        : s.spaceSetupPreviewPartnerFallback;

    return Scaffold(
      key: const Key('space-setup-page'),
      backgroundColor: tokens.skyBackdrop,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.78),
                    radius: 1.05,
                    colors: <Color>[
                      tokens.elevatedSurface.withValues(alpha: 0.65),
                      tokens.skyBackdrop.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 58,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: <Widget>[
                        const SizedBox(width: 34),
                        Expanded(
                          child: Text(
                            s.spaceSetupAppBarTitle,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.primary,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.28),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            size: 18,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.surfaceHigh,
                                  borderRadius: BorderRadius.circular(
                                    DeepSkyTheme.radiusFull,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 14,
                                      color: tokens.warmGlow,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      s.spaceSetupBadge.toUpperCase(),
                                      style: textTheme.labelSmall?.copyWith(
                                        color: tokens.blushPetal,
                                        letterSpacing: 0.9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              s.spaceSetupHeadline,
                              textAlign: TextAlign.center,
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              s.spaceSetupSubtitle,
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: tokens.mutedInk,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.surfaceLowest,
                                borderRadius: BorderRadius.circular(
                                  DeepSkyTheme.radiusLg,
                                ),
                                border: Border.all(
                                  color: tokens.cardBorder.withValues(
                                    alpha: 0.26,
                                  ),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: <Color>[
                                    scheme.primaryContainer.withValues(
                                      alpha: 0.12,
                                    ),
                                    tokens.warmGlow.withValues(alpha: 0.06),
                                    tokens.surfaceLowest,
                                  ],
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: <Widget>[
                                  _PreviewAvatarColumn(
                                    icon: Icons.person_rounded,
                                    accentColor: scheme.primaryContainer,
                                    iconColor: scheme.primary,
                                    tagText: previewUserName,
                                    tagColor: scheme.primary,
                                    tagKey: const Key('preview-user-tag'),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(
                                        Icons.favorite_rounded,
                                        size: 20,
                                        color: tokens.warmGlow,
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        width: 56,
                                        height: 2,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            DeepSkyTheme.radiusFull,
                                          ),
                                          gradient: LinearGradient(
                                            colors: <Color>[
                                              scheme.primary.withValues(
                                                alpha: 0.35,
                                              ),
                                              tokens.warmGlow.withValues(
                                                alpha: 0.6,
                                              ),
                                              scheme.secondary.withValues(
                                                alpha: 0.35,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        s.spaceSetupPreviewHomeLabel,
                                        style: textTheme.labelSmall?.copyWith(
                                          color: tokens.amberSoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                  _PreviewAvatarColumn(
                                    icon: Icons.favorite_border_rounded,
                                    accentColor: tokens.warmGlow,
                                    iconColor: tokens.warmGlow,
                                    tagText: previewPartnerName,
                                    tagColor: scheme.secondary,
                                    tagKey: const Key('preview-partner-tag'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: tokens.surfaceLow,
                                borderRadius: BorderRadius.circular(
                                  DeepSkyTheme.radiusLg,
                                ),
                                border: Border.all(
                                  color: tokens.cardBorder.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Icon(
                                        Icons.badge_outlined,
                                        size: 20,
                                        color: scheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          s.spaceSetupInputLabel,
                                          style: textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        s.spaceSetupInputVisibleHint,
                                        style: textTheme.labelSmall?.copyWith(
                                          color: tokens.blushPetal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    key: const Key('space-setup-name-field'),
                                    controller: _nameController,
                                    maxLength: 64,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: c.busy
                                        ? null
                                        : (String v) => c.completeNameSetup(v),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: tokens.surfaceLowest,
                                      counterText: '',
                                      hintText: s.spaceSetupInputPlaceholder,
                                      suffixIcon:
                                          _nameController.text.isNotEmpty
                                          ? IconButton(
                                              key: const Key(
                                                'space-setup-clear-button',
                                              ),
                                              tooltip: s.spaceSetupClearTooltip,
                                              onPressed: () {
                                                _nameController.clear();
                                              },
                                              icon: Icon(
                                                Icons.cancel_rounded,
                                                size: 18,
                                                color: tokens.mutedInk,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (c.errorNotice != null) ...<Widget>[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: scheme.errorContainer,
                                  borderRadius: BorderRadius.circular(
                                    DeepSkyTheme.radiusMd,
                                  ),
                                ),
                                child: Text(
                                  c.errorNotice!,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  DeepSkyTheme.radiusFull,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: scheme.primaryContainer.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 22,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: SizedBox(
                                height: 54,
                                child: FilledButton(
                                  key: const Key('space-setup-submit-button'),
                                  onPressed: c.busy
                                      ? null
                                      : () => c.completeNameSetup(
                                          _nameController.text,
                                        ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      if (c.busy)
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: scheme.onPrimary,
                                          ),
                                        )
                                      else
                                        const Icon(
                                          Icons.vpn_key_rounded,
                                          size: 20,
                                        ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          s.spaceSetupSubmitButton,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              key: const Key('space-setup-skip-button'),
                              onPressed: c.busy ? null : c.skipNameSetup,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(44, 44),
                                foregroundColor: tokens.mutedInk,
                              ),
                              child: Text(
                                s.spaceSetupSkipButton,
                                textAlign: TextAlign.center,
                                style: textTheme.labelMedium?.copyWith(
                                  color: tokens.mutedInk,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewAvatarColumn extends StatelessWidget {
  const _PreviewAvatarColumn({
    required this.icon,
    required this.accentColor,
    required this.iconColor,
    required this.tagText,
    required this.tagColor,
    required this.tagKey,
  });

  final IconData icon;
  final Color accentColor;
  final Color iconColor;
  final String tagText;
  final Color tagColor;
  final Key tagKey;

  @override
  Widget build(BuildContext context) {
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.surfaceHigh,
                border: Border.all(color: accentColor.withValues(alpha: 0.45)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.24),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Icon(icon, size: 26, color: iconColor),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.8),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxWidth: 108),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: tokens.surfaceHigh,
            borderRadius: BorderRadius.circular(DeepSkyTheme.radiusFull),
          ),
          child: Text(
            tagText,
            key: tagKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: textTheme.labelMedium?.copyWith(
              color: tagColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
