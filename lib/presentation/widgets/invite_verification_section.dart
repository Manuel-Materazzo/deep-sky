import 'package:deep_sky/data/couple_api_client.dart';
import 'package:deep_sky/domain/pairing/invite_link_codec.dart';
import 'package:deep_sky/presentation/theme/deep_sky_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Shared pairing/enrollment invite widget displaying the QR code, token,
/// peer join polling button, SAS verification code, and key-delivery confirmation.
class InviteVerificationSection extends StatelessWidget {
  const InviteVerificationSection({
    super.key,
    required this.invite,
    required this.serverUrl,
    required this.sasCode,
    this.acceptedDeviceLabel,
    required this.busy,
    required this.onPoll,
    required this.onConfirmSas,
    this.onCancel,
    this.tokenLabelPrefix = 'Codice invito',
    this.pollButtonLabel = 'Verifica se il partner si è unito',
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
  final VoidCallback onConfirmSas;
  final VoidCallback? onCancel;
  final String tokenLabelPrefix;
  final String pollButtonLabel;
  final String confirmButtonLabel;
  final Key tokenKey;
  final Key pollButtonKey;
  final Key sasCodeKey;
  final Key confirmButtonKey;

  @override
  Widget build(BuildContext context) {
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    final String inviteUri = InviteLinkCodec.buildInviteUri(
      serverUrl: serverUrl,
      inviteToken: invite.inviteToken,
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
          '$tokenLabelPrefix: ${invite.inviteToken}',
          key: tokenKey,
        ),
        const SizedBox(height: 12),
        if (sasCode == null)
          FilledButton.tonalIcon(
            key: pollButtonKey,
            onPressed: busy ? null : onPoll,
            icon: const Icon(Icons.sync),
            label: Text(pollButtonLabel),
          )
        else ...<Widget>[
          if (acceptedDeviceLabel != null &&
              acceptedDeviceLabel!.trim().isNotEmpty) ...<Widget>[
            Text(
              'Dispositivo collegato: $acceptedDeviceLabel',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: tokens.mutedInk),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            'Codice di verifica SAS: $sasCode',
            key: sasCodeKey,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: confirmButtonKey,
            onPressed: busy ? null : onConfirmSas,
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(confirmButtonLabel),
          ),
        ],
        if (onCancel != null) ...<Widget>[
          const SizedBox(height: 4),
          TextButton(
            onPressed: busy ? null : onCancel,
            child: const Text('Annulla invito'),
          ),
        ],
      ],
    );
  }
}
