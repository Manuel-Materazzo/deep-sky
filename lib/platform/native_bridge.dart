import 'package:deep_sky/domain/platform_capabilities.dart';
import 'package:deep_sky/domain/update/apk_update_models.dart';
import 'package:flutter/services.dart';

/// Bridge to Android native capabilities (installer, widgets, runtime FCM)
/// over a single structured MethodChannel (APP-02, TC-01).
class NativeBridge {
  const NativeBridge([this._channel = const MethodChannel(channelName)]);

  static const String channelName = 'com.vectevo.deep_sky/platform';

  final MethodChannel _channel;

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

  Future<bool> canRequestPackageInstalls() async {
    final bool? granted = await _channel.invokeMethod<bool>(
      'canRequestPackageInstalls',
    );
    return granted ?? false;
  }

  Future<void> openInstallPermissionSettings() async {
    await _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

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
}
