import 'package:deep_sky/domain/push_models.dart';
import 'package:deep_sky/domain/update/apk_update_models.dart';
import 'package:deep_sky/presentation/deep_sky_controller.dart';
import 'package:deep_sky/presentation/l10n/deep_sky_strings.dart';
import 'package:deep_sky/presentation/theme/deep_sky_theme.dart';
import 'package:deep_sky/scene/local_scene_view_state.dart';
import 'package:material_ui/material_ui.dart';

/// Dedicated Settings screen reachable from the single top-right header action (`S2-D05`, `S2-D09`).
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final DeepSkyController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _deviceLabelController =
      TextEditingController(
        text:
            widget.controller.identity?.deviceLabel ??
            widget.controller.deviceLabel,
      );
  late final TextEditingController _updateSourceController =
      TextEditingController(text: widget.controller.defaultUpdateSource);
  late final TextEditingController _updateKeyController = TextEditingController(
    text: widget.controller.trustedUpdatePublicKeyB64,
  );

  @override
  void dispose() {
    _deviceLabelController.dispose();
    _updateSourceController.dispose();
    _updateKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final DeepSkyController c = widget.controller;
        final DeepSkyStrings s = DeepSkyStrings(c.languageCode);
        final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
        final NativePushStatus? push = c.pushStatus;
        final ApkReleaseManifest? manifest = c.availableUpdate;

        return Scaffold(
          key: const Key('settings-page'),
          appBar: AppBar(
            leading: IconButton(
              key: const Key('settings-back-button'),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: Text(s.settingsTab),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        s.settingsProfileCardTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.settingsProfileCardSubtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('settings-device-label-field'),
                        controller: _deviceLabelController,
                        maxLength: 64,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: s.spaceSetupInputLabel,
                          counterText: '',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.tonalIcon(
                        key: const Key('settings-save-device-label-button'),
                        onPressed: c.busy || c.isOffline || c.isDeviceRevoked
                            ? null
                            : () => c.updateDeviceLabelFromSettings(
                                _deviceLabelController.text,
                              ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(s.settingsSaveNameButton),
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
                        s.settingsPrefsTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<SkyTimePreference>(
                        key: const Key('sky-preference-selector'),
                        initialValue: c.localSceneViewState.skyPreference,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: s.skyPreferenceLabel,
                          border: const OutlineInputBorder(),
                        ),
                        items: <DropdownMenuItem<SkyTimePreference>>[
                          for (final SkyTimePreference pref
                              in SkyTimePreference.values)
                            DropdownMenuItem<SkyTimePreference>(
                              value: pref,
                              child: Text(
                                pref.localizedLabel(c.languageCode),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (SkyTimePreference? pref) {
                          if (pref != null) {
                            c.setSkyPreference(pref);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.settingsNightMode),
                        value: c.isNight,
                        onChanged: (_) => c.toggleNightMode(),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.settingsReduceMotion),
                        value: c.reduceMotion,
                        onChanged: (_) => c.toggleReduceMotion(),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        key: const Key('settings-language-selector'),
                        initialValue: c.languageCode,
                        decoration: InputDecoration(
                          labelText: s.settingsLanguageLabel,
                          border: const OutlineInputBorder(),
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
                key: const Key('settings-graphics-card'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        s.settingsGraphicsTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.settingsGraphicsActiveVersion(
                          c.activePackVersion,
                          c.activePackIsFileSystem,
                        ),
                        key: const Key('active-graphics-pack-version'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 10),
                      FilledButton.tonalIcon(
                        key: const Key('force-update-graphics-button'),
                        onPressed:
                            c.busy ||
                                c.contentPackUpdating ||
                                c.isOffline ||
                                c.isDeviceRevoked
                            ? null
                            : c.forceUpdateContentPack,
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: Text(s.settingsGraphicsUpdateButton),
                      ),
                      if (c.contentPackUpdating) ...<Widget>[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(),
                      ],
                      if (c.contentPackFeedback != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          c.contentPackFeedback!,
                          key: const Key('graphics-update-feedback'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.calmAccent),
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        s.settingsPushTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        push != null && push.firebaseInitialized
                            ? s.settingsPushActiveCount(push.receivedCount)
                            : s.settingsPushInactive,
                      ),
                      if (push != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          push.hasNotificationPermission
                              ? s.settingsPushPermissionGranted
                              : s.settingsPushPermissionMissing,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: push.hasNotificationPermission
                                    ? tokens.mutedInk
                                    : Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      FilledButton.tonalIcon(
                        key: const Key('enable-push-button'),
                        onPressed: c.busy || c.isOffline || c.isDeviceRevoked
                            ? null
                            : c.enableRuntimePush,
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: Text(s.settingsPushEnableButton),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const Key('open-notification-settings-button'),
                        onPressed: c.busy ? null : c.openNotificationSettings,
                        icon: const Icon(Icons.settings_applications_outlined),
                        label: Text(s.settingsOpenNotificationSettingsButton),
                      ),
                      if (c.busy) ...<Widget>[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(),
                      ],
                      if (c.pushFeedback != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          c.pushFeedback!,
                          key: const Key('push-feedback-text'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: c.pushFeedbackIsError
                                    ? Theme.of(context).colorScheme.error
                                    : tokens.calmAccent,
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        s.settingsUpdatesTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.settingsVersionLine(
                          c.capabilities.versionName,
                          c.capabilities.versionCode,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<UpdateChannel>(
                        key: const Key('update-channel-selector'),
                        initialValue: c.updateChannel,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: s.updateChannelLabel,
                          border: const OutlineInputBorder(),
                        ),
                        items: <DropdownMenuItem<UpdateChannel>>[
                          for (final UpdateChannel ch in UpdateChannel.values)
                            DropdownMenuItem<UpdateChannel>(
                              value: ch,
                              child: Text(
                                ch.localizedLabel(c.languageCode),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: c.busy
                            ? null
                            : (UpdateChannel? ch) {
                                if (ch != null) {
                                  c.setUpdateChannel(ch);
                                }
                              },
                      ),
                      const SizedBox(height: 8),
                      ExpansionTile(
                        key: const Key('advanced-update-options-tile'),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(
                          top: 8,
                          bottom: 8,
                        ),
                        title: Text(
                          s.advancedUpdateOptionsLabel,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        children: <Widget>[
                          SwitchListTile(
                            key: const Key('allow-custom-update-anchor-switch'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(s.allowCustomUpdateAnchorLabel),
                            subtitle: Text(s.allowCustomUpdateAnchorHint),
                            value: c.allowCustomUpdateTrustAnchor,
                            onChanged: c.busy
                                ? null
                                : c.setAllowCustomUpdateTrustAnchor,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _updateSourceController,
                            enabled: c.allowCustomUpdateTrustAnchor && !c.busy,
                            decoration: InputDecoration(
                              labelText: s.updateSourceFieldLabel,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _updateKeyController,
                            enabled: c.allowCustomUpdateTrustAnchor && !c.busy,
                            decoration: InputDecoration(
                              labelText: s.updatePublicKeyFieldLabel,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
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
                      if (c.updateDownloadProgress != null) ...<Widget>[
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: c.updateDownloadProgress,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.updateDownloadProgress(
                            (c.updateDownloadProgress! * 100).round(),
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
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
          ),
        );
      },
    );
  }
}
