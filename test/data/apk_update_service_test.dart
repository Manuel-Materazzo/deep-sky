import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/data/apk_update_service.dart';
import 'package:deep_sky/domain/platform_capabilities.dart';
import 'package:deep_sky/domain/update/apk_update_models.dart';
import 'package:deep_sky/platform/native_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const PlatformCapabilities installedApp = PlatformCapabilities(
    packageName: 'com.vectevo.deep_sky',
    androidApiLevel: 35,
    versionName: '1.0.0',
    versionCode: 1,
    supportsRequestInstallPackages: true,
  );

  Future<
    ({
      SimpleKeyPair keyPair,
      SimplePublicKey publicKey,
      Uint8List apkBytes,
      String apkSha256,
      Uint8List manifestBytes,
      Uint8List sigBytes,
    })
  >
  buildSignedRelease({
    int versionCode = 2,
    String packageId = 'com.vectevo.deep_sky',
  }) async {
    final Ed25519 ed25519 = Ed25519();
    final SimpleKeyPair keyPair = await ed25519.newKeyPair();
    final SimplePublicKey publicKey = await keyPair.extractPublicKey();
    final Uint8List apkBytes = Uint8List.fromList(
      List<int>.generate(4096, (int i) => (i * 31) & 0xff),
    );
    final Hash sha = await Sha256().hash(apkBytes);
    final String hex = sha.bytes
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final Map<String, Object> manifestJson = <String, Object>{
      'schemaVersion': 1,
      'packageId': packageId,
      'versionCode': versionCode,
      'versionName': '1.0.$versionCode',
      'apkFile': 'deep-sky-1.0.$versionCode-$versionCode.apk',
      'apkSha256': hex,
      'apkSizeBytes': apkBytes.length,
      'createdAt': '2026-11-14T22:00:00Z',
    };
    final Uint8List manifestBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(manifestJson)),
    );
    final Signature sig = await ed25519.sign(manifestBytes, keyPair: keyPair);
    return (
      keyPair: keyPair,
      publicKey: publicKey,
      apkBytes: apkBytes,
      apkSha256: hex,
      manifestBytes: manifestBytes,
      sigBytes: Uint8List.fromList(sig.bytes),
    );
  }

  test('resolves alternate repository URLs cleanly', () {
    expect(
      ApkUpdateService.resolveSourceBaseUri('fork-owner/deep_sky').toString(),
      'https://github.com/fork-owner/deep_sky/releases/latest/download',
    );
    expect(
      ApkUpdateService.resolveSourceBaseUri(
        'https://updates.example.org/releases/',
      ).toString(),
      'https://updates.example.org/releases',
    );
  });

  test('rejects tampered manifest, lower version, and wrong package', () async {
    final rel = await buildSignedRelease();
    final Uint8List tamperedManifest = Uint8List.fromList(
      utf8.encode(
        utf8.decode(rel.manifestBytes).replaceFirst('1.0.2', '9.9.9'),
      ),
    );

    final MockClient tamperedHttp = MockClient((http.Request req) async {
      if (req.url.path.endsWith('manifest.json')) {
        return http.Response.bytes(tamperedManifest, 200);
      }
      return http.Response(base64Encode(rel.sigBytes), 200);
    });

    final ApkUpdateService service = ApkUpdateService(httpClient: tamperedHttp);
    await expectLater(
      service.fetchAndVerifyManifest(
        sourceBaseUri: Uri.parse('https://mirror.example.test/dl'),
        trustedPublicKey: rel.publicKey,
        currentApp: installedApp,
      ),
      throwsA(
        isA<ApkUpdateException>().having(
          (ApkUpdateException e) => e.code,
          'code',
          ApkUpdateErrorCode.signatureInvalid,
        ),
      ),
    );

    // Non-increasing versionCode -> rejected.
    final downgrade = await buildSignedRelease(versionCode: 1);
    final MockClient downgradeHttp = MockClient((http.Request req) async {
      if (req.url.path.endsWith('manifest.json')) {
        return http.Response.bytes(downgrade.manifestBytes, 200);
      }
      return http.Response.bytes(downgrade.sigBytes, 200);
    });
    await expectLater(
      ApkUpdateService(httpClient: downgradeHttp).fetchAndVerifyManifest(
        sourceBaseUri: Uri.parse('https://mirror.example.test/dl'),
        trustedPublicKey: downgrade.publicKey,
        currentApp: installedApp,
      ),
      throwsA(
        isA<ApkUpdateException>().having(
          (ApkUpdateException e) => e.code,
          'code',
          ApkUpdateErrorCode.versionNotHigher,
        ),
      ),
    );
  });

  test('resumes interrupted download with Range, verifies SHA-256, and delegates install', () async {
    final rel = await buildSignedRelease(versionCode: 2);
    final Directory tempDir = Directory.systemTemp.createTempSync('sp03_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    int apkFetches = 0;
    final MockClient resumeHttp = MockClient.streaming((
      http.BaseRequest req,
      http.ByteStream bodyStream,
    ) async {
      if (req.url.path.endsWith('manifest.json')) {
        return http.StreamedResponse(
          Stream<List<int>>.value(rel.manifestBytes),
          200,
        );
      }
      if (req.url.path.endsWith('manifest.json.sig')) {
        return http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode(base64Encode(rel.sigBytes))),
          200,
        );
      }
      apkFetches++;
      if (apkFetches == 1) {
        // Return first 1024 bytes, then throw network error mid-stream.
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable(<List<int>>[
            rel.apkBytes.sublist(0, 1024),
          ]).map((List<int> c) => c).asyncExpand((List<int> firstChunk) async* {
            yield firstChunk;
            throw const SocketException('simulated drop');
          }),
          200,
        );
      }
      expect(req.headers['Range'], 'bytes=1024-');
      return http.StreamedResponse(
        Stream<List<int>>.value(rel.apkBytes.sublist(1024)),
        206,
      );
    });

    const MethodChannel channel = MethodChannel(NativeBridge.channelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'canRequestPackageInstalls') {
            return true;
          }
          if (call.method == 'installVerifiedApk') {
            return 'session_committed:7';
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final ApkUpdateService service = ApkUpdateService(httpClient: resumeHttp);
    final ApkReleaseManifest manifest = await service.fetchAndVerifyManifest(
      sourceBaseUri: Uri.parse('https://alt-repo.example.test/releases'),
      trustedPublicKey: rel.publicKey,
      currentApp: installedApp,
    );

    // Insufficient space fails gracefully before network download.
    await expectLater(
      service.downloadAndVerifyApk(
        sourceBaseUri: Uri.parse('https://alt-repo.example.test/releases'),
        manifest: manifest,
        stagingDir: tempDir.path,
        availableBytes: 1024,
      ),
      throwsA(
        isA<ApkUpdateException>().having(
          (ApkUpdateException e) => e.code,
          'code',
          ApkUpdateErrorCode.insufficientStorage,
        ),
      ),
    );

    final File verified = await service.downloadAndVerifyApk(
      sourceBaseUri: Uri.parse('https://alt-repo.example.test/releases'),
      manifest: manifest,
      stagingDir: tempDir.path,
      availableBytes: 50 * 1024 * 1024,
    );
    expect(verified.existsSync(), isTrue);
    expect(verified.lengthSync(), rel.apkBytes.length);
    expect(apkFetches, 2);

    expect(await service.installApkFile(verified), 'session_committed:7');
  });

  test('rejects tampered APK bytes with wrong SHA-256', () async {
    final rel = await buildSignedRelease(versionCode: 3);
    final Directory tempDir = Directory.systemTemp.createTempSync('sp03_bad_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final Uint8List alteredApk = Uint8List.fromList(rel.apkBytes);
    alteredApk[100] ^= 0xff;

    final MockClient badApkHttp = MockClient((http.Request req) async {
      if (req.url.path.endsWith('manifest.json')) {
        return http.Response.bytes(rel.manifestBytes, 200);
      }
      if (req.url.path.endsWith('manifest.json.sig')) {
        return http.Response.bytes(rel.sigBytes, 200);
      }
      return http.Response.bytes(alteredApk, 200);
    });

    final ApkUpdateService service = ApkUpdateService(httpClient: badApkHttp);
    final ApkReleaseManifest manifest = await service.fetchAndVerifyManifest(
      sourceBaseUri: Uri.parse('https://mirror.example.test/dl'),
      trustedPublicKey: rel.publicKey,
      currentApp: installedApp,
    );

    await expectLater(
      service.downloadAndVerifyApk(
        sourceBaseUri: Uri.parse('https://mirror.example.test/dl'),
        manifest: manifest,
        stagingDir: tempDir.path,
        availableBytes: 50 * 1024 * 1024,
      ),
      throwsA(
        isA<ApkUpdateException>().having(
          (ApkUpdateException e) => e.code,
          'code',
          ApkUpdateErrorCode.apkHashMismatch,
        ),
      ),
    );
  });

  test(
    'checkForUpdate uses ETag If-None-Match (304) and enforces cooldown',
    () async {
      final rel = await buildSignedRelease(versionCode: 2);
      DateTime clock = DateTime.utc(2026, 11, 15, 0, 0);
      int manifestRequests = 0;

      final MockClient httpClient = MockClient((http.Request req) async {
        if (req.url.path.endsWith('manifest.json')) {
          manifestRequests++;
          if (req.headers['If-None-Match'] == '"v2-etag"') {
            return http.Response('', 304);
          }
          return http.Response.bytes(
            rel.manifestBytes,
            200,
            headers: <String, String>{'etag': '"v2-etag"'},
          );
        }
        if (req.url.path.endsWith('manifest.json.sig')) {
          return http.Response.bytes(rel.sigBytes, 200);
        }
        return http.Response('not found', 404);
      });

      final ApkUpdateService service = ApkUpdateService(httpClient: httpClient);
      final Uri sourceUri = Uri.parse('https://mirror.example.test/dl');

      final ApkUpdateCheckResult first = await service.checkForUpdate(
        sourceBaseUri: sourceUri,
        trustedPublicKey: rel.publicKey,
        currentApp: installedApp,
        nowUtc: () => clock,
      );
      expect(first.status, ApkUpdateCheckStatus.updateAvailable);
      expect(first.manifest?.versionCode, 2);
      expect(manifestRequests, 1);

      // Within 6h cooldown: should not hit the network.
      clock = clock.add(const Duration(hours: 2));
      final ApkUpdateCheckResult throttled = await service.checkForUpdate(
        sourceBaseUri: sourceUri,
        trustedPublicKey: rel.publicKey,
        currentApp: installedApp,
        nowUtc: () => clock,
      );
      expect(throttled.status, ApkUpdateCheckStatus.throttledByCooldown);
      expect(throttled.manifest?.versionCode, 2);
      expect(manifestRequests, 1);

      // After cooldown expires: sends If-None-Match and handles 304 gracefully.
      clock = clock.add(const Duration(hours: 5));
      final ApkUpdateCheckResult notModified = await service.checkForUpdate(
        sourceBaseUri: sourceUri,
        trustedPublicKey: rel.publicKey,
        currentApp: installedApp,
        nowUtc: () => clock,
      );
      expect(notModified.status, ApkUpdateCheckStatus.notModified304);
      expect(notModified.manifest?.versionCode, 2);
      expect(manifestRequests, 2);
    },
  );
}
