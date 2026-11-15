import 'package:deep_sky/domain/pairing/invite_link_codec.dart';
import 'package:deep_sky/presentation/l10n/deep_sky_strings.dart';
import 'package:deep_sky/presentation/theme/deep_sky_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Collapsible server configuration card for self-hosters (`S1-D02-D03-D05`, `P-09`).
///
/// Collapsed by default so non-technical partners are not confronted with server
/// details unless they choose to customize the host.
class WelcomeServerDrawer extends StatefulWidget {
  const WelcomeServerDrawer({
    super.key,
    required this.serverUrl,
    required this.defaultServerUrl,
    required this.isCustomServer,
    required this.busy,
    required this.strings,
    required this.serverController,
    required this.onSaveServer,
    required this.onResetOfficial,
  });

  final String serverUrl;
  final String defaultServerUrl;
  final bool isCustomServer;
  final bool busy;
  final DeepSkyStrings strings;
  final TextEditingController serverController;
  final Future<void> Function(String rawUrl) onSaveServer;
  final Future<void> Function() onResetOfficial;

  @override
  State<WelcomeServerDrawer> createState() => _WelcomeServerDrawerState();
}

class _WelcomeServerDrawerState extends State<WelcomeServerDrawer> {
  bool _expanded = false;
  String? _validationError;

  Future<void> _handleSave() async {
    final String raw = widget.serverController.text.trim();
    try {
      final String normalized = InviteLinkCodec.normalizeServerUrl(raw);
      setState(() => _validationError = null);
      widget.serverController.text = normalized;
      await widget.onSaveServer(normalized);
      if (mounted) {
        setState(() => _expanded = false);
      }
    } on FormatException {
      setState(() => _validationError = widget.strings.invalidServerAddress);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DeepSkyStrings s = widget.strings;
    final String displayHost = InviteLinkCodec.displayHost(widget.serverUrl);
    final String summary = widget.isCustomServer
        ? s.serverCustomSummary(displayHost)
        : s.serverOfficialSummary(displayHost);

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceLow,
        borderRadius: BorderRadius.circular(DeepSkyTheme.radiusLg),
        border: Border.all(color: tokens.cardBorder.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            key: const Key('toggle-server-drawer-button'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 54),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DeepSkyTheme.spaceMd,
                  vertical: 12,
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tokens.surfaceHigh,
                        border: Border.all(
                          color: tokens.cardBorder.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(
                        Icons.dns_outlined,
                        size: 18,
                        color: tokens.warmGlow,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            s.serverLabel,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 12,
                                  color: tokens.accentText,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _expanded
                              ? s.closeDrawerAction
                              : s.customizeServerAction,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: tokens.mutedInk),
                        ),
                        const SizedBox(width: 2),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            Icons.expand_more,
                            size: 18,
                            color: tokens.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded)
            Container(
              padding: const EdgeInsets.fromLTRB(
                DeepSkyTheme.spaceMd,
                10,
                DeepSkyTheme.spaceMd,
                DeepSkyTheme.spaceMd,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: tokens.cardBorder.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    s.serverDrawerDescription,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontSize: 12, color: tokens.mutedInk),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.customServerFieldLabel,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: tokens.mutedInk),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          key: const Key('onboarding-server-field'),
                          controller: widget.serverController,
                          enabled: !widget.busy,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurface),
                          decoration: InputDecoration(
                            hintText: s.customServerFieldHint,
                            hintStyle: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: tokens.mutedInk.withValues(alpha: 0.6),
                                ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _handleSave(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: const Key('save-server-button'),
                        onPressed: widget.busy ? null : _handleSave,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(64, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(s.saveButton),
                      ),
                    ],
                  ),
                  if (_validationError != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      _validationError!,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.error),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          s.serverSyncNote,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: tokens.mutedInk.withValues(alpha: 0.78),
                              ),
                        ),
                      ),
                      if (widget.isCustomServer)
                        TextButton(
                          key: const Key('reset-server-button'),
                          onPressed: widget.busy
                              ? null
                              : () async {
                                  widget.serverController.text =
                                      widget.defaultServerUrl;
                                  setState(() => _validationError = null);
                                  await widget.onResetOfficial();
                                  if (mounted) {
                                    setState(() => _expanded = false);
                                  }
                                },
                          child: Text(s.resetOfficialServerButton),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
