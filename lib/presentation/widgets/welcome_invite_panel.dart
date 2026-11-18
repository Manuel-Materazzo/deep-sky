import 'dart:async';

import 'package:deep_sky/data/couple_api_client.dart';
import 'package:deep_sky/presentation/deep_sky_controller.dart';
import 'package:deep_sky/presentation/l10n/deep_sky_strings.dart';
import 'package:deep_sky/presentation/theme/deep_sky_theme.dart';
import 'package:deep_sky/presentation/widgets/invite_verification_section.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Primary partner invite card (`S1-D03`, `S1-D05`) showing QR code, share CTA,
/// compact copyable link, waiting status, expiry, regeneration, and SAS approval.
class WelcomeInvitePanel extends StatefulWidget {
  const WelcomeInvitePanel({
    super.key,
    required this.controller,
    required this.strings,
  });

  final DeepSkyController controller;
  final DeepSkyStrings strings;

  @override
  State<WelcomeInvitePanel> createState() => _WelcomeInvitePanelState();
}

class _WelcomeInvitePanelState extends State<WelcomeInvitePanel> {
  bool _copied = false;
  Timer? _copiedResetTimer;
  Timer? _expiryTicker;
  Timer? _autoPollTimer;
  String? _polledInviteToken;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncAutoPollTimer);
    unawaited(widget.controller.setSecureScreen(true));
    _expiryTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _syncAutoPollTimer();
        setState(() {});
      }
    });
    _syncAutoPollTimer();
  }

  @override
  void didUpdateWidget(covariant WelcomeInvitePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncAutoPollTimer);
      widget.controller.addListener(_syncAutoPollTimer);
    }
    _syncAutoPollTimer();
  }

  @override
  void dispose() {
    unawaited(widget.controller.setSecureScreen(false));
    widget.controller.removeListener(_syncAutoPollTimer);
    _copiedResetTimer?.cancel();
    _expiryTicker?.cancel();
    _autoPollTimer?.cancel();
    super.dispose();
  }

  void _syncAutoPollTimer() {
    final DeepSkyController c = widget.controller;
    final CreateInviteResponse? invite = c.activeInvite;
    final bool shouldPoll =
        invite != null &&
        c.activeSasCode == null &&
        c.phase == AppBootPhase.waiting &&
        invite.expiresAt.toUtc().isAfter(DateTime.now().toUtc());

    if (!shouldPoll) {
      _autoPollTimer?.cancel();
      _autoPollTimer = null;
      _polledInviteToken = null;
      return;
    }

    if (_autoPollTimer != null && _polledInviteToken == invite.inviteToken) {
      return;
    }

    _autoPollTimer?.cancel();
    _polledInviteToken = invite.inviteToken;
    _autoPollTimer = Timer.periodic(c.inviteAutoPollInterval, (_) {
      if (!mounted) {
        return;
      }
      if (!invite.expiresAt.toUtc().isAfter(DateTime.now().toUtc())) {
        _syncAutoPollTimer();
        setState(() {});
        return;
      }
      unawaited(c.pollActiveInviteSilently());
    });
  }

  Future<void> _copyInviteLink(String inviteUri) async {
    await widget.controller.copySensitiveText(inviteUri);
    _copiedResetTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    _copiedResetTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final DeepSkyController c = widget.controller;
    final DeepSkyStrings s = widget.strings;
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: tokens.cardSurface,
        borderRadius: BorderRadius.circular(DeepSkyTheme.radiusXl),
        border: Border.all(color: tokens.cardBorder.withValues(alpha: 0.28)),
      ),
      padding: const EdgeInsets.all(DeepSkyTheme.spaceMd),
      child: _buildBody(context, c, s, tokens, scheme),
    );
  }

  Widget _buildBody(
    BuildContext context,
    DeepSkyController c,
    DeepSkyStrings s,
    DeepSkyTokens tokens,
    ColorScheme scheme,
  ) {
    final CreateInviteResponse? invite = c.activeInvite;

    if (invite == null && c.busy) {
      return Padding(
        key: const Key('invite-loading-state'),
        padding: const EdgeInsets.symmetric(vertical: DeepSkyTheme.spaceXl),
        child: Column(
          children: <Widget>[
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: scheme.primaryContainer,
              ),
            ),
            const SizedBox(height: DeepSkyTheme.spaceMd),
            Text(
              s.preparingHomeMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: tokens.mutedInk),
            ),
          ],
        ),
      );
    }

    if (invite == null) {
      return Padding(
        key: const Key('invite-error-state'),
        padding: const EdgeInsets.symmetric(vertical: DeepSkyTheme.spaceMd),
        child: Column(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.surfaceHigh,
              ),
              child: Icon(
                Icons.cloud_off_outlined,
                color: tokens.warmGlow,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              s.inviteErrorTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              s.inviteErrorBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: tokens.mutedInk),
            ),
            const SizedBox(height: DeepSkyTheme.spaceMd),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('create-invite-button'),
                onPressed: c.busy ? null : c.retryInitialInvite,
                icon: const Icon(Icons.refresh),
                label: Text(s.retryButton),
              ),
            ),
          ],
        ),
      );
    }

    if (c.activeSasCode != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InviteVerificationSection(
            invite: invite,
            serverUrl: c.activeServerUrl,
            sasCode: c.activeSasCode,
            acceptedDeviceLabel: c.activeInviteStatus?.acceptedLabel,
            busy: c.busy,
            onPoll: c.pollActiveInvite,
            onConfirmSas: c.confirmSasAndDeliverRootKey,
            onCancel: c.regenerateInitialInvite,
          ),
          ..._buildNotices(context, c, tokens, scheme),
        ],
      );
    }

    final String inviteUri = c.activeInviteUri!;
    final String compactLink = c.activeInviteDisplayLink!;
    final DateTime nowUtc = DateTime.now().toUtc();
    final Duration remaining = invite.expiresAt.toUtc().difference(nowUtc);
    final bool isExpired = remaining <= Duration.zero;
    final int remainingMinutes = (remaining.inSeconds / 60).ceil().clamp(1, 99);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const SizedBox(height: 4),
        Semantics(
          label: s.qrSemanticsLabel,
          child: Opacity(
            opacity: isExpired ? 0.45 : 1.0,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tokens.qrFrameSurface,
                borderRadius: BorderRadius.circular(DeepSkyTheme.radiusLg),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  QrImageView(
                    key: const Key('invite-qr-view'),
                    data: inviteUri,
                    size: 148,
                    padding: const EdgeInsets.all(4),
                    backgroundColor: tokens.qrFrameSurface,
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF13091E),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: Color(0xFF13091E),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: tokens.cardSurface,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.favorite,
                      size: 15,
                      color: tokens.warmGlow,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          s.qrCaption,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: tokens.mutedInk),
        ),
        const SizedBox(height: DeepSkyTheme.spaceMd),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DeepSkyTheme.radiusFull),
            boxShadow: isExpired
                ? const <BoxShadow>[]
                : <BoxShadow>[
                    BoxShadow(
                      color: scheme.primaryContainer.withValues(alpha: 0.24),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('share-invite-button'),
              onPressed: c.busy || isExpired
                  ? null
                  : () => c.shareActiveInvite(
                      messagePrefix: s.shareInviteMessage,
                      copiedFallbackNotice: s.shareFallbackCopiedNotice,
                    ),
              icon: const Icon(Icons.send_rounded, size: 19),
              label: Text(s.shareInviteLinkButton),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          decoration: BoxDecoration(
            color: tokens.surfaceHigh,
            borderRadius: BorderRadius.circular(DeepSkyTheme.radiusLg),
            border: Border.all(
              color: tokens.cardBorder.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  compactLink,
                  key: const Key('active-invite-token'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 13, color: tokens.accentText),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: tokens.cardSurface,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  key: const Key('copy-invite-link-button'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: isExpired ? null : () => _copyInviteLink(inviteUri),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 38,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            _copied ? Icons.done : Icons.content_copy_rounded,
                            size: 15,
                            color: _copied ? tokens.warmGlow : scheme.onSurface,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _copied ? s.copiedButton : s.copyButton,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: _copied
                                      ? tokens.warmGlow
                                      : scheme.onSurface,
                                  fontWeight: FontWeight.w600,
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
        const SizedBox(height: 12),
        Divider(height: 1, color: tokens.cardBorder.withValues(alpha: 0.22)),
        const SizedBox(height: 10),
        if (!isExpired) ...<Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.warmGlow,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${s.waitingForPartner} · ${s.expiresInMinutes(remainingMinutes)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 12, color: tokens.mutedInk),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              TextButton.icon(
                key: const Key('poll-invite-button'),
                onPressed: c.busy ? null : c.pollActiveInvite,
                icon: const Icon(Icons.sync, size: 17),
                label: Text(s.checkPartnerJoinedButton),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: tokens.accentText,
                ),
              ),
              TextButton.icon(
                key: const Key('regenerate-invite-button'),
                onPressed: c.busy ? null : c.regenerateInitialInvite,
                icon: const Icon(Icons.refresh, size: 17),
                label: Text(s.regenerateInviteButton),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: tokens.mutedInk,
                ),
              ),
            ],
          ),
        ] else ...<Widget>[
          Text(
            s.inviteExpiredMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: tokens.mutedInk),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('regenerate-invite-button'),
              onPressed: c.busy ? null : c.regenerateInitialInvite,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(s.generateNewInviteButton),
            ),
          ),
        ],
        ..._buildNotices(context, c, tokens, scheme),
      ],
    );
  }

  List<Widget> _buildNotices(
    BuildContext context,
    DeepSkyController c,
    DeepSkyTokens tokens,
    ColorScheme scheme,
  ) {
    return <Widget>[
      if (c.statusNotice != null) ...<Widget>[
        const SizedBox(height: 10),
        Text(
          c.statusNotice!,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: tokens.accentText),
        ),
      ],
      if (c.errorNotice != null) ...<Widget>[
        const SizedBox(height: 10),
        Text(
          c.errorNotice!,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.error),
        ),
      ],
    ];
  }
}
