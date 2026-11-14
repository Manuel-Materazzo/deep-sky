import 'package:deep_sky/domain/platform_capabilities.dart';
import 'package:deep_sky/platform/native_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(NativeBridge.channelName);
  const NativeBridge bridge = NativeBridge();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('ping returns pong from native platform channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'ping') {
            return 'pong';
          }
          return null;
        });

    expect(await bridge.ping(), 'pong');
  });

  test('getPlatformCapabilities maps native Android metadata', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'getPlatformCapabilities') {
            return <String, Object>{
              'packageName': 'com.vectevo.deep_sky',
              'androidApiLevel': 35,
              'versionName': '1.0.0',
              'versionCode': 1,
              'supportsRequestInstallPackages': true,
            };
          }
          return null;
        });

    final PlatformCapabilities caps = await bridge.getPlatformCapabilities();
    expect(caps.packageName, 'com.vectevo.deep_sky');
    expect(caps.androidApiLevel, 35);
    expect(caps.versionName, '1.0.0');
    expect(caps.versionCode, 1);
    expect(caps.supportsRequestInstallPackages, isTrue);
  });

  test('throws PlatformException when native channel returns null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async => null);

    expect(bridge.ping(), throwsA(isA<PlatformException>()));
  });
}
