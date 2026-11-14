import 'dart:typed_data';

import 'package:deep_sky/data/couple_api_client.dart';
import 'package:deep_sky/data/encrypted_local_cache.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';
import 'package:deep_sky/domain/crypto/recovery_key_codec.dart';
import 'package:deep_sky/domain/push_models.dart';
import 'package:deep_sky/domain/update/apk_update_models.dart';
import 'package:deep_sky/presentation/deep_sky_controller.dart';
import 'package:deep_sky/presentation/l10n/deep_sky_strings.dart';
import 'package:deep_sky/presentation/theme/deep_sky_theme.dart';
import 'package:deep_sky/scene/hybrid_scene_canvas.dart';
import 'package:deep_sky/scene/scene_manifest.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Authenticated couple space shell with Hybrid Home (`F-02`, `F-03`),
/// paired Devices & Recovery management (`F-20`, `S-03`), and Settings (`SP-01`, `F-19`).
class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key, required this.controller});

  final DeepSkyController controller;

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  final TextEditingController _noteController = TextEditingController();
  late final TextEditingController _updateSourceController =
      TextEditingController(text: widget.controller.defaultUpdateSource);
  late final TextEditingController _updateKeyController = TextEditingController(
    text: widget.controller.trustedUpdatePublicKeyB64,
  );

  int _navIndex = 0;
  bool _recoveryCheckbox = false;

  @override
  void dispose() {
    _noteController.dispose();
    _updateSourceController.dispose();
    _updateKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DeepSkyController c = widget.controller;
    final DeepSkyStrings s = DeepSkyStrings(c.languageCode);
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);

    return Scaffold(
      key: const Key('home-shell-page'),
      appBar: AppBar(
        title: Text(s.appTitle),
        actions: <Widget>[
          IconButton(
            key: const Key('refresh-sync-button'),
            tooltip: s.syncNow,
            onPressed: c.busy ? null : c.refreshSync,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (c.isOffline)
            Material(
              key: const Key('offline-readonly-banner'),
              color: tokens.offlineBannerSurface,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
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
            ),
          Expanded(
            child: IndexedStack(
              index: _navIndex,
              children: <Widget>[
                _buildHomeTab(context, c, s, tokens),
                _buildDevicesTab(context, c),
                _buildSettingsTab(context, c, s),
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
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: s.homeTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.devices_outlined),
            selectedIcon: const Icon(Icons.devices),
            label: s.devicesTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune_outlined),
            selectedIcon: const Icon(Icons.tune),
            label: s.settingsTab,
          ),
        ],
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
    final bool canWrite = !c.busy && !c.isOffline && id.recoverySavedConfirmed;

    final String statusHeadline;
    final String? statusNote;
    if (c.sceneState.windowLit && c.sceneState.latestThought != null) {
      statusHeadline = c.sceneState.fromPartner
          ? s.incomingThoughtBanner
          : s.thoughtSentConfirmation;
      final Object? rawNote = c.sceneState.latestThought!.payload.body['note'];
      statusNote = rawNote is String && rawNote.isNotEmpty ? rawNote : null;
    } else {
      statusHeadline = s.ourHomeTitle;
      statusNote = s.calmSubtitle;
    }

    return SingleChildScrollView(
      key: const Key('home-feed-scroll'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!id.recoverySavedConfirmed && id.recoverySeed != null)
            _buildRecoveryGateCard(context, c, s, id.recoverySeed!),
          Card(
            key: const Key('ds2-status-card'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        c.sceneState.windowLit
                            ? Icons.wb_twilight
                            : Icons.nights_stay_outlined,
                        color: c.sceneState.windowLit
                            ? tokens.warmGlow
                            : tokens.calmAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          statusHeadline,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  if (statusNote != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      statusNote,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: tokens.mutedInk),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (c.sceneManifest != null)
            HybridSceneCanvas(
              key: const Key('ds2-scene-canvas'),
              manifest: c.sceneManifest!,
              packAssetRoot: DeepSkyController.pilotAssetRoot,
              isNight: c.isNight,
              reduceMotion: c.reduceMotion,
              slotStates: c.sceneState.slotStates,
              overrides: c.assetOverrides,
              languageCode: c.languageCode,
              onSlotTapped: (SceneSlot slot) {
                if (slot.id == 'pet') {
                  c.togglePetOverride();
                } else if (slot.id == 'window') {
                  c.toggleNightMode();
                }
              },
            ),
          const SizedBox(height: 12),
          Card(
            key: const Key('ds2-thought-action-card'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextField(
                    key: const Key('thought-note-field'),
                    controller: _noteController,
                    enabled: canWrite,
                    maxLength: 140,
                    decoration: InputDecoration(
                      labelText: s.thoughtNoteHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('send-thought-button'),
                    onPressed: canWrite
                        ? () async {
                            final String note = _noteController.text;
                            await c.sendThinkingOfYou(note: note);
                            if (c.errorNotice == null) {
                              _noteController.clear();
                            }
                          }
                        : null,
                    icon: const Icon(Icons.favorite_border),
                    label: Text(s.sendThoughtLabel),
                  ),
                  if (c.statusNotice != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      c.statusNotice!,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: tokens.calmAccent),
                    ),
                  ],
                  if (c.errorNotice != null) ...<Widget>[
                    const SizedBox(height: 8),
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
                    c.languageCode == 'it'
                        ? 'Momenti recenti (${c.events.length})'
                        : 'Recent gestures (${c.events.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (c.events.isEmpty)
                    Text(
                      c.languageCode == 'it'
                          ? 'Ancora nessun gesto registrato.'
                          : 'No gestures saved yet.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: tokens.mutedInk),
                    )
                  else
                    for (final CachedEventEntry entry in c.events.reversed.take(
                      8,
                    ))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '• ${entry.payload.eventType}'
                          '${entry.payload.body['note'] != null ? ' — ${entry.payload.body['note']}' : ''}',
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryGateCard(
    BuildContext context,
    DeepSkyController c,
    DeepSkyStrings s,
    Uint8List seed,
  ) {
    final String sentence = RecoveryKeyCodec.toSentence(seed);
    final String qrPayload = RecoveryKeyCodec.toQrPayload(seed);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        key: const Key('recovery-gate-card'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                s.saveRecoveryFirstHint,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SelectableText(
                sentence,
                key: const Key('recovery-24-words'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(6),
                  child: QrImageView(data: qrPayload, size: 110),
                ),
              ),
              CheckboxListTile(
                key: const Key('recovery-saved-checkbox'),
                contentPadding: EdgeInsets.zero,
                value: _recoveryCheckbox,
                onChanged: (bool? v) =>
                    setState(() => _recoveryCheckbox = v ?? false),
                title: Text(s.confirmRecoveryCheckbox),
              ),
              FilledButton(
                key: const Key('confirm-recovery-button'),
                onPressed: (!c.busy && !c.isOffline && _recoveryCheckbox)
                    ? c.confirmRecoveryKeySaved
                    : null,
                child: Text(s.confirmRecoveryButton),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevicesTab(BuildContext context, DeepSkyController c) {
    final LocalDeviceIdentity id = c.identity!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Questo dispositivo: ${id.deviceLabel}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('ID coppia: ${id.coupleId}'),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: c.busy || c.isOffline
                      ? null
                      : c.createEnrollmentInvite,
                  icon: const Icon(Icons.devices),
                  label: const Text('Aggiungi un altro telefono'),
                ),
                if (c.activeInvite != null) ...<Widget>[
                  const SizedBox(height: 8),
                  SelectableText(
                    'Invito nuovo telefono: ${c.activeInvite!.inviteToken}',
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
                  'Dispositivi collegati (${c.devices.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                for (final DeviceSummary dev in c.devices)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(dev.label),
                    subtitle: Text(
                      dev.revokedAt != null ? 'Revocato' : 'Attivo',
                    ),
                    trailing:
                        (dev.deviceId != id.deviceId && dev.revokedAt == null)
                        ? TextButton(
                            onPressed: c.busy || c.isOffline
                                ? null
                                : () => c.revokeDevice(dev.deviceId),
                            child: const Text('Revoca'),
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('unpair-couple-button'),
          onPressed: c.busy || c.isOffline ? null : c.unpairCouple,
          icon: const Icon(Icons.link_off),
          label: const Text('Scollega dispositivo e pulisci spazio locale'),
        ),
      ],
    );
  }

  Widget _buildSettingsTab(
    BuildContext context,
    DeepSkyController c,
    DeepSkyStrings s,
  ) {
    final NativePushStatus? push = c.pushStatus;
    final ApkReleaseManifest? manifest = c.availableUpdate;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Preferenze stanza e lingua',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Atmosfera notturna'),
                  value: c.isNight,
                  onChanged: (_) => c.toggleNightMode(),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Riduci movimento'),
                  value: c.reduceMotion,
                  onChanged: (_) => c.toggleReduceMotion(),
                ),
                DropdownButtonFormField<String>(
                  initialValue: c.languageCode,
                  decoration: const InputDecoration(
                    labelText: 'Lingua / Language',
                    border: OutlineInputBorder(),
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'it',
                      child: Text('Italiano'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'en',
                      child: Text('English'),
                    ),
                  ],
                  onChanged: (String? v) {
                    if (v != null) {
                      c.setLanguageCode(v);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Notifiche push discrete (FCM runtime)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  push != null && push.firebaseInitialized
                      ? 'Attive (risvegli ricevuti: ${push.receivedCount})'
                      : 'Non configurate su questo dispositivo.',
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  key: const Key('enable-push-button'),
                  onPressed: c.busy || c.isOffline ? null : c.enableRuntimePush,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Attiva notifiche su questo telefono'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Aggiornamenti app (APK firmato offline)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Versione: ${c.capabilities.versionName} (${c.capabilities.versionCode})',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _updateSourceController,
                  decoration: const InputDecoration(
                    labelText: 'Repository GitHub o URL release',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _updateKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Chiave pubblica Ed25519 (base64)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: c.busy
                      ? null
                      : () => c.checkForUpdates(
                          source: _updateSourceController.text,
                          trustedKeyB64: _updateKeyController.text,
                        ),
                  icon: const Icon(Icons.system_update_outlined),
                  label: Text(s.checkUpdatesButton),
                ),
                if (manifest != null) ...<Widget>[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: c.busy
                        ? null
                        : () => c.downloadAndInstallUpdate(
                            source: _updateSourceController.text,
                          ),
                    icon: const Icon(Icons.download_outlined),
                    label: Text(
                      '${s.installUpdateButton} (${manifest.versionName})',
                    ),
                  ),
                ],
                if (c.updateFeedback != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(c.updateFeedback!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
