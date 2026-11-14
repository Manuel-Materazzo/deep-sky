import 'package:deep_sky/data/push_api_client.dart';
import 'package:deep_sky/domain/push_models.dart';
import 'package:deep_sky/platform/native_bridge.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

/// Diagnostic harness for SP-01 two-device FCM runtime config and background delivery verification.
class Sp01PrototypePage extends StatefulWidget {
  const Sp01PrototypePage({
    super.key,
    this.nativeBridge = const NativeBridge(),
    this.httpClient,
  });

  final NativeBridge nativeBridge;
  final http.Client? httpClient;

  @override
  State<Sp01PrototypePage> createState() => _Sp01PrototypePageState();
}

class _Sp01PrototypePageState extends State<Sp01PrototypePage> {
  final TextEditingController _serverUrlController = TextEditingController(
    text: 'http://10.0.2.2:8080',
  );
  final TextEditingController _deviceIdController = TextEditingController(
    text: 'device-a',
  );
  final TextEditingController _coupleIdController = TextEditingController(
    text: 'couple-sp01',
  );
  final TextEditingController _targetDeviceController = TextEditingController(
    text: 'device-b',
  );

  final TextEditingController _projectIdController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _appIdController = TextEditingController();
  final TextEditingController _senderIdController = TextEditingController();

  String _selectedL10nKey = 'wakeup.new_moment';
  String _statusMessage = 'Ready for SP-01 verification.';
  bool _busy = false;
  NativePushStatus? _nativeStatus;
  String? _activeToken;

  @override
  void initState() {
    super.initState();
    _refreshNativeStatus();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _deviceIdController.dispose();
    _coupleIdController.dispose();
    _targetDeviceController.dispose();
    _projectIdController.dispose();
    _apiKeyController.dispose();
    _appIdController.dispose();
    _senderIdController.dispose();
    super.dispose();
  }

  PushApiClient _apiClient() => PushApiClient(
    baseUrl: _serverUrlController.text,
    httpClient: widget.httpClient,
  );

  Future<void> _runGuarded(Future<void> Function() action) async {
    setState(() {
      _busy = true;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _refreshNativeStatus() async {
    try {
      final NativePushStatus status = await widget.nativeBridge.getPushStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _nativeStatus = status;
        if (status.lastKnownToken.isNotEmpty) {
          _activeToken = status.lastKnownToken;
        }
      });
    } catch (_) {
      // Widget tests without a mocked native channel ignore initial auto-refresh.
    }
  }

  Future<void> _fetchServerConfig() async {
    await _runGuarded(() async {
      final RuntimeFirebaseConfig config = await _apiClient()
          .fetchRuntimeConfig();
      if (!mounted) {
        return;
      }
      setState(() {
        _projectIdController.text = config.projectId;
        _apiKeyController.text = config.apiKey;
        _appIdController.text = config.appId;
        _senderIdController.text = config.senderId;
        _statusMessage = config.enabled
            ? 'Fetched runtime Firebase options for ${config.projectId}.'
            : 'Server reported firebase.enabled=false; fill options manually or configure DEEPSKY_FIREBASE_*.';
      });
    });
  }

  Future<void> _initAndRegister() async {
    await _runGuarded(() async {
      final bool granted = await widget.nativeBridge
          .requestNotificationPermission();
      final RuntimeFirebaseConfig config = RuntimeFirebaseConfig(
        enabled: true,
        projectId: _projectIdController.text,
        apiKey: _apiKeyController.text,
        appId: _appIdController.text,
        senderId: _senderIdController.text,
      );
      if (!config.isComplete) {
        setState(() {
          _statusMessage =
              'Complete projectId, apiKey, appId, and senderId first.';
        });
        return;
      }

      final String token = await widget.nativeBridge.configureRuntimePush(
        config,
      );
      await _apiClient().registerToken(
        deviceId: _deviceIdController.text,
        coupleId: _coupleIdController.text,
        fcmToken: token,
      );
      final NativePushStatus status = await widget.nativeBridge.getPushStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _activeToken = token;
        _nativeStatus = status;
        _statusMessage =
            'Firebase initialized & token registered (permissionGranted=$granted).';
      });
    });
  }

  Future<void> _syncRotatedToken() async {
    await _runGuarded(() async {
      final String? rotated = await widget.nativeBridge
          .consumePendingPushToken();
      if (rotated == null) {
        setState(() {
          _statusMessage = 'No pending rotated token in native storage.';
        });
        return;
      }
      await _apiClient().registerToken(
        deviceId: _deviceIdController.text,
        coupleId: _coupleIdController.text,
        fcmToken: rotated,
      );
      final NativePushStatus status = await widget.nativeBridge.getPushStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _activeToken = rotated;
        _nativeStatus = status;
        _statusMessage = 'Synced rotated token to server.';
      });
    });
  }

  Future<void> _sendWakeup({required bool toTargetDevice}) async {
    await _runGuarded(() async {
      final PushWakeupOutcome outcome = await _apiClient().sendTestWakeup(
        deviceId: toTargetDevice ? _targetDeviceController.text : null,
        coupleId: toTargetDevice ? null : _coupleIdController.text,
        localizationKey: _selectedL10nKey,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage =
            'Wakeup "${outcome.localizationKey}": attempted=${outcome.attempted}, '
            'delivered=${outcome.delivered}, evicted=${outcome.unregisteredRemoved}.';
      });
    });
  }

  Future<void> _clearNativeConfig() async {
    await _runGuarded(() async {
      await widget.nativeBridge.clearRuntimePushConfig();
      final NativePushStatus status = await widget.nativeBridge.getPushStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _activeToken = null;
        _nativeStatus = status;
        _statusMessage = 'Cleared local runtime Firebase config.';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final NativePushStatus? status = _nativeStatus;
    return Scaffold(
      appBar: AppBar(title: const Text('SP-01 · Runtime FCM Push')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                _statusMessage,
                key: const Key('sp01-status-banner'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('sp01-server-url'),
                controller: _serverUrlController,
                decoration: const InputDecoration(
                  labelText: 'Server Base URL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      key: const Key('sp01-device-id'),
                      controller: _deviceIdController,
                      decoration: const InputDecoration(
                        labelText: 'This Device ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const Key('sp01-couple-id'),
                      controller: _coupleIdController,
                      decoration: const InputDecoration(
                        labelText: 'Couple ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                key: const Key('sp01-fetch-config'),
                onPressed: _busy ? null : _fetchServerConfig,
                child: const Text('1. Fetch Runtime Config from Server'),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('sp01-project-id'),
                controller: _projectIdController,
                decoration: const InputDecoration(
                  labelText: 'Firebase Project ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('sp01-api-key'),
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Firebase API Key',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('sp01-app-id'),
                controller: _appIdController,
                decoration: const InputDecoration(
                  labelText: 'Firebase App ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('sp01-sender-id'),
                controller: _senderIdController,
                decoration: const InputDecoration(
                  labelText: 'GCM Sender ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('sp01-init-register'),
                onPressed: _busy ? null : _initAndRegister,
                child: const Text('2. Init Runtime Firebase & Register Token'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('sp01-sync-pending'),
                onPressed: _busy ? null : _syncRotatedToken,
                child: const Text('3. Flush Pending Rotated Token'),
              ),
              const Divider(height: 24),
              TextField(
                key: const Key('sp01-target-device'),
                controller: _targetDeviceController,
                decoration: const InputDecoration(
                  labelText: 'Target Device ID (partner phone)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedL10nKey,
                decoration: const InputDecoration(
                  labelText: 'Generic Wakeup l10nKey (S-02)',
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(
                    value: 'wakeup.new_moment',
                    child: Text('wakeup.new_moment'),
                  ),
                  DropdownMenuItem(
                    value: 'wakeup.capsule_ready',
                    child: Text('wakeup.capsule_ready'),
                  ),
                  DropdownMenuItem(
                    value: 'wakeup.daily_prompt',
                    child: Text('wakeup.daily_prompt'),
                  ),
                  DropdownMenuItem(
                    value: 'wakeup.generic',
                    child: Text('wakeup.generic'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (String? value) {
                        if (value != null) {
                          setState(() {
                            _selectedL10nKey = value;
                          });
                        }
                      },
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      key: const Key('sp01-send-target'),
                      onPressed: _busy
                          ? null
                          : () => _sendWakeup(toTargetDevice: true),
                      child: const Text('Send to Target'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      key: const Key('sp01-send-couple'),
                      onPressed: _busy
                          ? null
                          : () => _sendWakeup(toTargetDevice: false),
                      child: const Text('Send to Couple'),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Native Diagnostics',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text('Configured: ${status?.configured ?? false}'),
                      Text(
                        'Firebase initialized: ${status?.firebaseInitialized ?? false}',
                      ),
                      Text(
                        'Permission granted: ${status?.hasNotificationPermission ?? false}',
                      ),
                      Text('Received count: ${status?.receivedCount ?? 0}'),
                      Text('Last wakeup key: ${status?.lastWakeupKey ?? "-"}'),
                      Text(
                        'Active token prefix: ${_activeToken != null && _activeToken!.isNotEmpty ? _activeToken!.substring(0, _activeToken!.length < 12 ? _activeToken!.length : 12) : "-"}',
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          TextButton(
                            key: const Key('sp01-refresh-status'),
                            onPressed: _busy ? null : _refreshNativeStatus,
                            child: const Text('Refresh Status'),
                          ),
                          TextButton(
                            key: const Key('sp01-clear-config'),
                            onPressed: _busy ? null : _clearNativeConfig,
                            child: const Text('Clear Native Config'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
