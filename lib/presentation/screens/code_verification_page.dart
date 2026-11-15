import 'dart:async';

import 'package:deep_sky/data/pairing_and_sync_repository.dart';
import 'package:deep_sky/presentation/deep_sky_controller.dart';
import 'package:deep_sky/presentation/l10n/deep_sky_strings.dart';
import 'package:deep_sky/presentation/theme/deep_sky_theme.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Dedicated two-way SAS code verification screen (`S1-D07`, `S1-D08`, `S1-APP-02`, `S1-APP-03`).
///
/// Shown on both Partner A (after polling a joined device) and Partner B (after
/// accepting an invite link/QR) so both devices can compare the 6-digit SAS
/// plaque side by side before key delivery completes.
class CodeVerificationPage extends StatefulWidget {
  const CodeVerificationPage({super.key, required this.controller});

  final DeepSkyController controller;

  @override
  State<CodeVerificationPage> createState() => _CodeVerificationPageState();
}

class _CodeVerificationPageState extends State<CodeVerificationPage> {
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copySasCode(String sasCode) async {
    await Clipboard.setData(ClipboardData(text: sasCode));
    _copiedTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    _copiedTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  Future<void> _confirmMismatchDialog(
    DeepSkyController c,
    DeepSkyStrings s,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(s.verificationMismatchDialogTitle),
        content: Text(s.verificationMismatchDialogBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.verificationMismatchKeepButton),
          ),
          FilledButton(
            key: const Key('confirm-mismatch-cancel-button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.verificationMismatchConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await c.cancelVerificationOnMismatch();
    }
  }

  static bool _isGenericLabel(String? raw) {
    if (raw == null) {
      return true;
    }
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

    final PendingJoinSession? pending = c.pendingJoin;
    final bool isInviter = pending == null;
    final String sasCode = pending?.sasCode ?? c.activeSasCode ?? '000-000';
    final String? peerLabel = isInviter
        ? c.activeInviteStatus?.acceptedLabel
        : pending.peerLabel;
    final bool hasCustomPeerLabel = !_isGenericLabel(peerLabel);

    final List<String> digits = sasCode
        .replaceAll(RegExp(r'[^0-9A-Za-z]'), '')
        .split('');
    final List<String> leftDigits = digits.take(3).toList(growable: false);
    final List<String> rightDigits = digits
        .skip(3)
        .take(3)
        .toList(growable: false);

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color rightDigitColor = isDark ? tokens.amberSoft : tokens.warmGlow;

    return Scaffold(
      key: const Key('code-verification-page'),
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
                _VerificationTopBar(
                  title: s.verificationAppBarTitle,
                  onBackPressed: c.busy
                      ? null
                      : () {
                          if (isInviter) {
                            c.returnToInviteScreen();
                          } else {
                            c.cancelPendingJoin();
                          }
                        },
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
                            const _ConstellationConnectionHeader(),
                            const SizedBox(height: 16),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.cardSurface,
                                  borderRadius: BorderRadius.circular(
                                    DeepSkyTheme.radiusFull,
                                  ),
                                  border: Border.all(
                                    color: tokens.cardBorder.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.lock_rounded,
                                      size: 14,
                                      color: tokens.warmGlow,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      s.verificationBadge,
                                      style: textTheme.labelMedium?.copyWith(
                                        color: tokens.accentText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              s.verificationHeadline,
                              textAlign: TextAlign.center,
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                s.verificationSubtitle,
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: tokens.mutedInk,
                                ),
                              ),
                            ),
                            if (hasCustomPeerLabel) ...<Widget>[
                              const SizedBox(height: 10),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.surfaceHigh,
                                    borderRadius: BorderRadius.circular(
                                      DeepSkyTheme.radiusFull,
                                    ),
                                  ),
                                  child: Text(
                                    isInviter
                                        ? s.verificationConnectedPeer(
                                            peerLabel!.trim(),
                                          )
                                        : s.verificationInvitedBy(
                                            peerLabel!.trim(),
                                          ),
                                    style: textTheme.labelMedium?.copyWith(
                                      color: tokens.blushPetal,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: tokens.surfaceLow,
                                borderRadius: BorderRadius.circular(
                                  DeepSkyTheme.radiusXl,
                                ),
                                border: Border.all(
                                  color: tokens.cardBorder.withValues(
                                    alpha: 0.28,
                                  ),
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Expanded(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: tokens.warmGlow,
                                                boxShadow: <BoxShadow>[
                                                  BoxShadow(
                                                    color: tokens.warmGlow
                                                        .withValues(alpha: 0.6),
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                s.sharedSasCodeLabel
                                                    .toUpperCase(),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: textTheme.labelSmall
                                                    ?.copyWith(
                                                      color: tokens.mutedInk,
                                                      letterSpacing: 1.0,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Material(
                                        color: tokens.elevatedSurface,
                                        borderRadius: BorderRadius.circular(
                                          DeepSkyTheme.radiusFull,
                                        ),
                                        child: InkWell(
                                          key: const Key('copy-sas-button'),
                                          borderRadius: BorderRadius.circular(
                                            DeepSkyTheme.radiusFull,
                                          ),
                                          onTap: () => _copySasCode(sasCode),
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              minWidth: 44,
                                              minHeight: 32,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: <Widget>[
                                                  Icon(
                                                    _copied
                                                        ? Icons.check_rounded
                                                        : Icons
                                                              .content_copy_rounded,
                                                    size: 14,
                                                    color: _copied
                                                        ? tokens.warmGlow
                                                        : tokens.blushPetal,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _copied
                                                        ? s.copiedButton
                                                        : s.copyButton,
                                                    style: textTheme.labelSmall
                                                        ?.copyWith(
                                                          color: _copied
                                                              ? tokens.warmGlow
                                                              : tokens
                                                                    .blushPetal,
                                                          fontWeight:
                                                              FontWeight.w600,
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
                                  const SizedBox(height: 14),
                                  Semantics(
                                    key: Key(
                                      isInviter
                                          ? 'inviter-sas-code'
                                          : 'joiner-sas-code',
                                    ),
                                    label: 'SAS $sasCode',
                                    excludeSemantics: true,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tokens.surfaceLowest,
                                        borderRadius: BorderRadius.circular(
                                          DeepSkyTheme.radiusLg,
                                        ),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: <Widget>[
                                            for (
                                              int i = 0;
                                              i < leftDigits.length;
                                              i++
                                            ) ...<Widget>[
                                              _SasDigitTile(
                                                digit: leftDigits[i],
                                                color: scheme.primary,
                                              ),
                                              if (i < leftDigits.length - 1)
                                                const SizedBox(width: 6),
                                            ],
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                              child: Text(
                                                '·',
                                                style: textTheme.headlineLarge
                                                    ?.copyWith(
                                                      color: tokens.warmGlow
                                                          .withValues(
                                                            alpha: 0.7,
                                                          ),
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                            for (
                                              int i = 0;
                                              i < rightDigits.length;
                                              i++
                                            ) ...<Widget>[
                                              _SasDigitTile(
                                                digit: rightDigits[i],
                                                color: rightDigitColor,
                                              ),
                                              if (i < rightDigits.length - 1)
                                                const SizedBox(width: 6),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Expanded(
                                        child: Row(
                                          children: <Widget>[
                                            Container(
                                              width: 9,
                                              height: 9,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: scheme.primaryContainer,
                                                boxShadow: <BoxShadow>[
                                                  BoxShadow(
                                                    color: scheme
                                                        .primaryContainer
                                                        .withValues(alpha: 0.6),
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                isInviter
                                                    ? s.verificationReadyToConfirm
                                                    : s.verificationWaitingForPartner,
                                                style: textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: scheme.onSurface,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tokens.elevatedSurface,
                                          borderRadius: BorderRadius.circular(
                                            DeepSkyTheme.radiusFull,
                                          ),
                                        ),
                                        child: Text(
                                          s.verificationSyncedTag,
                                          style: textTheme.labelSmall?.copyWith(
                                            color: tokens.blushPetal,
                                          ),
                                        ),
                                      ),
                                    ],
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
                            const SizedBox(height: 20),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  DeepSkyTheme.radiusFull,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: scheme.primaryContainer.withValues(
                                      alpha: 0.32,
                                    ),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: SizedBox(
                                height: 54,
                                child: FilledButton.icon(
                                  key: Key(
                                    isInviter
                                        ? 'confirm-sas-button'
                                        : 'complete-join-button',
                                  ),
                                  onPressed: c.busy
                                      ? null
                                      : (isInviter
                                            ? c.confirmSasAndDeliverRootKey
                                            : c.completeJoinDelivery),
                                  icon: c.busy
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: scheme.onPrimary,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.verified_rounded,
                                          size: 20,
                                        ),
                                  label: Text(
                                    isInviter
                                        ? s.verificationConfirmInviterButton
                                        : s.verificationConfirmJoinerButton,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 48,
                              child: FilledButton.tonalIcon(
                                key: const Key('mismatch-sas-button'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: tokens.elevatedSurface,
                                  foregroundColor: tokens.blushPetal,
                                ),
                                onPressed: c.busy
                                    ? null
                                    : () => _confirmMismatchDialog(c, s),
                                icon: const Icon(
                                  Icons.cached_rounded,
                                  size: 18,
                                ),
                                label: Text(s.verificationMismatchButton),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: tokens.surfaceLowest.withValues(
                                  alpha: 0.72,
                                ),
                                borderRadius: BorderRadius.circular(
                                  DeepSkyTheme.radiusLg,
                                ),
                                border: Border.all(
                                  color: tokens.cardBorder.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    s.verificationWhyTitle,
                                    style: textTheme.labelMedium?.copyWith(
                                      color: tokens.amberSoft,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    s.verificationWhyBody,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: tokens.mutedInk,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
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

class _VerificationTopBar extends StatelessWidget {
  const _VerificationTopBar({required this.title, required this.onBackPressed});

  final String title;
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: <Widget>[
            IconButton(
              key: const Key('verification-back-button'),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: onBackPressed,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: tokens.mutedInk,
              ),
            ),
            Expanded(
              child: Text(
                title,
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
    );
  }
}

class _ConstellationConnectionHeader extends StatelessWidget {
  const _ConstellationConnectionHeader();

  @override
  Widget build(BuildContext context) {
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _NodeBadge(
          icon: Icons.favorite_rounded,
          iconColor: scheme.primary,
          sparkColor: tokens.warmGlow,
          sparkOnRight: true,
        ),
        const SizedBox(width: 10),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.blushPetal.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 34,
          height: 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DeepSkyTheme.radiusFull),
            gradient: LinearGradient(
              colors: <Color>[
                scheme.primary.withValues(alpha: 0.3),
                tokens.warmGlow,
                scheme.primary.withValues(alpha: 0.3),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.blushPetal.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(width: 10),
        _NodeBadge(
          icon: Icons.spa_rounded,
          iconColor: tokens.warmGlow,
          sparkColor: scheme.primaryContainer,
          sparkOnRight: false,
        ),
      ],
    );
  }
}

class _NodeBadge extends StatelessWidget {
  const _NodeBadge({
    required this.icon,
    required this.iconColor,
    required this.sparkColor,
    required this.sparkOnRight,
  });

  final IconData icon;
  final Color iconColor;
  final Color sparkColor;
  final bool sparkOnRight;

  @override
  Widget build(BuildContext context) {
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.elevatedSurface,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        Positioned(
          top: -1,
          right: sparkOnRight ? -1 : null,
          left: sparkOnRight ? null : -1,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sparkColor,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: sparkColor.withValues(alpha: 0.8),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SasDigitTile extends StatelessWidget {
  const _SasDigitTile({required this.digit, required this.color});

  final String digit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      width: 40,
      height: 54,
      decoration: BoxDecoration(
        color: tokens.surfaceHigh,
        borderRadius: BorderRadius.circular(DeepSkyTheme.radiusMd),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        digit,
        style: textTheme.headlineLarge?.copyWith(
          fontSize: 32,
          height: 1.0,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
