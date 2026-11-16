import 'package:deep_sky/domain/crypto/recovery_key_codec.dart';
import 'package:deep_sky/presentation/deep_sky_controller.dart';
import 'package:deep_sky/presentation/l10n/deep_sky_strings.dart';
import 'package:deep_sky/presentation/theme/deep_sky_theme.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Dedicated pre-Home Recovery Key safekeeping step (`S1-D04`, `S1-APP-02`, `S-06`).
class RecoveryKeySetupPage extends StatefulWidget {
  const RecoveryKeySetupPage({super.key, required this.controller});

  final DeepSkyController controller;

  @override
  State<RecoveryKeySetupPage> createState() => _RecoveryKeySetupPageState();
}

class _RecoveryKeySetupPageState extends State<RecoveryKeySetupPage> {
  bool _showQrView = false;
  bool _confirmedSaved = false;

  @override
  Widget build(BuildContext context) {
    final DeepSkyController c = widget.controller;
    final DeepSkyStrings s = DeepSkyStrings(c.languageCode);
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    final ThemeData theme = Theme.of(context);
    final Uint8List? seed = c.recoverySeed;

    if (seed == null) {
      return Scaffold(
        key: const Key('recovery-key-setup-page'),
        body: Center(child: Text(s.offlineReadOnlyBanner)),
      );
    }

    final List<String> words = RecoveryKeyCodec.toWords(seed);
    final String sentence = words.join(' ');
    final String qrPayload = RecoveryKeyCodec.toQrPayload(seed);

    return Scaffold(
      key: const Key('recovery-key-setup-page'),
      appBar: AppBar(
        title: Text(s.recoverySetupAppBarTitle),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 14),
                  Text(
                    s.recoverySetupHeadline,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.recoverySetupSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.mutedInk,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: <ButtonSegment<bool>>[
                      ButtonSegment<bool>(
                        value: false,
                        icon: const Icon(Icons.format_list_numbered_rounded),
                        label: Text(s.recoveryShowWordsTab),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: const Icon(Icons.qr_code_2_rounded),
                        label: Text(s.recoveryShowQrTab),
                      ),
                    ],
                    selected: <bool>{_showQrView},
                    onSelectionChanged: (Set<bool> selection) {
                      setState(() => _showQrView = selection.first);
                    },
                  ),
                  const SizedBox(height: 14),
                  if (!_showQrView)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                for (int i = 0; i < words.length; i++)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tokens.surfaceLow,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${i + 1}. ${words[i]}',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              sentence,
                              key: const Key('recovery-24-words'),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: tokens.mutedInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: <Widget>[
                            Container(
                              key: const Key('recovery-qr-image'),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.all(14),
                              child: QrImageView(
                                data: qrPayload,
                                size: 200,
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        key: const Key('copy-recovery-words-button'),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: sentence),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(s.recoveryCopiedNotice)),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(s.recoveryCopyWordsButton),
                      ),
                      OutlinedButton.icon(
                        key: const Key('export-recovery-button'),
                        onPressed: () async {
                          final bool launched = await c.shareText(
                            subject: s.recoverySetupAppBarTitle,
                            text:
                                '${s.recoverySetupAppBarTitle} (Deep Sky):\n$sentence',
                          );
                          if (!launched && context.mounted) {
                            await Clipboard.setData(
                              ClipboardData(text: sentence),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(s.recoveryCopiedNotice)),
                            );
                          }
                        },
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: Text(s.recoveryExportButton),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.surfaceLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.shield_outlined,
                              size: 18,
                              color: tokens.calmAccent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.recoveryWarningTitle,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.recoveryWarningBody,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.mutedInk,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    key: const Key('recovery-saved-checkbox'),
                    contentPadding: EdgeInsets.zero,
                    value: _confirmedSaved,
                    onChanged: (bool? v) {
                      setState(() => _confirmedSaved = v ?? false);
                    },
                    title: Text(s.confirmRecoveryCheckbox),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const Key('confirm-recovery-button'),
                    onPressed:
                        (!c.busy &&
                            !c.isOffline &&
                            !c.isDeviceRevoked &&
                            _confirmedSaved)
                        ? c.confirmRecoveryKeySaved
                        : null,
                    child: Text(s.confirmRecoveryButton),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
