import 'package:deep_sky/data/couple_api_client.dart';
import 'package:deep_sky/data/pairing_and_sync_repository.dart';
import 'package:deep_sky/presentation/deep_sky_controller.dart';
import 'package:deep_sky/presentation/l10n/deep_sky_strings.dart';
import 'package:deep_sky/presentation/theme/deep_sky_theme.dart';
import 'package:deep_sky/presentation/widgets/invite_verification_section.dart';
import 'package:material_ui/material_ui.dart';

/// DS-2 onboarding screen supporting couple creation (`F-01`), invite joining
/// with SAS verification, and 24-word/QR recovery (`F-20`).
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.controller});

  final DeepSkyController controller;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final TextEditingController _serverController = TextEditingController(
    text: widget.controller.defaultServerUrl,
  );
  final TextEditingController _labelController = TextEditingController(
    text: 'Telefono principale',
  );
  final TextEditingController _inviteTokenController = TextEditingController();
  final TextEditingController _recoveryController = TextEditingController();

  int _modeIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.controller.pendingJoin != null) {
      _modeIndex = 1;
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _labelController.dispose();
    _inviteTokenController.dispose();
    _recoveryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DeepSkyController c = widget.controller;
    final DeepSkyStrings s = DeepSkyStrings(c.languageCode);
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);

    return Scaffold(
      key: const Key('onboarding-page'),
      appBar: AppBar(title: Text(s.appTitle), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Icon(
              Icons.nights_stay_outlined,
              size: 48,
              color: tokens.calmAccent,
            ),
            const SizedBox(height: 12),
            Text(
              s.ourHomeTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              s.calmSubtitle,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: tokens.mutedInk),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SegmentedButton<int>(
              segments: <ButtonSegment<int>>[
                ButtonSegment<int>(
                  value: 0,
                  label: Text(s.createSpaceTab),
                  icon: const Icon(Icons.home_outlined),
                ),
                ButtonSegment<int>(
                  value: 1,
                  label: Text(s.joinSpaceTab),
                  icon: const Icon(Icons.link),
                ),
                ButtonSegment<int>(
                  value: 2,
                  label: Text(s.recoverSpaceTab),
                  icon: const Icon(Icons.key_outlined),
                ),
              ],
              selected: <int>{_modeIndex},
              onSelectionChanged: (Set<int> next) {
                setState(() => _modeIndex = next.first);
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      key: const Key('onboarding-server-field'),
                      controller: _serverController,
                      decoration: const InputDecoration(
                        labelText: 'Server della coppia (HTTPS)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('onboarding-label-field'),
                      controller: _labelController,
                      decoration: const InputDecoration(
                        labelText: 'Nome di questo telefono',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_modeIndex == 0) _buildCreateSection(c),
                    if (_modeIndex == 1) _buildJoinSection(c),
                    if (_modeIndex == 2) _buildRecoverSection(c),
                    if (c.statusNotice != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        c.statusNotice!,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: tokens.calmAccent),
                      ),
                    ],
                    if (c.errorNotice != null) ...<Widget>[
                      const SizedBox(height: 12),
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
          ],
        ),
      ),
    );
  }

  Widget _buildCreateSection(DeepSkyController c) {
    final CreateInviteResponse? invite = c.activeInvite;
    if (invite == null) {
      return FilledButton.icon(
        key: const Key('create-invite-button'),
        onPressed: c.busy
            ? null
            : () => c.createInitialInvite(
                serverUrl: _serverController.text,
                deviceLabel: _labelController.text,
              ),
        icon: const Icon(Icons.add_home_outlined),
        label: const Text('Crea invito per il partner'),
      );
    }

    return InviteVerificationSection(
      invite: invite,
      serverUrl: _serverController.text,
      sasCode: c.activeSasCode,
      acceptedDeviceLabel: c.activeInviteStatus?.acceptedLabel,
      busy: c.busy,
      onPoll: c.pollActiveInvite,
      onConfirmSas: c.confirmSasAndDeliverRootKey,
    );
  }

  Widget _buildJoinSection(DeepSkyController c) {
    final PendingJoinSession? pending = c.pendingJoin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          key: const Key('join-token-field'),
          controller: _inviteTokenController,
          decoration: const InputDecoration(
            labelText: 'Codice o link invito',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (pending == null)
          FilledButton.icon(
            key: const Key('accept-invite-button'),
            onPressed: c.busy
                ? null
                : () => c.acceptInvite(
                    serverUrl: _serverController.text,
                    inviteToken: _inviteTokenController.text,
                    deviceLabel: _labelController.text,
                  ),
            icon: const Icon(Icons.link),
            label: const Text('Unisciti con invito'),
          )
        else ...<Widget>[
          Text(
            'Conferma con ${pending.peerLabel} il codice SAS: ${pending.sasCode}',
            key: const Key('joiner-sas-code'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Chiedi a ${pending.peerLabel} di premere "Verifica" e poi "Il codice coincide" prima di completare qui.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('complete-join-button'),
            onPressed: c.busy ? null : c.completeJoinDelivery,
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Completa ricezione chiavi'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: c.busy ? null : c.cancelPendingJoin,
            child: const Text('Usa un altro codice'),
          ),
        ],
      ],
    );
  }

  Widget _buildRecoverSection(DeepSkyController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          key: const Key('recovery-words-field'),
          controller: _recoveryController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '24 parole o payload QR della Recovery Key',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('recover-space-button'),
          onPressed: c.busy
              ? null
              : () => c.recoverWithKey(
                  serverUrl: _serverController.text,
                  recoveryInput: _recoveryController.text,
                  deviceLabel: _labelController.text,
                ),
          icon: const Icon(Icons.key),
          label: const Text('Recupera il vostro spazio'),
        ),
      ],
    );
  }
}
