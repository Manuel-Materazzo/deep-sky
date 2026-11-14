import 'package:deep_sky/domain/platform_capabilities.dart';
import 'package:deep_sky/domain/push_models.dart';
import 'package:deep_sky/domain/update/apk_update_models.dart';
import 'package:flutter/services.dart';

/// Bridge to Android native capabilities (installer, widgets, runtime FCM)
/// over a single structured MethodChannel (APP-02, TC-01).
class NativeBridge {
  const NativeBridge([this._channel = const MethodChannel(channelName)]);

  static const String channelName = 'com.vectevo.deep_sky/platform';

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
    final String? token = await _channel.invokeMethod<String>(
      'configureRuntimePush',
      config.toChannelArgs(),
    );
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
    final bool? granted = await _channel.invokeMethod<bool>(
      'requestNotificationPermission',
    );
    return granted ?? false;
  }
}
