import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/data/apk_update_service.dart';
import 'package:deep_sky/domain/platform_capabilities.dart';
import 'package:deep_sky/domain/update/apk_update_models.dart';
import 'package:deep_sky/platform/native_bridge.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

/// Diagnostic harness for SP-03 self-update checks, Ed25519 manifest verification,
/// REQUEST_INSTALL_PACKAGES permission flow, and error scenarios (TC-10, F-19).
class Sp03PrototypePage extends StatefulWidget {
  const Sp03PrototypePage({
    super.key,
    this.nativeBridge = const NativeBridge(),
    this.httpClient,
  });

  final NativeBridge nativeBridge;
  final http.Client? httpClient;

  @override
  State<Sp03PrototypePage> createState() => _Sp03PrototypePageState();
}

class _Sp03PrototypePageState extends State<Sp03PrototypePage> {
  final TextEditingController _sourceController = TextEditingController(
    text: 'Manuel-Materazzo/deep_sky',
  );
  final TextEditingController _tagController = TextEditingController(
    text: 'latest',
  );
  final TextEditingController _pubKeyController = TextEditingController();

  PlatformCapabilities? _caps;
  bool _canInstall = false;
  ApkReleaseManifest? _verifiedManifest;
  String _status = 'Ready to check APK updates.';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshNativeState();
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _tagController.dispose();
    _pubKeyController.dispose();
    super.dispose();
  }

  ApkUpdateService _service() => ApkUpdateService(
    httpClient: widget.httpClient,
    nativeBridge: widget.nativeBridge,
  );

  Future<void> _refreshNativeState() async {
    try {
      final PlatformCapabilities caps = await widget.nativeBridge
          .getPlatformCapabilities();
      final bool canInstall = await widget.nativeBridge
          .canRequestPackageInstalls();
      if (!mounted) {
        return;
      }
      setState(() {
        _caps = caps;
        _canInstall = canInstall;
      });
    } catch (_) {
      // Widget tests without a mocked MethodChannel ignore startup query.
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() => _busy = true);
    try {
      final PlatformCapabilities caps =
          _caps ?? await widget.nativeBridge.getPlatformCapabilities();
      final SimplePublicKey pubKey = ApkUpdateService.parseEd25519PublicKey(
        _pubKeyController.text,
      );
      final Uri baseUri = ApkUpdateService.resolveSourceBaseUri(
        _sourceController.text,
        tag: _tagController.text.trim().isEmpty
            ? 'latest'
            : _tagController.text.trim(),
      );
      final ApkReleaseManifest manifest = await _service()
          .fetchAndVerifyManifest(
            sourceBaseUri: baseUri,
            trustedPublicKey: pubKey,
            currentApp: caps,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _verifiedManifest = manifest;
        _status =
            'Verified manifest v${manifest.versionName} (${manifest.versionCode}) '
            'from $baseUri';
      });
    } on ApkUpdateException catch (ex) {
      if (mounted) {
        setState(() {
          _verifiedManifest = null;
          _status = ex.friendlyMessage;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'Errore: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _downloadAndInstall() async {
    final ApkReleaseManifest? manifest = _verifiedManifest;
    if (manifest == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final Uri baseUri = ApkUpdateService.resolveSourceBaseUri(
        _sourceController.text,
        tag: _tagController.text.trim().isEmpty
            ? 'latest'
            : _tagController.text.trim(),
      );
      final UpdateStorageInfo storage = await widget.nativeBridge
          .getUpdateStorageInfo();
      final File apkFile = await _service().downloadAndVerifyApk(
        sourceBaseUri: baseUri,
        manifest: manifest,
        stagingDir: storage.stagingDir,
        availableBytes: storage.availableBytes,
      );
      final String sessionResult = await _service().installApkFile(apkFile);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Install session submitted ($sessionResult).';
      });
    } on ApkUpdateException catch (ex) {
      if (mounted) {
        setState(() => _status = ex.friendlyMessage);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'Errore installazione: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SP-03 · APK Self-Updater')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(_status, key: const Key('sp03-status')),
              const SizedBox(height: 8),
              if (_caps != null)
                Text(
                  'Installed: ${_caps!.packageName} v${_caps!.versionName} (${_caps!.versionCode}) · Permission: $_canInstall',
                ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('sp03-source'),
                controller: _sourceController,
                decoration: const InputDecoration(
                  labelText: 'Release Repo (owner/repo) or custom URL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('sp03-tag'),
                controller: _tagController,
                decoration: const InputDecoration(
                  labelText: 'Release tag ("latest" or tag)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('sp03-pubkey'),
                controller: _pubKeyController,
                decoration: const InputDecoration(
                  labelText: 'Ed25519 Manifest Public Key (Base64)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('sp03-check-btn'),
                onPressed: _busy ? null : _checkForUpdate,
                child: const Text('1. Check & Verify Signed Manifest'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                key: const Key('sp03-install-btn'),
                onPressed: _busy || _verifiedManifest == null
                    ? null
                    : _downloadAndInstall,
                child: const Text('2. Download (SHA-256) & Install APK'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('sp03-permission-btn'),
                onPressed: _busy
                    ? null
                    : () async {
                        await widget.nativeBridge
                            .openInstallPermissionSettings();
                        await _refreshNativeState();
                      },
                child: const Text('Open "Install Unknown Apps" Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
