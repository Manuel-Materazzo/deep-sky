import 'package:deep_sky/domain/platform_capabilities.dart';
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
}
