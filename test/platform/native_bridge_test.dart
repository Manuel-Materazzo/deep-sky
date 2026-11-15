import 'package:deep_sky/domain/platform_capabilities.dart';
import 'package:deep_sky/domain/push_models.dart';
import 'package:deep_sky/domain/update/apk_update_models.dart';
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

  test(
    'configureRuntimePush passes Firebase options and returns token',
    () async {
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            captured = call;
            if (call.method == 'configureRuntimePush') {
              return 'fcm-runtime-token-123';
            }
            if (call.method == 'consumePendingPushToken') {
              return '';
            }
            if (call.method == 'requestNotificationPermission') {
              return true;
            }
            if (call.method == 'getPushStatus') {
              return <String, Object>{
                'configured': true,
                'firebaseInitialized': true,
                'projectId': 'deepsky-proto',
                'appId': '1:123:android:abc',
                'lastKnownToken': 'fcm-runtime-token-123',
                'pendingToken': '',
                'lastWakeupKey': 'wakeup.thinking_of_you',
                'lastWakeupEpochMs': 1763159000000,
                'receivedCount': 2,
                'hasNotificationPermission': true,
              };
            }
            return null;
          });

      const RuntimeFirebaseConfig config = RuntimeFirebaseConfig(
        enabled: true,
        projectId: 'deepsky-proto',
        apiKey: 'api-key',
        appId: '1:123:android:abc',
        senderId: '123',
      );

      final String token = await bridge.configureRuntimePush(config);
      expect(token, 'fcm-runtime-token-123');
      expect(captured?.arguments, <String, String>{
        'projectId': 'deepsky-proto',
        'apiKey': 'api-key',
        'appId': '1:123:android:abc',
        'senderId': '123',
      });

      final NativePushStatus status = await bridge.getPushStatus();
      expect(status.firebaseInitialized, isTrue);
      expect(status.receivedCount, 2);
      expect(status.lastWakeupKey, 'wakeup.thinking_of_you');

      expect(await bridge.consumePendingPushToken(), isNull);
      expect(await bridge.requestNotificationPermission(), isTrue);
    },
  );

  test(
    'installer bridge methods forward storage info and APK install path',
    () async {
      final List<MethodCall> calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            calls.add(call);
            switch (call.method) {
              case 'canRequestPackageInstalls':
                return true;
              case 'getUpdateStorageInfo':
                return <String, Object>{
                  'stagingDir': '/data/user/0/com.vectevo.deep_sky/files/apk',
                  'availableBytes': 123456789,
                };
              case 'installVerifiedApk':
                return 'session_committed:9';
              default:
                return null;
            }
          });

      expect(await bridge.canRequestPackageInstalls(), isTrue);
      final UpdateStorageInfo storage = await bridge.getUpdateStorageInfo();
      expect(storage.availableBytes, 123456789);
      expect(
        await bridge.installVerifiedApk('/tmp/update.apk'),
        'session_committed:9',
      );
      expect(calls.last.arguments, <String, String>{
        'apkPath': '/tmp/update.apk',
      });
    },
  );

  test('shareText sends text and subject and handles missing plugin', () async {
    expect(
      await bridge.shareText(
        text: 'https://deepsky.vectevo.com/join#token=abc',
      ),
      isFalse,
    );

    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          captured = call;
          if (call.method == 'shareText') {
            return true;
          }
          return null;
        });

    final bool launched = await bridge.shareText(
      text: 'https://deepsky.vectevo.com/join#token=abc',
      subject: 'Deep Sky',
    );
    expect(launched, isTrue);
    expect(captured?.arguments, <String, Object?>{
      'text': 'https://deepsky.vectevo.com/join#token=abc',
      'subject': 'Deep Sky',
    });
  });
}
