import 'dart:async';

import 'package:deep_sky/data/pairing_and_sync_repository.dart';
import 'package:deep_sky/domain/crypto/recovery_key_codec.dart';
import 'package:deep_sky/domain/pairing/invite_link_codec.dart';
import 'package:deep_sky/presentation/deep_sky_controller.dart';
import 'package:deep_sky/presentation/l10n/deep_sky_strings.dart';
import 'package:deep_sky/presentation/theme/deep_sky_theme.dart';
import 'package:deep_sky/presentation/widgets/welcome_invite_panel.dart';
import 'package:deep_sky/presentation/widgets/welcome_server_drawer.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Welcome & Onboarding screen (`S1-D02-D03-D05`) following the
/// "Intimate Sanctuary" design language.
///
/// Opens directly into automatic initial invite creation (`S1-D03`) and QR/link
/// sharing (`S1-D05`), while keeping `Unisciti` (`F-01`) and `Recupera` (`F-20`)
/// accessible via a segmented control and hiding server details in a
/// collapsed-by-default drawer (`P-09`).
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.controller});

  final DeepSkyController controller;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final TextEditingController _serverController = TextEditingController(
    text: widget.controller.activeServerUrl,
  );
  final TextEditingController _inviteTokenController = TextEditingController();
  final TextEditingController _recoveryController = TextEditingController();

  late int _modeIndex;

  @override
  void initState() {
    super.initState();
    _modeIndex = widget.controller.pendingJoin != null
        ? 1
        : widget.controller.onboardingTabIndex;
    widget.controller.addListener(_onControllerUpdated);
    _applyPendingDeepLinkIfAny(notifyUi: false);
    if (_modeIndex == 0 && widget.controller.pendingJoin == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (_modeIndex == 0 && widget.controller.pendingJoin == null) {
          unawaited(widget.controller.ensureInitialInvite());
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdated);
    _serverController.dispose();
    _inviteTokenController.dispose();
    _recoveryController.dispose();
    super.dispose();
  }

  void _onControllerUpdated() {
    _applyPendingDeepLinkIfAny(notifyUi: true);
  }

  void _applyPendingDeepLinkIfAny({required bool notifyUi}) {
    final String? rawDeepLink = widget.controller.takePendingDeepLinkInvite();
    if (rawDeepLink == null) {
      return;
    }
    _inviteTokenController.text = rawDeepLink;
    _serverController.text = widget.controller.activeServerUrl;
    if (notifyUi && mounted) {
      setState(() => _modeIndex = 1);
    } else {
      _modeIndex = 1;
    }
  }

  void _selectMode(int index) {
    if (_modeIndex == index) {
      return;
    }
    widget.controller.setOnboardingTabIndex(index);
    setState(() => _modeIndex = index);
    if (index == 0 &&
        widget.controller.activeInvite == null &&
        widget.controller.pendingJoin == null &&
        !widget.controller.busy) {
      unawaited(widget.controller.ensureInitialInvite());
    }
  }

  Future<void> _handleSaveServer(String normalizedUrl) async {
    await widget.controller.updateServerUrl(
      normalizedUrl,
      createInvite: _modeIndex == 0 && widget.controller.pendingJoin == null,
    );
    if (mounted) {
      _serverController.text = widget.controller.activeServerUrl;
    }
  }

  Future<void> _handleResetOfficialServer() async {
    await widget.controller.resetToOfficialServer(
      createInvite: _modeIndex == 0 && widget.controller.pendingJoin == null,
    );
    if (mounted) {
      _serverController.text = widget.controller.activeServerUrl;
    }
  }

  void _showHelpSheet(DeepSkyStrings s) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (BuildContext sheetContext) {
          final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(sheetContext);
          final TextTheme textTheme = Theme.of(sheetContext).textTheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(s.helpSheetTitle, style: textTheme.titleLarge),
                  const SizedBox(height: 16),
                  _HelpPointRow(
                    icon: Icons.favorite_outline_rounded,
                    accent: tokens.calmAccent,
                    title: s.helpPointSpaceTitle,
                    body: s.helpPointSpaceBody,
                  ),
                  const SizedBox(height: 14),
                  _HelpPointRow(
                    icon: Icons.qr_code_2_rounded,
                    accent: tokens.amberGlow,
                    title: s.helpPointPairingTitle,
                    body: s.helpPointPairingBody,
                  ),
                  const SizedBox(height: 14),
                  _HelpPointRow(
                    icon: Icons.lock_outline_rounded,
                    accent: tokens.blushPetal,
                    title: s.helpPointPrivacyTitle,
                    body: s.helpPointPrivacyBody,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPreferencesSheet() {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (BuildContext sheetContext) {
          return AnimatedBuilder(
            animation: widget.controller,
            builder: (BuildContext innerContext, _) {
              final DeepSkyController c = widget.controller;
              final DeepSkyStrings s = DeepSkyStrings(c.languageCode);
              final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(innerContext);
              final TextTheme textTheme = Theme.of(innerContext).textTheme;
              final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(
                innerContext,
              );

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    4,
                    24,
                    24 + viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        s.preferencesSheetTitle,
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        key: const Key('preferences-theme-switch'),
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(
                          c.isNight
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,
                          color: tokens.amberGlow,
                        ),
                        title: Text(s.nightThemeToggleLabel),
                        value: c.isNight,
                        onChanged: (_) => c.toggleNightMode(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.languageSelectorLabel,
                        style: textTheme.labelMedium?.copyWith(
                          color: tokens.mutedInk,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const <ButtonSegment<String>>[
                          ButtonSegment<String>(
                            value: 'it',
                            label: Text(
                              'Italiano',
                              key: Key('preferences-lang-it'),
                            ),
                          ),
                          ButtonSegment<String>(
                            value: 'en',
                            label: Text(
                              'English',
                              key: Key('preferences-lang-en'),
                            ),
                          ),
                        ],
                        selected: <String>{c.languageCode},
                        onSelectionChanged: (Set<String> selected) {
                          if (selected.isNotEmpty) {
                            c.setLanguageCode(selected.first);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DeepSkyController c = widget.controller;
    final DeepSkyStrings s = DeepSkyStrings(c.languageCode);
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      key: const Key('onboarding-page'),
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
                      tokens.elevatedSurface.withValues(alpha: 0.7),
                      tokens.skyBackdrop.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _WelcomeTopBar(
                        title: s.appTitle,
                        helpTooltip: s.helpButtonTooltip,
                        preferencesTooltip: s.preferencesTooltip,
                        onHelpPressed: () => _showHelpSheet(s),
                        onPreferencesPressed: _showPreferencesSheet,
                      ),
                      const SizedBox(height: 12),
                      _WelcomeHeroSection(
                        icon: switch (_modeIndex) {
                          1 => Icons.wb_twilight_rounded,
                          2 => Icons.vpn_key_rounded,
                          _ => Icons.cottage_rounded,
                        },
                        title: switch (_modeIndex) {
                          1 => s.joinTitle,
                          2 => s.recoverTitle,
                          _ => s.welcomeTitle,
                        },
                        subtitle: switch (_modeIndex) {
                          1 => s.joinSubtitle,
                          2 => s.recoverSubtitle,
                          _ => s.welcomeSubtitle,
                        },
                      ),
                      const SizedBox(height: 22),
                      _WelcomeModePill(
                        selectedIndex: _modeIndex,
                        inviteLabel: s.inviteTab,
                        joinLabel: s.joinSpaceTab,
                        recoverLabel: s.recoverSpaceTab,
                        onSelected: _selectMode,
                      ),
                      const SizedBox(height: 16),
                      _buildActivePanel(c, s, tokens, scheme, textTheme),
                      const SizedBox(height: 16),
                      WelcomeServerDrawer(
                        serverUrl: c.activeServerUrl,
                        defaultServerUrl: c.defaultServerUrl,
                        isCustomServer: c.isCustomServer,
                        busy: c.busy,
                        strings: s,
                        serverController: _serverController,
                        onSaveServer: _handleSaveServer,
                        onResetOfficial: _handleResetOfficialServer,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 14,
                            color: tokens.mutedInk,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              s.welcomeFooterNote,
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: tokens.mutedInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePanel(
    DeepSkyController c,
    DeepSkyStrings s,
    DeepSkyTokens tokens,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (_modeIndex == 0) {
      return WelcomeInvitePanel(controller: c, strings: s);
    }

    final Widget content = _modeIndex == 1
        ? _buildJoinSection(c, s, tokens, textTheme)
        : _buildRecoverSection(c, s);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.cardSurface,
        borderRadius: BorderRadius.circular(DeepSkyTheme.radiusXl),
        border: Border.all(color: tokens.cardBorder.withValues(alpha: 0.28)),
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
          content,
          if (c.statusNotice != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.surfaceHigh,
                borderRadius: BorderRadius.circular(DeepSkyTheme.radiusMd),
              ),
              child: Text(
                c.statusNotice!,
                style: textTheme.bodySmall?.copyWith(
                  color: tokens.accentText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (c.errorNotice != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(DeepSkyTheme.radiusMd),
              ),
              child: Text(
                c.errorNotice!,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _scanJoinQr(DeepSkyController c, DeepSkyStrings s) async {
    final String? scanned = await c.scanQrCode(
      title: s.scanQrTitle,
      hint: s.scanQrInviteHint,
      cancelLabel: s.cancel,
    );
    if (!mounted || scanned == null || scanned.isEmpty) {
      return;
    }
    _inviteTokenController.text = scanned;
    final parsed = InviteLinkCodec.parseInviteInput(scanned);
    if (parsed.serverUrl != null) {
      _serverController.text = parsed.serverUrl!;
    }
    await c.acceptInvite(
      serverUrl: _serverController.text,
      inviteToken: scanned,
      deviceLabel: c.deviceLabel,
    );
  }

  Future<void> _pasteJoinToken() async {
    final ClipboardData? clip = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = clip?.text?.trim();
    if (mounted && text != null && text.isNotEmpty) {
      _inviteTokenController.text = text;
    }
  }

  Future<void> _scanRecoveryQr(DeepSkyController c, DeepSkyStrings s) async {
    final String? scanned = await c.scanQrCode(
      title: s.scanQrTitle,
      hint: s.scanQrRecoveryHint,
      cancelLabel: s.cancel,
    );
    if (mounted && scanned != null && scanned.isNotEmpty) {
      _recoveryController.text = scanned;
    }
  }

  Future<void> _pasteRecoveryWords() async {
    final ClipboardData? clip = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = clip?.text?.trim();
    if (mounted && text != null && text.isNotEmpty) {
      _recoveryController.text = text;
    }
  }

  Widget _buildJoinSection(
    DeepSkyController c,
    DeepSkyStrings s,
    DeepSkyTokens tokens,
    TextTheme textTheme,
  ) {
    final PendingJoinSession? pending = c.pendingJoin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (pending == null) ...<Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.surfaceHigh.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(DeepSkyTheme.radiusLg),
              border: Border.all(
                color: tokens.cardBorder.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tokens.elevatedSurface,
                        borderRadius: BorderRadius.circular(
                          DeepSkyTheme.radiusMd,
                        ),
                      ),
                      child: Icon(
                        Icons.qr_code_scanner_rounded,
                        color: tokens.calmAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              Text(s.scanQrTitle, style: textTheme.titleMedium),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.scanQrDescription,
                            style: textTheme.bodySmall?.copyWith(
                              color: tokens.mutedInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  key: const Key('scan-invite-qr-button'),
                  onPressed: c.busy ? null : () => _scanJoinQr(c, s),
                  icon: const Icon(Icons.photo_camera_rounded, size: 19),
                  label: Text(s.openCameraButton),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: Divider(color: tokens.cardBorder.withValues(alpha: 0.4)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  s.orEnterManuallyDivider.toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(
                    color: tokens.mutedInk,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: tokens.cardBorder.withValues(alpha: 0.4)),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        TextField(
          key: const Key('join-token-field'),
          controller: _inviteTokenController,
          decoration: InputDecoration(
            labelText: s.isIt ? 'Codice o link invito' : 'Invite code or link',
            hintText: s.isIt
                ? 'Incolla il link ricevuto dal partner'
                : 'Paste the link sent by your partner',
            suffixIcon: IconButton(
              key: const Key('paste-invite-button'),
              tooltip: s.pasteButton,
              onPressed: c.busy ? null : _pasteJoinToken,
              icon: Icon(
                Icons.content_paste_rounded,
                size: 19,
                color: tokens.mutedInk,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (pending == null)
          FilledButton.icon(
            key: const Key('accept-invite-button'),
            onPressed: c.busy
                ? null
                : () => c.acceptInvite(
                    serverUrl: _serverController.text,
                    inviteToken: _inviteTokenController.text,
                    deviceLabel: c.deviceLabel,
                  ),
            icon: const Icon(Icons.link_rounded),
            label: Text(s.isIt ? 'Unisciti con invito' : 'Join with invite'),
          )
        else ...<Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.surfaceHigh,
              borderRadius: BorderRadius.circular(DeepSkyTheme.radiusMd),
              border: Border.all(
                color: tokens.calmAccent.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  s.isIt
                      ? 'Conferma con ${pending.peerLabel} il codice SAS: ${pending.sasCode}'
                      : 'Confirm SAS code with ${pending.peerLabel}: ${pending.sasCode}',
                  key: const Key('joiner-sas-code'),
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  s.isIt
                      ? 'Chiedi a ${pending.peerLabel} di premere "Verifica" e poi "Il codice coincide" prima di completare qui.'
                      : 'Ask ${pending.peerLabel} to verify and confirm the matching code before completing here.',
                  style: textTheme.bodySmall?.copyWith(color: tokens.mutedInk),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('complete-join-button'),
            onPressed: c.busy ? null : c.completeJoinDelivery,
            icon: const Icon(Icons.verified_outlined),
            label: Text(
              s.isIt ? 'Completa ricezione chiavi' : 'Complete key delivery',
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: c.busy ? null : c.cancelPendingJoin,
            child: Text(s.isIt ? 'Usa un altro codice' : 'Use another code'),
          ),
        ],
      ],
    );
  }

  Widget _buildRecoverSection(DeepSkyController c, DeepSkyStrings s) {
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    final ThemeData theme = Theme.of(context);
    final String rawInput = _recoveryController.text.trim();
    final bool isQrPayload = rawInput.startsWith(RecoveryKeyCodec.qrPrefix);
    final List<String> words = isQrPayload
        ? const <String>[]
        : RecoveryKeyCodec.tokenizeWords(rawInput);
    final int invalidCount = words
        .where((String w) => !RecoveryKeyCodec.isValidWord(w))
        .length;
    final int remaining = (24 - words.length).clamp(0, 24);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          s.recoverSectionSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(color: tokens.mutedInk),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              key: const Key('scan-recovery-qr-button'),
              onPressed: c.busy ? null : () => _scanRecoveryQr(c, s),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: Text(s.scanQrActionLabel),
            ),
            OutlinedButton.icon(
              key: const Key('paste-recovery-button'),
              onPressed: c.busy ? null : _pasteRecoveryWords,
              icon: const Icon(Icons.content_paste_rounded, size: 18),
              label: Text(s.pasteButton),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('recovery-words-field'),
          controller: _recoveryController,
          maxLines: 3,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: s.isIt
                ? '24 parole o payload QR della Recovery Key'
                : '24 recovery words or QR payload',
            hintText: s.recoverFieldPlaceholder,
          ),
        ),
        if (isQrPayload || words.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            key: const Key('recovery-word-chips-panel'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.surfaceLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (isQrPayload)
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.qr_code_2_rounded,
                        size: 18,
                        color: tokens.calmAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.isIt
                              ? 'Codice QR Recovery rilevato e pronto per il ripristino.'
                              : 'Recovery QR payload detected and ready to restore.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  )
                else ...<Widget>[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (int i = 0; i < words.length && i < 24; i++)
                        Builder(
                          builder: (BuildContext context) {
                            final bool valid = RecoveryKeyCodec.isValidWord(
                              words[i],
                            );
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: valid
                                    ? theme.colorScheme.surfaceContainerHigh
                                    : theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${i + 1}. ${words[i]}',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: valid
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    remaining > 0
                        ? s.recoverMissingWordsCounter(remaining)
                        : (invalidCount == 0
                              ? s.recoverWordsComplete
                              : '${words.length} / 24'),
                    key: const Key('recovery-word-count-status'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: (remaining == 0 && invalidCount == 0)
                          ? tokens.calmAccent
                          : tokens.mutedInk,
                    ),
                  ),
                  if (invalidCount > 0) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      s.recoverInvalidWordsHint(invalidCount),
                      key: const Key('recovery-invalid-words-hint'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const Key('recover-space-button'),
          onPressed: c.busy
              ? null
              : () => c.recoverWithKey(
                  serverUrl: _serverController.text,
                  recoveryInput: _recoveryController.text,
                  deviceLabel: c.deviceLabel,
                ),
          icon: const Icon(Icons.key_rounded),
          label: Text(s.recoverSubmitButton),
        ),
      ],
    );
  }
}

class _WelcomeTopBar extends StatelessWidget {
  const _WelcomeTopBar({
    required this.title,
    required this.helpTooltip,
    required this.preferencesTooltip,
    required this.onHelpPressed,
    required this.onPreferencesPressed,
  });

  final String title;
  final String helpTooltip;
  final String preferencesTooltip;
  final VoidCallback onHelpPressed;
  final VoidCallback onPreferencesPressed;

  @override
  Widget build(BuildContext context) {
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 52,
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.warmGlow.withValues(alpha: 0.14),
            ),
            child: Icon(
              Icons.nightlight_round,
              size: 19,
              color: tokens.warmGlow,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          IconButton(
            key: const Key('welcome-help-button'),
            tooltip: helpTooltip,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: onHelpPressed,
            icon: Icon(Icons.help_outline_rounded, color: tokens.mutedInk),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: preferencesTooltip,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('welcome-preferences-button'),
                borderRadius: BorderRadius.circular(22),
                onTap: onPreferencesPressed,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tokens.surfaceHigh,
                        border: Border.all(
                          color: tokens.calmAccent.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: tokens.accentText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeHeroSection extends StatelessWidget {
  const _WelcomeHeroSection({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      children: <Widget>[
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                tokens.warmGlow.withValues(alpha: 0.24),
                tokens.surfaceLow.withValues(alpha: 0.85),
              ],
            ),
            border: Border.all(color: tokens.amberGlow.withValues(alpha: 0.35)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: tokens.warmGlow.withValues(alpha: 0.16),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(child: Icon(icon, size: 36, color: tokens.amberGlow)),
        ),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: textTheme.displaySmall),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: tokens.mutedInk),
        ),
      ],
    );
  }
}

class _WelcomeModePill extends StatelessWidget {
  const _WelcomeModePill({
    required this.selectedIndex,
    required this.inviteLabel,
    required this.joinLabel,
    required this.recoverLabel,
    required this.onSelected,
  });

  final int selectedIndex;
  final String inviteLabel;
  final String joinLabel;
  final String recoverLabel;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: tokens.surfaceLow,
        borderRadius: BorderRadius.circular(DeepSkyTheme.radiusFull),
        border: Border.all(color: tokens.cardBorder.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: <Widget>[
          _ModePillTab(
            key: const Key('welcome-tab-invite'),
            icon: Icons.favorite_outline_rounded,
            label: inviteLabel,
            selected: selectedIndex == 0,
            onTap: () => onSelected(0),
          ),
          _ModePillTab(
            key: const Key('welcome-tab-join'),
            icon: Icons.login_rounded,
            label: joinLabel,
            selected: selectedIndex == 1,
            onTap: () => onSelected(1),
          ),
          _ModePillTab(
            key: const Key('welcome-tab-recover'),
            icon: Icons.sync_rounded,
            label: recoverLabel,
            selected: selectedIndex == 2,
            onTap: () => onSelected(2),
          ),
        ],
      ),
    );
  }
}

class _ModePillTab extends StatelessWidget {
  const _ModePillTab({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color foreground = selected
        ? scheme.onPrimaryContainer
        : tokens.mutedInk;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(DeepSkyTheme.radiusFull),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(DeepSkyTheme.radiusFull),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(icon, size: 15, color: foreground),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            color: foreground,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HelpPointRow extends StatelessWidget {
  const _HelpPointRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                body,
                style: textTheme.bodySmall?.copyWith(color: tokens.mutedInk),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
