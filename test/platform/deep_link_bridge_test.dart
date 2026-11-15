import 'package:deep_sky/platform/native_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NativeBridge consumes initial deep link and listens for hot deep links', () async {
    const MethodChannel channel = MethodChannel(NativeBridge.channelName);
    const String sampleUri =
        'https://deepsky.vectevo.com/join#server=https%3A%2F%2Fcasa.test&token=t-123';

    String? pending = sampleUri;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'consumePendingDeepLink') {
            final String? out = pending;
            pending = null;
            return out;
          }
          return null;
        });

    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    const NativeBridge bridge = NativeBridge();
    final List<String> received = <String>[];
    bridge.setDeepLinkListener(received.add);

    expect(await bridge.consumePendingDeepLink(), sampleUri);
    expect(await bridge.consumePendingDeepLink(), isNull);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          NativeBridge.channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onDeepLink', 'deepsky://pair#token=hot-456'),
          ),
          (_) {},
        );
    expect(received, <String>['deepsky://pair#token=hot-456']);
  });
}
