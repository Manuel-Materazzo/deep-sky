import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/data/content_pack_service.dart';
import 'package:deep_sky/data/encrypted_local_cache.dart';
import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/domain/content/content_pack_models.dart';
import 'package:deep_sky/domain/crypto/deep_sky_crypto.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';
import 'package:deep_sky/domain/platform_capabilities.dart';
import 'package:deep_sky/platform/native_bridge.dart';
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
    Map<String, Object?> extraFields = const <String, Object?>{},
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
          ...extraFields,
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
    String packId = 'deep-sky-home-v1',
  }) {
    final List<int> png =
        floorBytes ?? <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    final String manifest = jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'packId': packId,
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
        expectedPackId: 'deep-sky-home-v1',
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
      expectedPackId: 'deep-sky-home-v1',
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
      expectedPackId: 'deep-sky-home-v1',
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
      expectedPackId: 'deep-sky-home-v1',
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
        expectedPackId: 'deep-sky-home-v1',
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

  test('AU-07 / AU-15 / AU-19: concurrent syncFromServer is serialized, oversized streams abort, and stale previous dirs are pruned', () async {
    final SimpleKeyPair kp = await ed25519.newKeyPair();
    final SimplePublicKey pub = await kp.extractPublicKey();
    final Directory tempRoot = Directory.systemTemp.createTempSync(
      'deepsky_au07_',
    );
    addTearDown(() => tempRoot.deleteSync(recursive: true));

    final Map<String, List<int>> files11 = buildValidPackFiles(
      packVersion: '1.1.0',
      floorBytes: <int>[1, 2, 3, 4],
    );
    final signed11 = await signPackPayload(
      keyPair: kp,
      keyId: 'v1',
      packId: 'deep-sky-home-v1',
      packVersion: '1.1.0',
      files: files11,
    );
    final Map<String, List<int>> files12 = buildValidPackFiles(
      packVersion: '1.2.0',
      floorBytes: <int>[5, 6, 7, 8],
    );
    final signed12 = await signPackPayload(
      keyPair: kp,
      keyId: 'v1',
      packId: 'deep-sky-home-v1',
      packVersion: '1.2.0',
      files: files12,
    );

    Map<String, List<int>> activeFiles = files11;
    var activeSigned = signed11;
    bool sendOversizedBlob = false;
    final MockClient mockHttp = MockClient((http.Request req) async {
      final String p = req.url.path;
      if (p.endsWith('/checksums')) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response.bytes(
          activeSigned.checksumsBytes,
          200,
          headers: <String, String>{
            'etag': '"e-${activeFiles['manifest.json']!.length}"',
          },
        );
      }
      if (p.endsWith('/checksums.sig')) {
        return http.Response.bytes(activeSigned.sigBytes, 200);
      }
      if (p.contains('/blobs/')) {
        final String sha = p.split('/').last;
        for (final List<int> bytes in activeFiles.values) {
          if (await sha256Hex(bytes) == sha) {
            if (sendOversizedBlob) {
              return http.Response.bytes(<int>[
                ...bytes,
                ...List<int>.filled(64, 9),
              ], 200);
            }
            return http.Response.bytes(bytes, 200);
          }
        }
      }
      return http.Response('not found', 404);
    });

    final ContentPackService svc = ContentPackService(
      keyStore: InMemorySecureKeyStore(),
      trustedPublicKeys: <String, SimplePublicKey>{'v1': pub},
      httpClient: mockHttp,
      resolveStorageRootDir: () async => tempRoot.path,
    );

    // AU-15: oversized blob response aborts with fileHashMismatch
    sendOversizedBlob = true;
    await expectLater(
      () => svc.syncFromServer(
        serverBaseUrl: 'https://test.local',
        bundledPackVersion: SemanticVersion.parse('1.0.0'),
        currentActivePackVersion: SemanticVersion.parse('1.0.0'),
        expectedPackId: 'deep-sky-home-v1',
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
    sendOversizedBlob = false;

    // AU-07: parallel background + manual syncFromServer serialize without corrupting state
    final List<ContentPackUpdateResult> results = await Future.wait(
      <Future<ContentPackUpdateResult>>[
        svc.syncFromServer(
          serverBaseUrl: 'https://test.local',
          bundledPackVersion: SemanticVersion.parse('1.0.0'),
          currentActivePackVersion: SemanticVersion.parse('1.0.0'),
          expectedPackId: 'deep-sky-home-v1',
          manualForce: false,
        ),
        svc.syncFromServer(
          serverBaseUrl: 'https://test.local',
          bundledPackVersion: SemanticVersion.parse('1.0.0'),
          currentActivePackVersion: SemanticVersion.parse('1.0.0'),
          expectedPackId: 'deep-sky-home-v1',
          manualForce: true,
        ),
      ],
    );
    expect(results[0].status, ContentPackUpdateStatus.stagedForNextBoot);
    expect(results[1].status, ContentPackUpdateStatus.activatedHotReload);

    // AU-19: create a stale older version in previous/ and upgrade to 1.2.0 -> stale dir is pruned
    final Directory stalePrev = Directory(
      '${tempRoot.path}${Platform.pathSeparator}previous${Platform.pathSeparator}1.0.5',
    )..createSync(recursive: true);
    File('${stalePrev.path}${Platform.pathSeparator}old.bin')
        .writeAsBytesSync(<int>[9, 9, 9]);
    activeFiles = files12;
    activeSigned = signed12;
    final ContentPackUpdateResult v12Res = await svc.syncFromServer(
      serverBaseUrl: 'https://test.local',
      bundledPackVersion: SemanticVersion.parse('1.0.0'),
      currentActivePackVersion: SemanticVersion.parse('1.1.0'),
      expectedPackId: 'deep-sky-home-v1',
      manualForce: true,
    );
    expect(v12Res.status, ContentPackUpdateStatus.activatedHotReload);
    expect(stalePrev.existsSync(), isFalse);
    expect(
      Directory(
        '${tempRoot.path}${Platform.pathSeparator}previous${Platform.pathSeparator}1.1.0',
      ).existsSync(),
      isTrue,
    );
  });

  // ---------------------------------------------------------------------------
  // Independent review 2026-11-22 regression tests (IR-01, IR-05, IR-06, IR-N1..N3, section 5)
  // ---------------------------------------------------------------------------

  const String metaKey = 'deepsky.content_pack.meta.v1';

  /// Minimal signed-pack HTTP server; records the headers of every `/checksums` request.
  MockClient packServer({
    required Map<String, List<int>> Function() files,
    required ({Uint8List checksumsBytes, Uint8List sigBytes}) Function() signed,
    List<Map<String, String>>? checksumRequestHeaders,
    String? etag,
  }) {
    return MockClient((http.Request req) async {
      final String path = req.url.path;
      if (path == '/api/v1/content/pack/checksums') {
        checksumRequestHeaders?.add(Map<String, String>.of(req.headers));
        return http.Response.bytes(
          signed().checksumsBytes,
          200,
          headers: <String, String>{'etag': ?etag},
        );
      }
      if (path == '/api/v1/content/pack/checksums.sig') {
        return http.Response.bytes(signed().sigBytes, 200);
      }
      const String prefix = '/api/v1/content/pack/blobs/';
      if (path.startsWith(prefix)) {
        final String hash = path.substring(prefix.length);
        for (final List<int> bytes in files().values) {
          if (await sha256Hex(bytes) == hash) {
            return http.Response.bytes(bytes, 200);
          }
        }
      }
      return http.Response('not found', 404);
    });
  }

  Future<Map<String, Object?>> readMeta(InMemorySecureKeyStore store) async =>
      jsonDecode((await store.read(metaKey)) ?? '{}') as Map<String, Object?>;

  void writePackDir(
    Directory root,
    String bucket,
    String version, {
    String packId = 'deep-sky-home-v1',
  }) {
    final Map<String, List<int>> files = buildValidPackFiles(
      packVersion: version,
      packId: packId,
    );
    for (final MapEntry<String, List<int>> e in files.entries) {
      final File f = File('${root.path}/$bucket/$version/${e.key}');
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync(e.value);
    }
  }

  Matcher throwsPackError(ContentPackErrorCode code) => throwsA(
    isA<ContentPackException>().having(
      (ContentPackException e) => e.code,
      'code',
      code,
    ),
  );

  test('IR-01: a correctly signed pack with a foreign packId is rejected (packIdMismatch) and never raises maxSeenVersion; a later legit Home pack still installs', () async {
    final SimpleKeyPair kp = await ed25519.newKeyPair();
    final Directory tempRoot = Directory.systemTemp.createTempSync(
      'deepsky_ir01_',
    );
    addTearDown(() => tempRoot.deleteSync(recursive: true));
    final InMemorySecureKeyStore store = InMemorySecureKeyStore();

    final Map<String, List<int>> foreignFiles = buildValidPackFiles(
      packVersion: '9.0.0',
      packId: 'some-other-pack',
    );
    final foreignSigned = await signPackPayload(
      keyPair: kp,
      keyId: 'v1',
      packId: 'some-other-pack',
      packVersion: '9.0.0',
      files: foreignFiles,
    );
    final Map<String, List<int>> homeFiles = buildValidPackFiles(
      packVersion: '1.2.0',
    );
    final homeSigned = await signPackPayload(
      keyPair: kp,
      keyId: 'v1',
      packId: 'deep-sky-home-v1',
      packVersion: '1.2.0',
      files: homeFiles,
    );
    bool serveForeign = true;
    final ContentPackService svc = ContentPackService(
      keyStore: store,
      trustedPublicKeys: <String, SimplePublicKey>{
        'v1': await kp.extractPublicKey(),
      },
      resolveStorageRootDir: () async => tempRoot.path,
      httpClient: packServer(
        files: () => serveForeign ? foreignFiles : homeFiles,
        signed: () => serveForeign ? foreignSigned : homeSigned,
      ),
    );

    for (final bool manual in <bool>[true, false]) {
      await expectLater(
        () => svc.syncFromServer(
          serverBaseUrl: 'https://couple.example.test',
          bundledPackVersion: const SemanticVersion(1, 0, 0),
          currentActivePackVersion: const SemanticVersion(1, 0, 0),
          expectedPackId: 'deep-sky-home-v1',
          manualForce: manual,
        ),
        throwsPackError(ContentPackErrorCode.packIdMismatch),
      );
    }
    final Map<String, Object?> meta = await readMeta(store);
    expect(meta['maxSeenVersion'], isNull);
    expect(meta['activeVersion'], isNull);
    expect(meta['stagedVersion'], isNull);
    expect(
      Directory('${tempRoot.path}/active').existsSync() &&
          Directory('${tempRoot.path}/active').listSync().isNotEmpty,
      isFalse,
    );
    expect(
      const ContentPackException(
        ContentPackErrorCode.packIdMismatch,
        'x',
      ).localizedMessage('it'),
      isNotEmpty,
    );
    expect(
      const ContentPackException(
        ContentPackErrorCode.packIdMismatch,
        'x',
      ).localizedMessage('en'),
      isNot(
        equals(
          const ContentPackException(
            ContentPackErrorCode.packIdMismatch,
            'x',
          ).localizedMessage('it'),
        ),
      ),
    );

    serveForeign = false;
    final ContentPackUpdateResult ok = await svc.syncFromServer(
      serverBaseUrl: 'https://couple.example.test',
      bundledPackVersion: const SemanticVersion(1, 0, 0),
      currentActivePackVersion: const SemanticVersion(1, 0, 0),
      expectedPackId: 'deep-sky-home-v1',
      manualForce: true,
    );
    expect(ok.status, ContentPackUpdateStatus.activatedHotReload);
    expect((await readMeta(store))['maxSeenVersion'], '1.2.0');
  });

  test('IR-01: startup rejects staged / active / previous packs whose manifest packId differs and falls back like any invalid pack', () async {
    // Staged foreign pack: discarded, bundled returned.
    final Directory r1 = Directory.systemTemp.createTempSync('deepsky_ir01s_');
    addTearDown(() => r1.deleteSync(recursive: true));
    final InMemorySecureKeyStore s1 = InMemorySecureKeyStore();
    writePackDir(r1, 'staged', '1.6.0', packId: 'some-other-pack');
    await s1.write(
      metaKey,
      jsonEncode(<String, Object?>{'stagedVersion': '1.6.0', 'etag': '"e"'}),
    );
    final ContentPackService svc1 = ContentPackService(
      keyStore: s1,
      trustedPublicKeys: const <String, SimplePublicKey>{},
      resolveStorageRootDir: () async => r1.path,
    );
    final ResolvedContentPack res1 = await svc1.resolveStartupPack(
      bundledManifest: bundledManifest(),
      bundledAssetRoot: 'content/packs/v1',
    );
    expect(res1.isFileSystem, isFalse);
    expect((await readMeta(s1))['stagedVersion'], isNull);
    expect((await readMeta(s1))['activeVersion'], isNull);

    // Active foreign pack: dropped, bundled returned.
    final Directory r2 = Directory.systemTemp.createTempSync('deepsky_ir01a_');
    addTearDown(() => r2.deleteSync(recursive: true));
    final InMemorySecureKeyStore s2 = InMemorySecureKeyStore();
    writePackDir(r2, 'active', '1.5.0', packId: 'some-other-pack');
    await s2.write(
      metaKey,
      jsonEncode(<String, Object?>{'activeVersion': '1.5.0', 'etag': '"e"'}),
    );
    final ContentPackService svc2 = ContentPackService(
      keyStore: s2,
      trustedPublicKeys: const <String, SimplePublicKey>{},
      resolveStorageRootDir: () async => r2.path,
    );
    final ResolvedContentPack res2 = await svc2.resolveStartupPack(
      bundledManifest: bundledManifest(),
      bundledAssetRoot: 'content/packs/v1',
    );
    expect(res2.isFileSystem, isFalse);
    expect(res2.packVersion, '1.0.0');
    expect((await readMeta(s2))['activeVersion'], isNull);
    expect((await readMeta(s2))['etag'], isNull); // IR-05

    // Previous foreign pack during rollback: skipped, bundled returned.
    final Directory r3 = Directory.systemTemp.createTempSync('deepsky_ir01p_');
    addTearDown(() => r3.deleteSync(recursive: true));
    final InMemorySecureKeyStore s3 = InMemorySecureKeyStore();
    writePackDir(r3, 'active', '1.4.0');
    writePackDir(r3, 'previous', '1.3.0', packId: 'some-other-pack');
    await s3.write(
      metaKey,
      jsonEncode(<String, Object?>{
        'activeVersion': '1.4.0',
        'previousVersion': '1.3.0',
        'packBootAttempts': 2,
      }),
    );
    final ContentPackService svc3 = ContentPackService(
      keyStore: s3,
      trustedPublicKeys: const <String, SimplePublicKey>{},
      resolveStorageRootDir: () async => r3.path,
    );
    final ResolvedContentPack res3 = await svc3.resolveStartupPack(
      bundledManifest: bundledManifest(),
      bundledAssetRoot: 'content/packs/v1',
    );
    expect(res3.isFileSystem, isFalse);
    expect(res3.rolledBackFromVersion, '1.4.0');
  });

  group(
    'IR-05: stale ETag is cleared when a staged/active pack is dropped',
    () {
      Future<List<Map<String, String>>> nextSilentSyncHeaders(
        InMemorySecureKeyStore store,
        Directory root,
      ) async {
        final List<Map<String, String>> seen = <Map<String, String>>[];
        final ContentPackService svc = ContentPackService(
          keyStore: store,
          trustedPublicKeys: const <String, SimplePublicKey>{},
          resolveStorageRootDir: () async => root.path,
          httpClient: MockClient((http.Request req) async {
            seen.add(Map<String, String>.of(req.headers));
            return http.Response('not found', 404);
          }),
        );
        await svc.syncFromServer(
          serverBaseUrl: 'https://couple.example.test',
          bundledPackVersion: const SemanticVersion(1, 0, 0),
          currentActivePackVersion: const SemanticVersion(1, 0, 0),
          expectedPackId: 'deep-sky-home-v1',
        );
        return seen;
      }

      Future<void> runScenario({
        required Map<String, Object?> meta,
        void Function(Directory root)? seedDirs,
        SemanticVersion? serverMin,
      }) async {
        final Directory root = Directory.systemTemp.createTempSync(
          'deepsky_ir05_',
        );
        addTearDown(() => root.deleteSync(recursive: true));
        final InMemorySecureKeyStore store = InMemorySecureKeyStore();
        seedDirs?.call(root);
        await store.write(
          metaKey,
          jsonEncode(<String, Object?>{...meta, 'etag': '"stale"'}),
        );
        final ContentPackService svc = ContentPackService(
          keyStore: store,
          trustedPublicKeys: const <String, SimplePublicKey>{},
          resolveStorageRootDir: () async => root.path,
        );
        await svc.resolveStartupPack(
          bundledManifest: bundledManifest(),
          bundledAssetRoot: 'content/packs/v1',
          serverMinPackVersion: serverMin,
        );
        expect((await readMeta(store))['etag'], isNull);
        final List<Map<String, String>> headers = await nextSilentSyncHeaders(
          store,
          root,
        );
        expect(headers, hasLength(1));
        expect(headers.single.containsKey('If-None-Match'), isFalse);
      }

      test(
        'staged pack whose manifest fails to load',
        () => runScenario(
          meta: <String, Object?>{
            'stagedVersion': '1.2.0',
          }, // no staged/1.2.0 dir on disk
        ),
      );

      test(
        'staged pack below the minimum acceptable version',
        () => runScenario(
          meta: <String, Object?>{
            'stagedVersion': '1.1.0',
            'maxSeenVersion': '1.3.0',
          },
          seedDirs: (Directory r) => writePackDir(r, 'staged', '1.1.0'),
        ),
      );

      test(
        'active pack rolled back to the bundled pack',
        () => runScenario(
          meta: <String, Object?>{
            'activeVersion': '1.2.0',
            'packBootAttempts': 2,
          },
          seedDirs: (Directory r) => writePackDir(r, 'active', '1.2.0'),
        ),
      );

      test(
        'active pack rolled back to the previous pack',
        () => runScenario(
          meta: <String, Object?>{
            'activeVersion': '1.2.0',
            'previousVersion': '1.1.0',
            'packBootAttempts': 2,
          },
          seedDirs: (Directory r) {
            writePackDir(r, 'active', '1.2.0');
            writePackDir(r, 'previous', '1.1.0');
          },
        ),
      );

      test('control: a healthy active pack keeps its ETag', () async {
        final Directory root = Directory.systemTemp.createTempSync(
          'deepsky_ir05c_',
        );
        addTearDown(() => root.deleteSync(recursive: true));
        final InMemorySecureKeyStore store = InMemorySecureKeyStore();
        writePackDir(root, 'active', '1.2.0');
        await store.write(
          metaKey,
          jsonEncode(<String, Object?>{
            'activeVersion': '1.2.0',
            'etag': '"fresh"',
          }),
        );
        final ContentPackService svc = ContentPackService(
          keyStore: store,
          trustedPublicKeys: const <String, SimplePublicKey>{},
          resolveStorageRootDir: () async => root.path,
        );
        await svc.resolveStartupPack(
          bundledManifest: bundledManifest(),
          bundledAssetRoot: 'content/packs/v1',
        );
        expect((await readMeta(store))['etag'], '"fresh"');
      });
    },
  );

  test('IR-06 (PD-19 transitional): checksums `type` is optional, but must equal deep-sky/pack-checksums when present', () async {
    final SimpleKeyPair kp = await ed25519.newKeyPair();
    final ContentPackService service = ContentPackService(
      keyStore: InMemorySecureKeyStore(),
      trustedPublicKeys: <String, SimplePublicKey>{
        'v1': await kp.extractPublicKey(),
      },
    );
    final Map<String, List<int>> files = buildValidPackFiles(
      packVersion: '1.1.0',
    );

    Future<ContentPackChecksums> parse(Map<String, Object?> extra) async {
      final signed = await signPackPayload(
        keyPair: kp,
        keyId: 'v1',
        packId: 'deep-sky-home-v1',
        packVersion: '1.1.0',
        files: files,
        extraFields: extra,
      );
      return service.verifyAndParseChecksums(
        rawChecksumsBytes: signed.checksumsBytes,
        rawSignatureBytes: signed.sigBytes,
      );
    }

    expect((await parse(<String, Object?>{})).packId, 'deep-sky-home-v1');
    expect(
      (await parse(<String, Object?>{'type': 'deep-sky/pack-checksums'}))
          .packVersion,
      const SemanticVersion(1, 1, 0),
    );
    for (final Object? bad in <Object?>['deep-sky/apk-manifest', '', null, 7]) {
      await expectLater(
        () => parse(<String, Object?>{'type': bad}),
        throwsPackError(ContentPackErrorCode.checksumsInvalid),
      );
    }
  });

  test('IR-N1: the keyId:base64 signature envelope is mandatory (raw 64 bytes and unprefixed base64 are rejected)', () async {
    final SimpleKeyPair kp = await ed25519.newKeyPair();
    final ContentPackService service = ContentPackService(
      keyStore: InMemorySecureKeyStore(),
      trustedPublicKeys: <String, SimplePublicKey>{
        'v1': await kp.extractPublicKey(),
      },
    );
    final signed = await signPackPayload(
      keyPair: kp,
      keyId: 'v1',
      packId: 'deep-sky-home-v1',
      packVersion: '1.1.0',
      files: buildValidPackFiles(packVersion: '1.1.0'),
    );
    final String envelope = utf8.decode(signed.sigBytes).trim();
    final String b64 = envelope.substring('v1:'.length);

    // Control: the prefixed form verifies.
    await service.verifyAndParseChecksums(
      rawChecksumsBytes: signed.checksumsBytes,
      rawSignatureBytes: signed.sigBytes,
    );
    // Unprefixed base64 of a VALID signature and raw 64 signature bytes are both rejected.
    for (final Uint8List bad in <Uint8List>[
      Uint8List.fromList(utf8.encode('$b64\n')),
      Uint8List.fromList(base64Decode(b64)),
    ]) {
      await expectLater(
        () => service.verifyAndParseChecksums(
          rawChecksumsBytes: signed.checksumsBytes,
          rawSignatureBytes: bad,
        ),
        // Random raw bytes may or may not contain a ':' by chance, so either envelope error is
        // a rejection; the point is that neither form is ever accepted as `v1`.
        throwsA(
          isA<ContentPackException>().having(
            (ContentPackException e) => e.code,
            'code',
            anyOf(
              ContentPackErrorCode.signatureInvalid,
              ContentPackErrorCode.unknownKeyId,
            ),
          ),
        ),
      );
    }
  });

  test('IR-N2: isSafeRelativePath rejects every control character U+0000-U+001F and U+007F', () async {
    expect(ContentPackService.isSafeRelativePath('assets/floor.png'), isTrue);
    for (int code = 0; code <= 0x1F; code++) {
      expect(
        ContentPackService.isSafeRelativePath(
          'assets/fl${String.fromCharCode(code)}oor.png',
        ),
        isFalse,
        reason: 'control 0x${code.toRadixString(16)}',
      );
    }
    expect(
      ContentPackService.isSafeRelativePath('assets/fl\u007Foor.png'),
      isFalse,
    );

    // End-to-end: a signed checksums file listing such a path is rejected as pathTraversal.
    final SimpleKeyPair kp = await ed25519.newKeyPair();
    final ContentPackService service = ContentPackService(
      keyStore: InMemorySecureKeyStore(),
      trustedPublicKeys: <String, SimplePublicKey>{
        'v1': await kp.extractPublicKey(),
      },
    );
    final Map<String, List<int>> files = buildValidPackFiles(
      packVersion: '1.1.0',
    );
    final signed = await signPackPayload(
      keyPair: kp,
      keyId: 'v1',
      packId: 'deep-sky-home-v1',
      packVersion: '1.1.0',
      files: <String, List<int>>{
        'manifest.json': files['manifest.json']!,
        'assets/fl\u0001oor.png': <int>[1, 2, 3],
      },
    );
    await expectLater(
      () => service.verifyAndParseChecksums(
        rawChecksumsBytes: signed.checksumsBytes,
        rawSignatureBytes: signed.sigBytes,
      ),
      throwsPackError(ContentPackErrorCode.pathTraversal),
    );
  });

  test('IR-N3: manualForce with the already-active version returns upToDate without rebuilding active/<version>; a damaged active dir is still repaired', () async {
    final SimpleKeyPair kp = await ed25519.newKeyPair();
    final Directory tempRoot = Directory.systemTemp.createTempSync(
      'deepsky_irn3_',
    );
    addTearDown(() => tempRoot.deleteSync(recursive: true));
    final InMemorySecureKeyStore store = InMemorySecureKeyStore();
    final Map<String, List<int>> files = buildValidPackFiles(
      packVersion: '1.2.0',
    );
    final signed = await signPackPayload(
      keyPair: kp,
      keyId: 'v1',
      packId: 'deep-sky-home-v1',
      packVersion: '1.2.0',
      files: files,
    );
    final ContentPackService svc = ContentPackService(
      keyStore: store,
      trustedPublicKeys: <String, SimplePublicKey>{
        'v1': await kp.extractPublicKey(),
      },
      resolveStorageRootDir: () async => tempRoot.path,
      httpClient: packServer(files: () => files, signed: () => signed),
    );
    Future<ContentPackUpdateResult> manual() => svc.syncFromServer(
      serverBaseUrl: 'https://couple.example.test',
      bundledPackVersion: const SemanticVersion(1, 0, 0),
      currentActivePackVersion: const SemanticVersion(1, 2, 0),
      expectedPackId: 'deep-sky-home-v1',
      manualForce: true,
    );

    expect((await manual()).status, ContentPackUpdateStatus.activatedHotReload);
    // Marker proves the live directory is not rebuilt/moved over.
    final File marker = File('${tempRoot.path}/active/1.2.0/marker.tmp')
      ..writeAsStringSync('live');
    final ContentPackUpdateResult again = await manual();
    expect(again.status, ContentPackUpdateStatus.upToDate);
    expect(again.packVersion, '1.2.0');
    expect(marker.existsSync(), isTrue);

    // Damaged active dir (asset missing) -> normal rebuild path.
    File('${tempRoot.path}/active/1.2.0/assets/floor.png').deleteSync();
    final ContentPackUpdateResult repaired = await manual();
    expect(repaired.status, ContentPackUpdateStatus.activatedHotReload);
    expect(
      File('${tempRoot.path}/active/1.2.0/assets/floor.png').existsSync(),
      isTrue,
    );
  });

  test('Review section 5 / P-07 / S-05: initialize -> replyToPartnerThought / sendThinkingOfYou never put lastSeenEventSeq, lastSeenThoughtEnvelopeId or lastOpenedAtLocal on the wire', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const int sentinelSeq = 424242; // seeded lastSeenEventSeq
    const String sentinelEnvelopeId = 'env-SENTINEL-previously-seen-0042';
    const int newThoughtSeq = 424250;
    const String newThoughtEnvelopeId = 'env-SENTINEL-partner-new-0050';
    final DateTime seededOpened = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final DateTime nowUtc = DateTime.utc(2026, 11, 21, 18, 0, 17);

    final DeepSkyCrypto crypto = DeepSkyCrypto();
    final InMemorySecureKeyStore store = InMemorySecureKeyStore();
    final authKp = await crypto.generateDeviceAuthKeyPair();
    final kemKp = await crypto.generateDeviceKemKeyPair();
    final Uint8List seed = Uint8List.fromList(
      List<int>.generate(32, (int i) => i + 11),
    );
    final LocalDeviceIdentity id = LocalDeviceIdentity(
      serverUrl: 'https://couple.example.test',
      coupleId: 'couple-priv',
      deviceId: 'dev-me',
      deviceLabel: 'Luca',
      authPrivateKeySeed: Uint8List.fromList(
        await authKp.extractPrivateKeyBytes(),
      ),
      authPublicKey: Uint8List.fromList(
        (await authKp.extractPublicKey()).bytes,
      ),
      kemPrivateKey: Uint8List.fromList(await kemKp.extractPrivateKeyBytes()),
      kemPublicKey: Uint8List.fromList((await kemKp.extractPublicKey()).bytes),
      recoverySeed: seed,
      pairingCompleted: true,
      nameSetupCompleted: true,
      recoverySavedConfirmed: true,
    );
    await store.write('deep_sky.device_identity.v1', jsonEncode(id.toJson()));
    await LocalSceneViewStateStore(store).save(
      LocalSceneViewState(
        lastSeenEventSeq: sentinelSeq,
        lastSeenThoughtEnvelopeId: sentinelEnvelopeId,
        lastOpenedAtLocal: seededOpened,
      ),
    );

    final List<http.BaseRequest> recorded = <http.BaseRequest>[];
    final List<String> bodies = <String>[];
    final MockClient client = MockClient((http.Request req) async {
      recorded.add(req);
      bodies.add(req.body);
      final String path = req.url.path;
      if (path == '/api/v1/system/compatibility') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'minClientVersionCode': 1,
            'minProtocolVersion': 1,
            'minPackVersion': '1.0.0',
          }),
          200,
        );
      }
      if (path == '/api/v1/sync/envelopes' && req.method == 'GET') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'items': <Object?>[],
            'nextAfterSeq': 0,
            'hasMore': false,
            'coupleKeyEpoch': 1,
          }),
          200,
        );
      }
      if (path == '/api/v1/sync/envelopes' && req.method == 'POST') {
        final Map<String, Object?> body =
            jsonDecode(req.body) as Map<String, Object?>;
        return http.Response(
          jsonEncode(<String, Object?>{
            ...body,
            'coupleId': 'couple-priv',
            'senderDeviceId': 'dev-me',
            'seq': 1,
            'createdAtServer': nowUtc.toIso8601String(),
          }),
          201,
        );
      }
      if (path == '/api/v1/pairing/devices') {
        return http.Response('[]', 200);
      }
      if (path == '/api/v1/push/config') {
        return http.Response('{"enabled":false}', 200);
      }
      if (path.startsWith('/api/v1/content/pack/')) {
        return http.Response('not found', 404);
      }
      return http.Response('{}', 200);
    });

    final DeepSkyController controller = DeepSkyController(
      keyStore: store,
      httpClient: client,
      loadAssetString: (_) async =>
          File('content/packs/v1/manifest.json').readAsStringSync(),
      loadCapabilities: () async => const PlatformCapabilities(
        packageName: 'com.vectevo.deep_sky',
        androidApiLevel: 35,
        versionName: '1.1.0',
        versionCode: 2,
        supportsRequestInstallPackages: false,
      ),
      defaultServerUrl: 'https://couple.example.test',
      enableSkyRefreshTimer: false,
      clockUtc: () => nowUtc,
      clockLocal: () => DateTime(2026, 11, 21, 19, 0, 17),
    );
    addTearDown(controller.dispose);

    await controller
        .initialize(); // writes lastOpenedAtLocal (new value = clock)
    expect(controller.localSceneViewState.lastOpenedAtLocal, isNotNull);
    expect(controller.localSceneViewState.lastOpenedAtLocal!.toUtc(), nowUtc);

    final CachedEventEntry partnerThought = CachedEventEntry(
      envelopeId: newThoughtEnvelopeId,
      coupleId: 'couple-priv',
      senderDeviceId: 'dev-partner',
      channel: EnvelopeChannel.event,
      keyEpoch: 1,
      seq: newThoughtSeq,
      createdAtServer: nowUtc.subtract(const Duration(minutes: 20)),
      payload: DecryptedEnvelopePayload(
        schemaVersion: 1,
        eventType: 'thinking_of_you',
        createdAtClient: nowUtc.subtract(const Duration(minutes: 20)),
        authorDeviceId: 'dev-partner',
        body: const <String, Object?>{'note': 'Ciao amore'},
      ),
    );
    controller.events = <CachedEventEntry>[partnerThought];
    controller.sceneState = const SceneStateMapper().derive(
      events: controller.events,
      localDeviceId: 'dev-me',
      coupleId: 'couple-priv',
      localViewState: controller.localSceneViewState,
      nowUtc: nowUtc,
      nowLocal: DateTime(2026, 11, 21, 19, 0, 17),
    );
    expect(controller.sceneState.unseenPartnerThought, isNotNull);

    final int before = recorded.length;
    await controller.replyToPartnerThought(note: 'Anche io');
    await controller.sendThinkingOfYou();
    expect(controller.errorNotice, isNull);
    expect(recorded.length, greaterThan(before));
    expect(
      controller.localSceneViewState.lastSeenThoughtEnvelopeId,
      newThoughtEnvelopeId,
      reason: 'reply must have marked the thought as seen locally',
    );

    // Everything the local view state ever held (seeded + current) must be absent from the wire.
    final LocalSceneViewState lv = controller.localSceneViewState;
    final List<String> forbiddenKeys = <String>[
      'lastSeenEventSeq',
      'lastSeenThoughtEnvelopeId',
      'lastOpenedAtLocal',
    ];
    final List<String> forbiddenValues = <String>[
      sentinelEnvelopeId,
      newThoughtEnvelopeId,
      seededOpened.toIso8601String(),
      lv.lastOpenedAtLocal!.toIso8601String(),
      lv.lastOpenedAtLocal!.toUtc().toIso8601String(),
    ];
    final List<String> seqStrings = <String>[
      sentinelSeq.toString(),
      newThoughtSeq.toString(),
    ];

    for (int i = 0; i < recorded.length; i++) {
      final http.BaseRequest req = recorded[i];
      final String url = req.url.toString();
      final String headers = req.headers.entries
          .map((MapEntry<String, String> e) => '${e.key}: ${e.value}')
          .join('\n');
      for (final String needle in <String>[
        ...forbiddenKeys,
        ...forbiddenValues,
      ]) {
        expect(url, isNot(contains(needle)), reason: 'URL leaks $needle');
        expect(
          headers,
          isNot(contains(needle)),
          reason: 'headers leak $needle',
        );
        expect(
          bodies[i],
          isNot(contains(needle)),
          reason: 'body leaks $needle',
        );
      }
      // The numeric sentinel is checked on URL/headers only: bodies carry random base64.
      for (final String seq in seqStrings) {
        expect(url, isNot(contains(seq)));
        expect(headers, isNot(contains(seq)));
      }
    }

    // The envelope bodies are E2EE ciphertext, so also assert on the PLAINTEXT by decrypting
    // every uploaded envelope with the couple key (the repository/crypto seam).
    final Uint8List rootKey = await crypto.deriveCoupleRootKey(seed);
    int decryptedUploads = 0;
    for (int i = 0; i < recorded.length; i++) {
      if (recorded[i].method == 'POST' &&
          recorded[i].url.path == '/api/v1/sync/envelopes') {
        final EncryptedEnvelope env = EncryptedEnvelope.fromJson(
          <String, Object?>{
            ...(jsonDecode(bodies[i]) as Map<String, Object?>),
            // The server derives these from the authenticated device, not from the body.
            'coupleId': 'couple-priv',
            'senderDeviceId': 'dev-me',
          },
        );
        final DecryptedEnvelopePayload plain = await crypto.decryptEnvelope(
          rootKey: rootKey,
          expectedCoupleId: 'couple-priv',
          envelope: env,
        );
        final String plainJson = jsonEncode(plain.toJson());
        decryptedUploads++;
        expect(plain.eventType, 'thinking_of_you');
        for (final String needle in <String>[
          ...forbiddenKeys,
          ...forbiddenValues,
          ...seqStrings,
        ]) {
          expect(
            plainJson,
            isNot(contains(needle)),
            reason: 'plaintext leaks $needle',
          );
        }
      }
    }
    expect(decryptedUploads, 2);
  });

  test('AU-24: setSecureScreen is reference-counted across nested sensitive screens', () async {
    final List<bool> nativeCalls = <bool>[];
    final _RecordingNativeBridge bridge = _RecordingNativeBridge(nativeCalls);
    final DeepSkyController controller = DeepSkyController(
      keyStore: InMemorySecureKeyStore(),
      nativeBridge: bridge,
      enableSkyRefreshTimer: false,
    );

    await controller.setSecureScreen(true); // page 1 opens -> native true
    await controller.setSecureScreen(
      true,
    ); // nested page 2 opens -> no duplicate call
    await controller.setSecureScreen(
      false,
    ); // page 2 closes -> still protected!
    expect(nativeCalls, <bool>[true]);

    await controller.setSecureScreen(false); // page 1 closes -> native false
    expect(nativeCalls, <bool>[true, false]);
    controller.dispose();
  });
}

class _RecordingNativeBridge extends NativeBridge {
  _RecordingNativeBridge(this.secureCalls);

  final List<bool> secureCalls;

  @override
  Future<void> setSecureScreen(bool enabled) async {
    secureCalls.add(enabled);
  }
}
