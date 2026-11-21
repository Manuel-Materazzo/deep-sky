import 'package:deep_sky/domain/platform_capabilities.dart';
import 'package:deep_sky/domain/push_models.dart';
import 'package:deep_sky/domain/update/apk_update_models.dart';
import 'package:flutter/services.dart';

/// Bridge to Android native capabilities (installer, widgets, runtime FCM)
/// over a single structured MethodChannel (APP-02, TC-01).
class NativeBridge {
  const NativeBridge([this._channel = const MethodChannel(channelName)]);

  static const String channelName = 'com.vectevo.deep_sky/platform';
  static final Map<MethodChannel, void Function(String uri)>
  _deepLinkListeners = <MethodChannel, void Function(String uri)>{};
  static final Map<MethodChannel, void Function(String l10nKey)>
  _pushWakeupListeners = <MethodChannel, void Function(String l10nKey)>{};

  final MethodChannel _channel;

  /// Verifies the Flutter <-> Kotlin channel responds as expected.
  Future<String> ping() async {
    final String? reply = await _channel.invokeMethod<String>('ping');
    if (reply == null) {
      throw PlatformException(
        code: 'null_reply',
        message: 'Native platform channel returned null for ping.',
      );
    }
    return reply;
  }

  /// Queries Android runtime metadata and install-permission support.
  Future<PlatformCapabilities> getPlatformCapabilities() async {
    final Map<Object?, Object?>? result = await _channel
        .invokeMethod<Map<Object?, Object?>>('getPlatformCapabilities');
    if (result == null) {
      throw PlatformException(
        code: 'null_reply',
        message: 'Native platform channel returned null for getPlatformCapabilities.',
      );
    }
    return PlatformCapabilities.fromMap(result);
  }

  /// Checks whether Android allows this app to launch the APK package installer.
  Future<bool> canRequestPackageInstalls() async {
    final bool? granted = await _channel.invokeMethod<bool>(
      'canRequestPackageInstalls',
    );
    return granted ?? false;
  }

  /// Opens the Android system settings screen to allow APK installs from this app.
  Future<void> openInstallPermissionSettings() async {
    await _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

  /// Returns app-private staging directory and available storage bytes for APK downloads.
  Future<UpdateStorageInfo> getUpdateStorageInfo() async {
    final Map<Object?, Object?>? result = await _channel
        .invokeMethod<Map<Object?, Object?>>('getUpdateStorageInfo');
    if (result == null) {
      throw PlatformException(
        code: 'null_reply',
        message:
            'Native platform channel returned null for getUpdateStorageInfo.',
      );
    }
    return UpdateStorageInfo.fromMap(result);
  }

  /// Verifies and commits an Android PackageInstaller session for [apkPath].
  Future<String> installVerifiedApk(String apkPath) async {
    final String? status = await _channel.invokeMethod<String>(
      'installVerifiedApk',
      <String, String>{'apkPath': apkPath},
    );
    if (status == null) {
      throw PlatformException(
        code: 'null_reply',
        message:
            'Native platform channel returned null for installVerifiedApk.',
      );
    }
    return status;
  }

  /// Initializes Android FirebaseApp at runtime and returns the active FCM token (SP-01).
  Future<String> configureRuntimePush(RuntimeFirebaseConfig config) async {
    final String? token = await _channel
        .invokeMethod<String>('configureRuntimePush', config.toChannelArgs())
        .timeout(const Duration(seconds: 20));
    if (token == null || token.isEmpty) {
      throw PlatformException(
        code: 'null_reply',
        message: 'Native platform channel returned null/empty FCM registration token.',
      );
    }
    return token;
  }

  /// Reads persisted runtime Firebase state and local wakeup diagnostics (SP-01).
  Future<NativePushStatus> getPushStatus() async {
    final Map<Object?, Object?>? result = await _channel
        .invokeMethod<Map<Object?, Object?>>('getPushStatus');
    if (result == null) {
      throw PlatformException(
        code: 'null_reply',
        message: 'Native platform channel returned null for getPushStatus.',
      );
    }
    return NativePushStatus.fromMap(result);
  }

  /// Returns and clears any rotated FCM token captured by FirebaseMessagingService.onNewToken.
  Future<String?> consumePendingPushToken() async {
    final String? token = await _channel.invokeMethod<String>(
      'consumePendingPushToken',
    );
    if (token == null || token.isEmpty) {
      return null;
    }
    return token;
  }

  /// Clears stored runtime Firebase configuration from native preferences.
  Future<void> clearRuntimePushConfig() async {
    await _channel.invokeMethod<void>('clearRuntimePushConfig');
  }

  /// Requests Android 13+ POST_NOTIFICATIONS runtime permission when needed.
  Future<bool> requestNotificationPermission() async {
    final bool? granted = await _channel
        .invokeMethod<bool>('requestNotificationPermission')
        .timeout(const Duration(seconds: 25));
    return granted ?? false;
  }

  /// Opens the Android system notification settings screen for Deep Sky.
  Future<bool> openNotificationSettings() async {
    try {
      final bool? opened = await _channel.invokeMethod<bool>(
        'openNotificationSettings',
      );
      return opened ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the native Android share sheet with [text] and optional [subject].
  ///
  /// Returns `false` when unavailable (e.g. headless tests or desktop hosts).
  Future<bool> shareText({required String text, String? subject}) async {
    try {
      final bool? launched = await _channel.invokeMethod<bool>(
        'shareText',
        <String, Object?>{
          'text': text,
          if (subject != null && subject.isNotEmpty) 'subject': subject,
        },
      );
      return launched ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the native CameraX QR code scanner (`S1-D06`, `S1-D10`) and returns
  /// the decoded text, or `null` if cancelled or unsupported on this platform.
  ///
  /// Propagates [PlatformException] for explicit camera permission denials or
  /// hardware failures so the UI can display a calm localized hint.
  Future<String?> scanQrCode({
    String? title,
    String? hint,
    String? cancelLabel,
  }) async {
    try {
      final String? payload = await _channel.invokeMethod<String>(
        'scanQrCode',
        <String, Object?>{
          if (title != null && title.isNotEmpty) 'title': title,
          if (hint != null && hint.isNotEmpty) 'hint': hint,
          if (cancelLabel != null && cancelLabel.isNotEmpty)
            'cancelLabel': cancelLabel,
        },
      );
      if (payload == null || payload.trim().isEmpty) {
        return null;
      }
      return payload.trim();
    } on MissingPluginException {
      return null;
    }
  }

  /// Registers a listener for deep-link invite URIs arriving while the app is open (`S1-APP-01`).
  void setDeepLinkListener(void Function(String uri)? listener) {
    if (listener == null) {
      _deepLinkListeners.remove(_channel);
    } else {
      _deepLinkListeners[_channel] = listener;
    }
    _syncChannelHandler();
  }

  /// Registers a listener for foreground FCM wakeups forwarded from native Android (`AU-18`).
  void setPushWakeupListener(void Function(String l10nKey)? listener) {
    if (listener == null) {
      _pushWakeupListeners.remove(_channel);
    } else {
      _pushWakeupListeners[_channel] = listener;
    }
    _syncChannelHandler();
  }

  void _syncChannelHandler() {
    final bool hasDeepLink = _deepLinkListeners.containsKey(_channel);
    final bool hasWakeup = _pushWakeupListeners.containsKey(_channel);
    if (!hasDeepLink && !hasWakeup) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onDeepLink') {
        final String? uri = call.arguments as String?;
        final void Function(String)? cb = _deepLinkListeners[_channel];
        if (cb != null && uri != null && uri.trim().isNotEmpty) {
          cb(uri.trim());
        }
      } else if (call.method == 'onPushWakeup') {
        final String? key = call.arguments as String?;
        final void Function(String)? cb = _pushWakeupListeners[_channel];
        if (cb != null && key != null && key.trim().isNotEmpty) {
          cb(key.trim());
        }
      }
    });
  }

  /// Reads and clears any pending deep-link invite URI captured at app launch (`S1-APP-01`).
  Future<String?> consumePendingDeepLink() async {
    try {
      final String? uri = await _channel.invokeMethod<String>(
        'consumePendingDeepLink',
      );
      if (uri == null || uri.trim().isEmpty) {
        return null;
      }
      return uri.trim();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Enables or disables `FLAG_SECURE` on the host Android window (`CA-10`).
  Future<void> setSecureScreen(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setSecureScreen', <String, Object?>{
        'enabled': enabled,
      });
    } on MissingPluginException {
      // Desktop / headless widget tests run without Android platform channels.
    } on PlatformException {
      // Best-effort window protection.
    }
  }

  /// Copies [text] marked as sensitive (`EXTRA_IS_SENSITIVE`) and clears it
  /// from the Android clipboard after [clearAfterSeconds] (`CA-10`).
  Future<void> copySensitiveText(
    String text, {
    int clearAfterSeconds = 45,
  }) async {
    try {
      final bool? handled = await _channel.invokeMethod<bool>(
        'copySensitiveText',
        <String, Object?>{'text': text, 'clearAfterSeconds': clearAfterSeconds},
      );
      if (handled == true) {
        return;
      }
    } on MissingPluginException {
      // Fall back to standard Clipboard in headless tests / non-Android hosts.
    } on PlatformException {
      // Fall back to standard Clipboard if native helper fails.
    }
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Returns `true` when the active Android network is unmetered (e.g. Wi-Fi) (`S2-APP-02`).
  ///
  /// Defaults to `true` on desktop/headless hosts without Android platform channels.
  Future<bool> isConnectionUnmetered() async {
    try {
      final bool? unmetered = await _channel.invokeMethod<bool>(
        'isConnectionUnmetered',
      );
      return unmetered ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }

  /// Returns the app-private directory used for verified content packs (`S2-APP-02`, `AD-06`).
  Future<String?> getContentPackRootDir() async {
    try {
      final String? path = await _channel.invokeMethod<String>(
        'getContentPackRootDir',
      );
      if (path == null || path.trim().isEmpty) {
        return null;
      }
      return path.trim();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Returns the app-private directory used for the encrypted offline event cache (`AU-05`).
  Future<String?> getOfflineCacheRootDir() async {
    try {
      final String? path = await _channel.invokeMethod<String>(
        'getOfflineCacheRootDir',
      );
      if (path == null || path.trim().isEmpty) {
        return null;
      }
      return path.trim();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
