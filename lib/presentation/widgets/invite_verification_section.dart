import 'dart:async';

import 'package:deep_sky/data/couple_api_client.dart';
import 'package:deep_sky/domain/pairing/invite_link_codec.dart';
import 'package:deep_sky/presentation/theme/deep_sky_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Shared pairing/enrollment invite widget displaying the QR code, token,
/// automatic peer-join detection (with manual fallback), SAS verification code,
/// and key-delivery confirmation.
class InviteVerificationSection extends StatefulWidget {
  const InviteVerificationSection({
    super.key,
    required this.invite,
    required this.serverUrl,
    required this.sasCode,
    this.acceptedDeviceLabel,
    required this.busy,
    required this.onPoll,
    this.onAutoPoll,
    this.autoPollInterval = const Duration(seconds: 3),
    required this.onConfirmSas,
    this.onCancel,
    this.onSecureScreenChanged,
    this.tokenLabelPrefix = 'Codice invito',
    this.waitingStatusLabel,
    this.pollButtonLabel = 'Controlla ora',
    this.confirmButtonLabel = 'Il codice coincide · Completa abbinamento',
    this.tokenKey = const Key('active-invite-token'),
    this.pollButtonKey = const Key('poll-invite-button'),
    this.sasCodeKey = const Key('inviter-sas-code'),
    this.confirmButtonKey = const Key('confirm-sas-button'),
  });

  final CreateInviteResponse invite;
  final String serverUrl;
  final String? sasCode;
  final String? acceptedDeviceLabel;
  final bool busy;
  final VoidCallback onPoll;
  final Future<void> Function()? onAutoPoll;
  final Duration autoPollInterval;
  final VoidCallback onConfirmSas;
  final VoidCallback? onCancel;
  final Future<void> Function(bool enabled)? onSecureScreenChanged;
  final String tokenLabelPrefix;
  final String? waitingStatusLabel;
  final String pollButtonLabel;
  final String confirmButtonLabel;
  final Key tokenKey;
  final Key pollButtonKey;
  final Key sasCodeKey;
  final Key confirmButtonKey;

  @override
  State<InviteVerificationSection> createState() =>
      _InviteVerificationSectionState();
}

class _InviteVerificationSectionState extends State<InviteVerificationSection> {
  Timer? _autoPollTimer;

  @override
  void initState() {
    super.initState();
    final fn = widget.onSecureScreenChanged;
    if (fn != null) {
      unawaited(fn(true));
    }
    _syncAutoPollTimer();
  }

  @override
  void didUpdateWidget(covariant InviteVerificationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.invite.inviteToken != widget.invite.inviteToken ||
        oldWidget.sasCode != widget.sasCode ||
        oldWidget.onAutoPoll != widget.onAutoPoll ||
        oldWidget.autoPollInterval != widget.autoPollInterval) {
      _syncAutoPollTimer(forceRestart: true);
    }
  }

  @override
  void dispose() {
    final fn = widget.onSecureScreenChanged;
    if (fn != null) {
      unawaited(fn(false));
    }
    _autoPollTimer?.cancel();
    super.dispose();
  }

  void _syncAutoPollTimer({bool forceRestart = false}) {
    final bool shouldPoll =
        widget.sasCode == null &&
        widget.onAutoPoll != null &&
        widget.invite.expiresAt.toUtc().isAfter(DateTime.now().toUtc());

    if (!shouldPoll) {
      _autoPollTimer?.cancel();
      _autoPollTimer = null;
      return;
    }

    if (_autoPollTimer != null && !forceRestart) {
      return;
    }

    _autoPollTimer?.cancel();
    _autoPollTimer = Timer.periodic(widget.autoPollInterval, (_) {
      if (!mounted) {
        return;
      }
      if (!widget.invite.expiresAt.toUtc().isAfter(DateTime.now().toUtc())) {
        _syncAutoPollTimer();
        setState(() {});
        return;
      }
      final Future<void> Function()? autoPoll = widget.onAutoPoll;
      if (autoPoll != null) {
        unawaited(autoPoll());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    final String inviteUri = InviteLinkCodec.buildInviteUri(
      serverUrl: widget.serverUrl,
      inviteToken: widget.invite.inviteToken,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: tokens.qrFrameSurface,
              borderRadius: BorderRadius.circular(DeepSkyTheme.radiusLg),
            ),
            padding: const EdgeInsets.all(10),
            child: QrImageView(
              data: inviteUri,
              size: 150,
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
          ),
        ),
        const SizedBox(height: 8),
        SelectableText(
          '${widget.tokenLabelPrefix}: ${widget.invite.inviteToken}',
          key: widget.tokenKey,
        ),
        const SizedBox(height: 12),
        if (widget.sasCode == null) ...<Widget>[
          if (widget.waitingStatusLabel != null) ...<Widget>[
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
                    widget.waitingStatusLabel!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: tokens.mutedInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          TextButton.icon(
            key: widget.pollButtonKey,
            onPressed: widget.busy ? null : widget.onPoll,
            icon: const Icon(Icons.sync, size: 17),
            label: Text(widget.pollButtonLabel),
          ),
        ] else ...<Widget>[
          if (widget.acceptedDeviceLabel != null &&
              widget.acceptedDeviceLabel!.trim().isNotEmpty) ...<Widget>[
            Text(
              'Dispositivo collegato: ${widget.acceptedDeviceLabel}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.mutedInk),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            'Codice di verifica SAS: ${widget.sasCode}',
            key: widget.sasCodeKey,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: widget.confirmButtonKey,
            onPressed: widget.busy ? null : widget.onConfirmSas,
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(widget.confirmButtonLabel),
          ),
        ],
        if (widget.onCancel != null) ...<Widget>[
          const SizedBox(height: 4),
          TextButton(
            onPressed: widget.busy ? null : widget.onCancel,
            child: const Text('Annulla invito'),
          ),
        ],
      ],
    );
  }
}
