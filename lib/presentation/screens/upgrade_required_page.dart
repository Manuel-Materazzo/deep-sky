import 'package:deep_sky/domain/update/apk_update_models.dart';
import 'package:deep_sky/presentation/deep_sky_controller.dart';
import 'package:deep_sky/presentation/l10n/deep_sky_strings.dart';
import 'package:deep_sky/presentation/theme/deep_sky_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Non-alarming blocking screen when the backend returns HTTP 426 (`F-19`, `V-08`).
class UpgradeRequiredPage extends StatefulWidget {
  const UpgradeRequiredPage({super.key, required this.controller});

  final DeepSkyController controller;

  @override
  State<UpgradeRequiredPage> createState() => _UpgradeRequiredPageState();
}

class _UpgradeRequiredPageState extends State<UpgradeRequiredPage> {
  late final TextEditingController _sourceController = TextEditingController(
    text: widget.controller.defaultUpdateSource,
  );
  late final TextEditingController _keyController = TextEditingController(
    text: widget.controller.trustedUpdatePublicKeyB64,
  );

  @override
  void dispose() {
    _sourceController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DeepSkyController c = widget.controller;
    final DeepSkyStrings s = DeepSkyStrings(c.languageCode);
    final DeepSkyTokens tokens = DeepSkyTheme.tokensOf(context);
    final ApkReleaseManifest? manifest = c.availableUpdate;

    return Scaffold(
      key: const Key('upgrade-required-page'),
      appBar: AppBar(title: Text(s.appTitle), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.system_update_outlined,
                      size: 40,
                      color: tokens.calmAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.upgradeRequiredTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(s.upgradeRequiredBody),
                    const SizedBox(height: 12),
                    Text(
                      s.upgradeVersionSummary(
                        c.capabilities.versionName,
                        c.capabilities.versionCode,
                        c.compatibilityPolicy?.minClientVersionCode,
                      ),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: tokens.mutedInk),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<UpdateChannel>(
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: _sourceController,
                      decoration: InputDecoration(
                        labelText: s.updateSourceFieldLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _keyController,
                      decoration: InputDecoration(
                        labelText: s.updatePublicKeyFieldLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('upgrade-check-button'),
                      onPressed: c.busy
                          ? null
                          : () => c.checkForUpdates(
                              source: _sourceController.text,
                              trustedKeyB64: _keyController.text,
                            ),
                      icon: const Icon(Icons.refresh),
                      label: Text(s.checkUpdatesButton),
                    ),
                    if (manifest != null) ...<Widget>[
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        key: const Key('upgrade-install-button'),
                        onPressed: c.busy
                            ? null
                            : () => c.downloadAndInstallUpdate(
                                source: _sourceController.text,
                              ),
                        icon: const Icon(Icons.download_for_offline_outlined),
                        label: Text(
                          '${s.installUpdateButton} (${manifest.versionName})',
                        ),
                      ),
                    ],
                    if (c.updateDownloadProgress != null) ...<Widget>[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: c.updateDownloadProgress),
                      const SizedBox(height: 4),
                      Text(
                        s.updateDownloadProgress(
                          (c.updateDownloadProgress! * 100).round(),
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (c.updateFeedback != null || c.errorNotice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          c.updateFeedback ?? c.errorNotice ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
