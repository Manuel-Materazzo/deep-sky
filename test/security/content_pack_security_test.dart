import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/data/content_pack_service.dart';
import 'package:deep_sky/data/encrypted_local_cache.dart';
import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/domain/content/content_pack_models.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';
import 'package:deep_sky/presentation/deep_sky_controller.dart';
import 'package:deep_sky/scene/couple_room_snapshot.dart';
import 'package:deep_sky/scene/local_scene_view_state.dart';
import 'package:deep_sky/scene/scene_manifest.dart';
import 'package:deep_sky/scene/scene_state_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Security verification suite for S3-2 content pack supply chain and local-state privacy
/// (`S2-SEC-01`, `G5-07`, `TC-10`, `P-07`, `S-05`).
void main() {
  final Ed25519 ed25519 = Ed25519();

  Future<String> sha256Hex(List<int> bytes) async {
    final Hash h = await Sha256().hash(bytes);
    return h.bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<({Uint8List checksumsBytes, Uint8List sigBytes})> signPackPayload({
    required SimpleKeyPair keyPair,
    required String keyId,
    required String packId,
    required String packVersion,
    required Map<String, List<int>> files,
    int minAppProtocol = 1,
  }) async {
    final Map<String, Object?> fileMeta = <String, Object?>{};
    for (final MapEntry<String, List<int>> e in files.entries) {
      fileMeta[e.key] = <String, Object?>{
        'sha256': await sha256Hex(e.value),
        'sizeBytes': e.value.length,
      };
    }
    final Uint8List checksumsBytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'keyId': keyId,
          'packId': packId,
          'packVersion': packVersion,
          'minAppProtocol': minAppProtocol,
          'files': fileMeta,
        }),
      ),
    );
    final Signature sig = await ed25519.sign(checksumsBytes, keyPair: keyPair);
    final Uint8List sigBytes = Uint8List.fromList(
      utf8.encode('$keyId:${base64Encode(sig.bytes)}\n'),
    );
    return (checksumsBytes: checksumsBytes, sigBytes: sigBytes);
  }

  Map<String, List<int>> buildValidPackFiles({
    required String packVersion,
    List<int>? floorBytes,
  }) {
    final List<int> png =
        floorBytes ?? <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    final String manifest = jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'packId': 'deep-sky-home-v1',
      'packVersion': packVersion,
      'minAppProtocol': 1,
      'name': <String, String>{'it': 'Casa', 'en': 'Home'},
      'scene': <String, Object?>{
        'aspectRatio': '4:3',
        'bleed': <String, double>{'top': 0, 'bottom': 0, 'left': 0, 'right': 0},
        'background': <String, Object?>{'dayAsset': null, 'nightAsset': null},
      },
      'slots': <Object?>[
        <String, Object?>{
          'id': 'floor',
          'description': 'Floor',
          'zIndex': 5,
          'replaceable': false,
          'anchor': <String, double>{'x': 0.5, 'y': 0.56},
          'bounds': <String, double>{
            'x': 0.0,
            'y': 0.56,
            'width': 1.0,
            'height': 0.44,
          },
          'touchArea': <String, double>{
            'x': 0.0,
            'y': 0.56,
            'width': 1.0,
            'height': 0.44,
          },
          'accessibilityLabel': <String, String>{
            'it': 'Pavimento',
            'en': 'Floor',
          },
          'defaultState': 'default',
          'states': <String, Object?>{
            'default': <String, Object?>{
              'layers': <Object?>[
                <String, Object?>{
                  'id': 'parquet',
                  'asset': 'assets/floor.png',
                  'zOffset': 0,
                },
              ],
            },
          },
          'animations': <Object?>[],
        },
      ],
    });
    return <String, List<int>>{
      'manifest.json': utf8.encode(manifest),
      'assets/floor.png': png,
    };
  }

  SceneManifest bundledManifest() => const SceneManifest(
    schemaVersion: 1,
    packId: 'deep-sky-home-v1',
    packVersion: '1.0.0',
    minAppProtocol: 1,
    name: LocalizedText(it: 'Casa', en: 'Home'),
    aspectRatio: '4:3',
    slots: <SceneSlot>[],
  );

  test('G5-07: verifies Ed25519 signature on raw bytes BEFORE any JSON parsing and rejects unknown keyId', () async {
    final SimpleKeyPair kp = await ed25519.newKeyPair();
    final SimplePublicKey pub = await kp.extractPublicKey();
    final ContentPackService service = ContentPackService(
      keyStore: InMemorySecureKeyStore(),
      trustedPublicKeys: <String, SimplePublicKey>{'v1': pub},
    );

    // Adversarial non-JSON payload + invalid signature MUST fail with signatureInvalid (never JSON parse error)
    final Uint8List garbagePayload = Uint8List.fromList(
      utf8.encode('{{{not-json-at-all!!!'),
    );
    final Uint8List fakeSig = Uint8List.fromList(
      utf8.encode('v1:${base64Encode(List<int>.filled(64, 7))}\n'),
    );
    await expectLater(
      () => service.verifyAndParseChecksums(
        rawChecksumsBytes: garbagePayload,
        rawSignatureBytes: fakeSig,
      ),
      throwsA(
        isA<ContentPackException>().having(
          (ContentPackException e) => e.code,
          'code',
          ContentPackErrorCode.signatureInvalid,
        ),
      ),
    );

    // Unknown keyId MUST fail immediately with unknownKeyId before JSON parsing
    final Uint8List unknownKeySig = Uint8List.fromList(
      utf8.encode('v99:${base64Encode(List<int>.filled(64, 7))}\n'),
    );
    await expectLater(
      () => service.verifyAndParseChecksums(
        rawChecksumsBytes: garbagePayload,
        rawSignatureBytes: unknownKeySig,
      ),
      throwsA(
        isA<ContentPackException>().having(
          (ContentPackException e) => e.code,
          'code',
          ContentPackErrorCode.unknownKeyId,
        ),
      ),
    );
  });

  test('Rejects tampered checksums, path traversal, unsupported minAppProtocol, and mismatched PNG SHA-256', () async {
    final SimpleKeyPair kp = await ed25519.newKeyPair();
    final SimplePublicKey pub = await kp.extractPublicKey();
    final Directory tempRoot = Directory.systemTemp.createTempSync(
      'deepsky_sec_',
    );
    addTearDown(() => tempRoot.deleteSync(recursive: true));

    final Map<String, List<int>> files = buildValidPackFiles(
      packVersion: '1.1.0',
    );
    final signed = await signPackPayload(
      keyPair: kp,
      keyId: 'v1',
      packId: 'deep-sky-home-v1',
      packVersion: '1.1.0',
      files: files,
    );

    final ContentPackService service = ContentPackService(
      keyStore: InMemorySecureKeyStore(),
      trustedPublicKeys: <String, SimplePublicKey>{'v1': pub},
    );

    // Tampered checksums byte -> signatureInvalid
    final Uint8List tampered = Uint8List.fromList(signed.checksumsBytes);
    tampered[tampered.length - 2] ^= 0x01;
    await expectLater(
      () => service.verifyAndParseChecksums(
        rawChecksumsBytes: tampered,
        rawSignatureBytes: signed.sigBytes,
      ),
      throwsA(
        isA<ContentPackException>().having(
          (ContentPackException e) => e.code,
          'code',
          ContentPackErrorCode.signatureInvalid,
        ),
      ),
    );

    // Path traversal inside signed checksums -> pathTraversal
    for (final String badPath in <String>[
      '../escape.png',
      '/etc/passwd',
      r'assets\win.png',
      'assets/../../evil.png',
    ]) {
      final badSigned = await signPackPayload(
        keyPair: kp,
        keyId: 'v1',
        packId: 'deep-sky-home-v1',
        packVersion: '1.1.0',
        files: <String, List<int>>{
          'manifest.json': files['manifest.json']!,
          badPath: <int>[1, 2, 3],
        },
      );
      await expectLater(
        () => service.verifyAndParseChecksums(
          rawChecksumsBytes: badSigned.checksumsBytes,
          rawSignatureBytes: badSigned.sigBytes,
        ),
        throwsA(
          isA<ContentPackException>().having(
            (ContentPackException e) => e.code,
            'code',
            ContentPackErrorCode.pathTraversal,
          ),
        ),
      );
    }

    // Unsupported minAppProtocol -> protocolUnsupported
    final futureProto = await signPackPayload(
      keyPair: kp,
      keyId: 'v1',
      packId: 'deep-sky-home-v1',
      packVersion: '1.1.0',
      files: files,
      minAppProtocol: 9,
    );
    await expectLater(
      () => service.verifyAndParseChecksums(
        rawChecksumsBytes: futureProto.checksumsBytes,
        rawSignatureBytes: futureProto.sigBytes,
      ),
      throwsA(
        isA<ContentPackException>().having(
          (ContentPackException e) => e.code,
          'code',
          ContentPackErrorCode.protocolUnsupported,
        ),
      ),
    );

    // Single PNG with corrupted bytes during file-by-file download -> fileHashMismatch
    final ContentPackService downloadSvc = ContentPackService(
      keyStore: InMemorySecureKeyStore(),
      trustedPublicKeys: <String, SimplePublicKey>{'v1': pub},
      resolveStorageRootDir: () async => tempRoot.path,
      httpClient: MockClient((http.Request req) async {
        if (req.url.path == '/api/v1/content/pack/checksums') {
          return http.Response.bytes(signed.checksumsBytes, 200);
        }
        if (req.url.path == '/api/v1/content/pack/checksums.sig') {
          return http.Response.bytes(signed.sigBytes, 200);
        }
        if (req.url.path ==
            '/api/v1/content/pack/blobs/${await sha256Hex(files['manifest.json']!)}') {
          return http.Response.bytes(files['manifest.json']!, 200);
        }
        if (req.url.path ==
            '/api/v1/content/pack/blobs/${await sha256Hex(files['assets/floor.png']!)}') {
          return http.Response.bytes(<int>[
            0x89,
            0x50,
            0x4E,
            0x47,
            0xFF,
            0xFF,
            0xFF,
            0xFF,
          ], 200);
        }
        return http.Response('not found', 404);
      }),
    );

    await expectLater(
      () => downloadSvc.syncFromServer(
        serverBaseUrl: 'https://couple.example.test',
        bundledPackVersion: const SemanticVersion(1, 0, 0),
        currentActivePackVersion: const SemanticVersion(1, 0, 0),
        manualForce: true,
      ),
      throwsA(
        isA<ContentPackException>().having(
          (ContentPackException e) => e.code,
          'code',
          ContentPackErrorCode.fileHashMismatch,
        ),
      ),
    );
  });

  test('Enforces persistent anti-downgrade, file-by-file SHA-256 reuse, metered guard, and automatic rollback after >= 2 failed boots', () async {
    final SimpleKeyPair kpV1 = await ed25519.newKeyPair();
    final SimpleKeyPair kpV2 = await ed25519.newKeyPair();
    final Directory tempRoot = Directory.systemTemp.createTempSync(
      'deepsky_pack_flow_',
    );
    addTearDown(() => tempRoot.deleteSync(recursive: true));

    final InMemorySecureKeyStore keyStore = InMemorySecureKeyStore();
    final List<int> sharedFloorBytes = List<int>.generate(
      64,
      (int i) => (i * 7) & 0xFF,
    );
    final Map<String, List<int>> pack110 = buildValidPackFiles(
      packVersion: '1.1.0',
      floorBytes: sharedFloorBytes,
    );
    final Map<String, List<int>> pack120 = buildValidPackFiles(
      packVersion: '1.2.0',
      floorBytes: sharedFloorBytes,
    );
    final Map<String, List<int>> pack100 = buildValidPackFiles(
      packVersion: '1.0.0',
      floorBytes: sharedFloorBytes,
    );

    var servedFiles = pack110;
    var servedSigned = await signPackPayload(
      keyPair: kpV1,
      keyId: 'v1',
      packId: 'deep-sky-home-v1',
      packVersion: '1.1.0',
      files: pack110,
    );
    final List<String> fetchedFilePaths = <String>[];
    bool unmetered = false;

    final ContentPackService svc = ContentPackService(
      keyStore: keyStore,
      trustedPublicKeys: <String, SimplePublicKey>{
        'v1': await kpV1.extractPublicKey(),
        'v2': await kpV2.extractPublicKey(),
      },
      resolveStorageRootDir: () async => tempRoot.path,
      isConnectionUnmetered: () async => unmetered,
      httpClient: MockClient((http.Request req) async {
        if (req.url.path == '/api/v1/content/pack/checksums') {
          return http.Response.bytes(
            servedSigned.checksumsBytes,
            200,
            headers: const <String, String>{'etag': '"etag-1"'},
          );
        }
        if (req.url.path == '/api/v1/content/pack/checksums.sig') {
          return http.Response.bytes(servedSigned.sigBytes, 200);
        }
        const String prefix = '/api/v1/content/pack/blobs/';
        if (req.url.path.startsWith(prefix)) {
          final String hash = req.url.path.substring(prefix.length);
          for (final MapEntry<String, List<int>> f in servedFiles.entries) {
            if (await sha256Hex(f.value) == hash) {
              fetchedFilePaths.add(f.key);
              return http.Response.bytes(f.value, 200);
            }
          }
        }
        return http.Response('not found', 404);
      }),
    );

    // 1) Background sync skipped on metered network
    final ContentPackUpdateResult meteredRes = await svc.syncFromServer(
      serverBaseUrl: 'https://couple.example.test',
      bundledPackVersion: const SemanticVersion(1, 0, 0),
      currentActivePackVersion: const SemanticVersion(1, 0, 0),
      manualForce: false,
    );
    expect(meteredRes.status, ContentPackUpdateStatus.skippedMeteredNetwork);

    final Directory blobsDir = Directory('${tempRoot.path}/blobs')
      ..createSync(recursive: true);
    final File orphanBlobA = File('${blobsDir.path}/${'a' * 64}')
      ..writeAsBytesSync(<int>[1, 2, 3]);

    // 2) Manual force downloads & activates v1.1.0 immediately even on metered network
    final ContentPackUpdateResult hotRes = await svc.syncFromServer(
      serverBaseUrl: 'https://couple.example.test',
      bundledPackVersion: const SemanticVersion(1, 0, 0),
      currentActivePackVersion: const SemanticVersion(1, 0, 0),
      manualForce: true,
    );
    expect(hotRes.status, ContentPackUpdateStatus.activatedHotReload);
    expect(hotRes.packVersion, '1.1.0');
    expect(hotRes.downloadedFiles, 2);
    // Blob GC after manual promotion drops unreferenced blobs but keeps the active pack's files.
    expect(orphanBlobA.existsSync(), isFalse);
    expect(
      File('${blobsDir.path}/${await sha256Hex(pack110['assets/floor.png']!)}')
          .existsSync(),
      isTrue,
    );

    // 3) Key rotation to v2 + file-by-file reuse: upgrading to v1.2.0 reuses cached floor.png
    fetchedFilePaths.clear();
    unmetered = true;
    servedFiles = pack120;
    servedSigned = await signPackPayload(
      keyPair: kpV2,
      keyId: 'v2',
      packId: 'deep-sky-home-v1',
      packVersion: '1.2.0',
      files: pack120,
    );
    final ContentPackUpdateResult stagedRes = await svc.syncFromServer(
      serverBaseUrl: 'https://couple.example.test',
      bundledPackVersion: const SemanticVersion(1, 0, 0),
      currentActivePackVersion: const SemanticVersion(1, 1, 0),
      manualForce: false,
    );
    expect(stagedRes.status, ContentPackUpdateStatus.stagedForNextBoot);
    expect(stagedRes.downloadedFiles, 1); // Only manifest.json changed!
    expect(stagedRes.reusedCachedFiles, 1); // floor.png reused from blobs/!
    expect(fetchedFilePaths, <String>['manifest.json']);

    // 4) Downgrade to 1.0.0 rejected because localMaxSeen is 1.2.0 (and serverMin enforcement works)
    servedFiles = pack100;
    servedSigned = await signPackPayload(
      keyPair: kpV1,
      keyId: 'v1',
      packId: 'deep-sky-home-v1',
      packVersion: '1.0.0',
      files: pack100,
    );
    await expectLater(
      () => svc.syncFromServer(
        serverBaseUrl: 'https://couple.example.test',
        bundledPackVersion: const SemanticVersion(1, 0, 0),
        currentActivePackVersion: const SemanticVersion(1, 1, 0),
        serverMinPackVersion: const SemanticVersion(1, 1, 0),
        manualForce: true,
      ),
      throwsA(
        isA<ContentPackException>().having(
          (ContentPackException e) => e.code,
          'code',
          ContentPackErrorCode.downgradeRejected,
        ),
      ),
    );

    final File orphanBlobB = File('${blobsDir.path}/${'b' * 64}')
      ..writeAsBytesSync(<int>[4, 5, 6]);

    // 5) Startup promotes staged 1.2.0 -> 2 failed boots without markHomeBootSucceeded -> rollback to 1.1.0!
    final ResolvedContentPack boot1 = await svc.resolveStartupPack(
      bundledManifest: bundledManifest(),
      bundledAssetRoot: 'content/packs/v1',
    );
    expect(
      boot1.packVersion,
      '1.2.0',
    ); // attempt 1 (crashes before first frame)
    // Blob GC after startup promotion: orphan removed, active (1.2.0) + previous (1.1.0) blobs kept.
    expect(orphanBlobB.existsSync(), isFalse);
    for (final Map<String, List<int>> pk in <Map<String, List<int>>>[
      pack110,
      pack120,
    ]) {
      for (final List<int> bytes in pk.values) {
        expect(
          File('${blobsDir.path}/${await sha256Hex(bytes)}').existsSync(),
          isTrue,
        );
      }
    }

    final ResolvedContentPack boot2 = await svc.resolveStartupPack(
      bundledManifest: bundledManifest(),
      bundledAssetRoot: 'content/packs/v1',
    );
    expect(
      boot2.packVersion,
      '1.2.0',
    ); // attempt 2 (crashes before first frame)

    final ResolvedContentPack boot3 = await svc.resolveStartupPack(
      bundledManifest: bundledManifest(),
      bundledAssetRoot: 'content/packs/v1',
    );
    expect(boot3.packVersion, '1.1.0');
    expect(boot3.rolledBackFromVersion, '1.2.0');
    await svc.markHomeBootSucceeded();
  });

  test('P-07 / S-05: LocalSceneViewState (lastSeenEventSeq, lastOpenedAtLocal) never leaks into CoupleRoomSnapshot or server HTTP requests', () async {
    final DateTime now = DateTime.utc(2026, 11, 21, 18, 0);
    final CachedEventEntry partnerThought = CachedEventEntry(
      envelopeId: 'env-partner-1',
      coupleId: 'couple-1',
      senderDeviceId: 'dev-partner',
      channel: EnvelopeChannel.event,
      keyEpoch: 1,
      seq: 7,
      createdAtServer: now.subtract(const Duration(minutes: 20)),
      payload: DecryptedEnvelopePayload(
        schemaVersion: 1,
        eventType: 'thinking_of_you',
        createdAtClient: now.subtract(const Duration(minutes: 20)),
        authorDeviceId: 'dev-partner',
        body: const <String, Object?>{'note': 'Ciao amore'},
      ),
    );

    final SceneStateSnapshot snap = const SceneStateMapper().derive(
      events: <CachedEventEntry>[partnerThought],
      localDeviceId: 'dev-me',
      coupleId: 'couple-1',
      localViewState: LocalSceneViewState(
        lastSeenEventSeq: 3,
        lastOpenedAtLocal: now.subtract(const Duration(days: 4)),
        skyPreference: SkyTimePreference.auto,
      ),
      nowUtc: now,
      nowLocal: DateTime(2026, 11, 21, 19, 30),
    );

    // Shared snapshot JSON must NEVER contain any device-local read/open/presence keys
    final Map<String, Object?> sharedJson = snap.sharedSnapshot!.toJson();
    expect(sharedJson.keys, isNot(contains('lastSeenEventSeq')));
    expect(sharedJson.keys, isNot(contains('lastOpenedAtLocal')));
    expect(sharedJson.keys, isNot(contains('skyPreference')));
    expect(sharedJson.keys, isNot(contains('seenByDeviceId')));
    expect(CoupleRoomSnapshot.fromJson(sharedJson).lastEventSeq, 7);

    // Marking partner thought seen locally must trigger ZERO network calls
    int httpCallCount = 0;
    final DeepSkyController controller = DeepSkyController(
      keyStore: InMemorySecureKeyStore(),
      httpClient: MockClient((_) async {
        httpCallCount++;
        return http.Response('{}', 200);
      }),
      enableSkyRefreshTimer: false,
      clockUtc: () => now,
      clockLocal: () => DateTime(2026, 11, 21, 19, 30),
    );
    controller.events = <CachedEventEntry>[partnerThought];
    controller.sceneState = snap;
    expect(controller.sceneState.hasUnseenRecentPartnerThought, isTrue);

    await controller.markLatestPartnerThoughtSeen();
    expect(httpCallCount, 0);
    expect(controller.localSceneViewState.lastSeenEventSeq, 7);
    expect(controller.sceneState.hasUnseenRecentPartnerThought, isFalse);
    expect(controller.sceneState.floorLampLit, isFalse);
    controller.dispose();
  });
}
