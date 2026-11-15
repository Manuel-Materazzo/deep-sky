import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/data/couple_api_client.dart';
import 'package:deep_sky/data/pairing_and_sync_repository.dart';
import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/domain/crypto/deep_sky_crypto.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';
import 'package:deep_sky/domain/crypto/recovery_key_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('SP-02 full client flow: pairing with SAS, E2EE envelopes, 24-word/QR recovery, enrollment, revocation', () async {
    final _FakeServer fakeServer = _FakeServer();
    final MockClient mockHttp = MockClient(fakeServer.handle);
    final DeepSkyCrypto crypto = DeepSkyCrypto();

    PairingAndSyncRepository makeRepo(InMemorySecureKeyStore store) =>
        PairingAndSyncRepository(
          keyStore: store,
          crypto: crypto,
          clientFactory: (String url) => CoupleApiClient(
            baseUrl: url,
            httpClient: mockHttp,
            crypto: crypto,
          ),
        );

    final PairingAndSyncRepository repoA = makeRepo(InMemorySecureKeyStore());
    final PairingAndSyncRepository repoB = makeRepo(InMemorySecureKeyStore());
    final PairingAndSyncRepository repoR = makeRepo(InMemorySecureKeyStore());
    final PairingAndSyncRepository repoB2 = makeRepo(InMemorySecureKeyStore());

    // 1. Device A creates invite
    final init = await repoA.createInitialInvite(
      serverUrl: 'https://test.local',
      deviceLabel: 'Phone A',
    );

    // 2. Device B accepts invite -> SAS matches Device A's SAS
    final PendingJoinSession joinSession = await repoB.acceptInvite(
      serverUrl: 'https://test.local',
      inviteToken: init.invite.inviteToken,
      deviceLabel: 'Phone B',
    );
    final status = await repoA.checkInviteAndSas(init.invite.inviteToken);
    expect(status.status.accepted, isTrue);
    expect(status.sasCode, equals(joinSession.sasCode));

    // 3. Device A delivers wrapped recoverySeed -> Device B completes pairing
    await repoA.confirmSasAndDeliverRootKey(
      targetDeviceId: status.status.acceptedDeviceId!,
      targetKemPublicKey: status.status.acceptedKemPublicKey!,
    );
    final LocalDeviceIdentity idB = await repoB.completeKeyDelivery(
      session: joinSession,
    );
    expect(idB.recoverySeed, orderedEquals(init.identity.recoverySeed!));
    await repoB.confirmRecoveryKeySaved();

    // 4. Device A sends a secret time capsule; Device B decrypts it
    await repoA.sendEncryptedEvent(
      eventType: 'time_capsule',
      body: <String, Object?>{
        'title': 'Anniversario',
        'unlockAt': '2027-05-01T00:00:00Z',
      },
    );
    final List<DecryptedEventRecord> eventsOnB = await repoB
        .fetchAndDecryptEvents();
    expect(eventsOnB.length, 1);
    expect(eventsOnB.first.payload.eventType, 'time_capsule');
    expect(eventsOnB.first.payload.body['title'], 'Anniversario');

    // Server visibility check: plaintext words never appear in stored envelopes
    final String serverDump = jsonEncode(fakeServer.envelopes);
    expect(serverDump.contains('time_capsule'), isFalse);
    expect(serverDump.contains('Anniversario'), isFalse);
    expect(serverDump.contains('2027-05-01'), isFalse);

    // 5. Zero-second-phone recovery via 24 words (and verify QR matches)
    final String phrase = RecoveryKeyCodec.toSentence(
      init.identity.recoverySeed!,
    );
    final String qr = RecoveryKeyCodec.toQrPayload(init.identity.recoverySeed!);
    expect(
      RecoveryKeyCodec.parseUserInput(qr),
      orderedEquals(init.identity.recoverySeed!),
    );

    final LocalDeviceIdentity idR = await repoR.recoverWithRecoveryKey(
      serverUrl: 'https://test.local',
      recoveryInput: phrase,
      deviceLabel: 'Recovered Phone',
    );
    expect(idR.coupleId, equals(init.identity.coupleId));
    final List<DecryptedEventRecord> recoveredEvents = await repoR
        .fetchAndDecryptEvents();
    expect(recoveredEvents.length, 1);
    expect(recoveredEvents.first.payload.body['title'], 'Anniversario');

    // 6. Cross-device enrollment from Phone A -> Phone B2
    final CreateInviteResponse enrollInvite = await repoA
        .createEnrollmentInvite();
    final PendingJoinSession b2Join = await repoB2.acceptInvite(
      serverUrl: 'https://test.local',
      inviteToken: enrollInvite.inviteToken,
      deviceLabel: 'New Phone B2',
    );
    final enrollStatus = await repoA.checkInviteAndSas(
      enrollInvite.inviteToken,
    );
    expect(enrollStatus.sasCode, equals(b2Join.sasCode));
    await repoA.confirmSasAndDeliverRootKey(
      targetDeviceId: enrollStatus.status.acceptedDeviceId!,
      targetKemPublicKey: enrollStatus.status.acceptedKemPublicKey!,
    );
    final LocalDeviceIdentity idB2 = await repoB2.completeKeyDelivery(
      session: b2Join,
    );
    expect(idB2.recoverySeed, orderedEquals(init.identity.recoverySeed!));

    // 7. Device revocation: Device A revokes Device B -> Device B is blocked
    await repoA.revokeDevice(idB.deviceId);
    await expectLater(
      repoB.fetchAndDecryptEvents(),
      throwsA(isA<ApiRequestException>()),
    );
  });

  test('offline encrypted local cache stores ciphertext only and survives offline fallback (AD-06, TC-07)', () async {
    final _FakeServer fakeServer = _FakeServer();
    bool simulateOffline = false;
    final MockClient mockHttp = MockClient((http.Request req) async {
      if (simulateOffline) {
        throw const SocketException('Network unreachable');
      }
      return fakeServer.handle(req);
    });
    final DeepSkyCrypto crypto = DeepSkyCrypto();
    final InMemorySecureKeyStore storeA = InMemorySecureKeyStore();

    final PairingAndSyncRepository repoA = PairingAndSyncRepository(
      keyStore: storeA,
      crypto: crypto,
      clientFactory: (String url) =>
          CoupleApiClient(baseUrl: url, httpClient: mockHttp, crypto: crypto),
    );

    await repoA.createInitialInvite(
      serverUrl: 'https://test.local',
      deviceLabel: 'Phone A',
    );
    await repoA.sendEncryptedEvent(
      eventType: 'thinking_of_you',
      body: <String, Object?>{'note': 'Un pensiero segreto sotto il cielo'},
    );

    final SyncEventsSnapshot onlineSnap = await repoA
        .syncEventsWithOfflineFallback();
    expect(onlineSnap.isOffline, isFalse);
    expect(onlineSnap.events, hasLength(1));
    expect(
      onlineSnap.events.first.payload.body['note'],
      'Un pensiero segreto sotto il cielo',
    );

    // Ensure the persisted offline cache in SecureKeyStore does not leak plaintext
    final String? cachedRaw = await storeA.read('deep_sky.offline_cache.v1');
    expect(cachedRaw, isNotNull);
    expect(cachedRaw!.contains('Un pensiero segreto'), isFalse);
    expect(cachedRaw.contains('thinking_of_you'), isFalse);

    // Switch offline -> fallback returns decrypted cached events cleanly
    simulateOffline = true;
    final SyncEventsSnapshot offlineSnap = await repoA
        .syncEventsWithOfflineFallback();
    expect(offlineSnap.isOffline, isTrue);
    expect(offlineSnap.events, hasLength(1));
    expect(
      offlineSnap.events.first.payload.body['note'],
      'Un pensiero segreto sotto il cielo',
    );

    // Tampered offline cache fails AEAD verification
    final Map<String, Object?> tampered =
        jsonDecode(cachedRaw) as Map<String, Object?>;
    tampered['ciphertextB64'] = base64UrlEncode(Uint8List(32));
    await storeA.write('deep_sky.offline_cache.v1', jsonEncode(tampered));
    await expectLater(
      repoA.loadCachedEvents(),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('unlinkCurrentDevice revokes only calling device and wipes local state even on 401/offline', () async {
    final _FakeServer fakeServer = _FakeServer();
    bool simulateOffline = false;
    final MockClient mockHttp = MockClient((http.Request req) async {
      if (simulateOffline) {
        throw const SocketException('Network unreachable');
      }
      return fakeServer.handle(req);
    });
    final DeepSkyCrypto crypto = DeepSkyCrypto();

    PairingAndSyncRepository makeRepo(InMemorySecureKeyStore store) =>
        PairingAndSyncRepository(
          keyStore: store,
          crypto: crypto,
          clientFactory: (String url) => CoupleApiClient(
            baseUrl: url,
            httpClient: mockHttp,
            crypto: crypto,
          ),
        );

    final InMemorySecureKeyStore storeA = InMemorySecureKeyStore();
    final InMemorySecureKeyStore storeB = InMemorySecureKeyStore();
    final InMemorySecureKeyStore storeC = InMemorySecureKeyStore();
    final PairingAndSyncRepository repoA = makeRepo(storeA);
    final PairingAndSyncRepository repoB = makeRepo(storeB);
    final PairingAndSyncRepository repoC = makeRepo(storeC);

    final init = await repoA.createInitialInvite(
      serverUrl: 'https://test.local',
      deviceLabel: 'Phone A',
    );
    final PendingJoinSession joinB = await repoB.acceptInvite(
      serverUrl: 'https://test.local',
      inviteToken: init.invite.inviteToken,
      deviceLabel: 'Phone B',
    );
    final status = await repoA.checkInviteAndSas(init.invite.inviteToken);
    await repoA.confirmSasAndDeliverRootKey(
      targetDeviceId: status.status.acceptedDeviceId!,
      targetKemPublicKey: status.status.acceptedKemPublicKey!,
    );
    final LocalDeviceIdentity idB = await repoB.completeKeyDelivery(
      session: joinB,
    );
    await repoB.confirmRecoveryKeySaved();

    // Enroll Phone C via recovery key
    await repoC.recoverWithRecoveryKey(
      serverUrl: 'https://test.local',
      recoveryInput: RecoveryKeyCodec.toSentence(init.identity.recoverySeed!),
      deviceLabel: 'Phone C',
    );
    final LocalDeviceIdentity idC = (await repoC.loadIdentity())!;

    // Populate offline cache on Phone B before unlinking
    await repoA.sendEncryptedEvent(
      eventType: 'thinking_of_you',
      body: <String, Object?>{'note': 'Ciao'},
    );
    await repoB.syncEventsWithOfflineFallback();
    expect(await storeB.read('deep_sky.offline_cache.v1'), isNotNull);

    // 1. Phone B unlinks itself: ONLY Phone B is revoked; Phone A and C stay active
    await repoB.unlinkCurrentDevice();
    expect(await repoB.loadIdentity(), isNull);
    expect(await storeB.read('deep_sky.offline_cache.v1'), isNull);
    expect(fakeServer.devices[idB.deviceId]!['revokedAt'], isNotNull);
    expect(fakeServer.devices[init.identity.deviceId]!['revokedAt'], isNull);
    expect(fakeServer.devices[idC.deviceId]!['revokedAt'], isNull);

    // Phone A can still send and Phone C can still sync
    await repoA.sendEncryptedEvent(
      eventType: 'thinking_of_you',
      body: <String, Object?>{'note': 'Ancora qui'},
    );
    final eventsOnC = await repoC.fetchAndDecryptEvents();
    expect(eventsOnC, hasLength(2));

    // 2. Phone A revokes Phone C remotely -> Phone C gets 401 -> unlinkCurrentDevice still clears Phone C
    await repoA.revokeDevice(idC.deviceId);
    await expectLater(
      repoC.fetchAndDecryptEvents(),
      throwsA(
        isA<ApiRequestException>().having(
          (ApiRequestException e) => e.isDeviceUnknownOrRevoked,
          'isDeviceUnknownOrRevoked',
          isTrue,
        ),
      ),
    );
    await repoC.unlinkCurrentDevice();
    expect(await repoC.loadIdentity(), isNull);
    expect(await storeC.read('deep_sky.offline_cache.v1'), isNull);

    // 3. Offline unlink still clears local identity & cache cleanly
    simulateOffline = true;
    await repoA.unlinkCurrentDevice();
    expect(await repoA.loadIdentity(), isNull);
    expect(await storeA.read('deep_sky.offline_cache.v1'), isNull);
  });

  test('CoupleApiClient sends version headers and surfaces 426 ClientUpgradeRequiredException (F-19)', () async {
    String? seenClientHeader;
    String? seenProtoHeader;
    final MockClient mockHttp = MockClient((http.Request req) async {
      seenClientHeader = req.headers['X-Client-Version-Code'];
      seenProtoHeader = req.headers['X-Protocol-Version'];
      return http.Response(
        jsonEncode(<String, Object?>{
          'code': 'CLIENT_UPGRADE_REQUIRED',
          'message': 'Please update Deep Sky.',
          'minClientVersionCode': 5,
          'minProtocolVersion': 2,
        }),
        426,
      );
    });

    final CoupleApiClient api = CoupleApiClient(
      baseUrl: 'https://test.local',
      httpClient: mockHttp,
      clientVersionCode: 3,
      protocolVersion: 1,
    );

    await expectLater(
      api.createInitialInvite(
        deviceLabel: 'Phone A',
        deviceAuthPublicKey: Uint8List(32),
        deviceKemPublicKey: Uint8List(32),
        recoveryAuthPublicKey: Uint8List(32),
      ),
      throwsA(
        isA<ClientUpgradeRequiredException>()
            .having(
              (ClientUpgradeRequiredException e) => e.minClientVersionCode,
              'minClientVersionCode',
              5,
            )
            .having(
              (ClientUpgradeRequiredException e) => e.minProtocolVersion,
              'minProtocolVersion',
              2,
            ),
      ),
    );
    expect(seenClientHeader, '3');
    expect(seenProtoHeader, '1');
  });
}

class _FakeServer {
  final Ed25519 _ed25519 = Ed25519();
  final Sha256 _sha256 = Sha256();

  int _idCounter = 1;
  int _seqCounter = 1;

  final Map<String, Map<String, Object?>> couples =
      <String, Map<String, Object?>>{};
  final Map<String, Map<String, Object?>> devices =
      <String, Map<String, Object?>>{};
  final Map<String, Map<String, Object?>> invites =
      <String, Map<String, Object?>>{};
  final Map<String, Map<String, Object?>> deliveries =
      <String, Map<String, Object?>>{};
  final Map<String, Map<String, Object?>> challenges =
      <String, Map<String, Object?>>{};
  final List<Map<String, Object?>> envelopes = <Map<String, Object?>>[];

  String _nextId() =>
      '00000000-0000-4000-8000-${(_idCounter++).toString().padLeft(12, '0')}';

  Future<http.Response> handle(http.Request req) async {
    final String path = req.url.path;
    final String method = req.method.toUpperCase();
    final String bodyText = req.body;
    final Map<String, Object?> bodyJson = bodyText.isEmpty
        ? <String, Object?>{}
        : jsonDecode(bodyText) as Map<String, Object?>;

    if (method == 'POST' && path == '/api/v1/pairing/invites') {
      final String coupleId = _nextId();
      final String deviceId = _nextId();
      final String token = 'tok-${_idCounter++}';
      couples[coupleId] = <String, Object?>{
        'coupleId': coupleId,
        'recoveryAuthPublicKeyB64': bodyJson['recoveryAuthPublicKeyB64'],
      };
      devices[deviceId] = <String, Object?>{
        'deviceId': deviceId,
        'coupleId': coupleId,
        'label': bodyJson['deviceLabel'],
        'authPublicKeyB64': bodyJson['deviceAuthPublicKeyB64'],
        'kemPublicKeyB64': bodyJson['deviceKemPublicKeyB64'],
        'enrolledVia': 'INVITE_INIT',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'revokedAt': null,
      };
      invites[token] = <String, Object?>{
        'coupleId': coupleId,
        'creatorDeviceId': deviceId,
        'acceptedDeviceId': null,
      };
      return _json(201, <String, Object?>{
        'coupleId': coupleId,
        'deviceId': deviceId,
        'inviteToken': token,
        'expiresAt': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 15))
            .toIso8601String(),
      });
    }

    if (method == 'POST' &&
        path.startsWith('/api/v1/pairing/invites/') &&
        path.endsWith('/accept')) {
      final String token = path.split('/')[5];
      final Map<String, Object?> inv = invites[token]!;
      final String coupleId = inv['coupleId']! as String;
      final String creatorId = inv['creatorDeviceId']! as String;
      final Map<String, Object?> creator = devices[creatorId]!;
      final String newDeviceId = _nextId();
      devices[newDeviceId] = <String, Object?>{
        'deviceId': newDeviceId,
        'coupleId': coupleId,
        'label': bodyJson['deviceLabel'],
        'authPublicKeyB64': bodyJson['deviceAuthPublicKeyB64'],
        'kemPublicKeyB64': bodyJson['deviceKemPublicKeyB64'],
        'enrolledVia': 'INVITE_JOIN',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'revokedAt': null,
      };
      inv['acceptedDeviceId'] = newDeviceId;
      return _json(200, <String, Object?>{
        'coupleId': coupleId,
        'deviceId': newDeviceId,
        'peerDeviceId': creatorId,
        'peerLabel': creator['label'],
        'peerAuthPublicKeyB64': creator['authPublicKeyB64'],
        'peerKemPublicKeyB64': creator['kemPublicKeyB64'],
      });
    }

    if (method == 'POST' && path == '/api/v1/recovery/challenges') {
      final String pub = bodyJson['recoveryAuthPublicKeyB64']! as String;
      final Map<String, Object?> couple = couples.values.firstWhere(
        (Map<String, Object?> c) => c['recoveryAuthPublicKeyB64'] == pub,
      );
      final String chalId = _nextId();
      final String nonceB64 = base64UrlEncode(utf8.encode('nonce-$chalId'));
      challenges[chalId] = <String, Object?>{
        'coupleId': couple['coupleId'],
        'nonceB64': nonceB64,
        'recoveryAuthPublicKeyB64': pub,
      };
      return _json(200, <String, Object?>{
        'challengeId': chalId,
        'coupleId': couple['coupleId'],
        'nonceB64': nonceB64,
        'expiresAt': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 5))
            .toIso8601String(),
      });
    }

    if (method == 'POST' && path == '/api/v1/recovery/complete') {
      final String chalId = bodyJson['challengeId']! as String;
      final Map<String, Object?> chal = challenges[chalId]!;
      final String coupleId = chal['coupleId']! as String;
      final String authPub = bodyJson['newDeviceAuthPublicKeyB64']! as String;
      final String kemPub = bodyJson['newDeviceKemPublicKeyB64']! as String;
      final String canonical =
          'deep-sky:recovery:v1|$coupleId|$chalId|${chal['nonceB64']}|$authPub|$kemPub';
      final bool ok = await _ed25519.verify(
        utf8.encode(canonical),
        signature: Signature(
          _decodeB64(bodyJson['recoverySignatureB64']! as String),
          publicKey: SimplePublicKey(
            _decodeB64(chal['recoveryAuthPublicKeyB64']! as String),
            type: KeyPairType.ed25519,
          ),
        ),
      );
      if (!ok) {
        return _json(401, <String, Object?>{'message': 'Invalid recovery sig'});
      }
      final String newDevId = _nextId();
      devices[newDevId] = <String, Object?>{
        'deviceId': newDevId,
        'coupleId': coupleId,
        'label': bodyJson['deviceLabel'],
        'authPublicKeyB64': authPub,
        'kemPublicKeyB64': kemPub,
        'enrolledVia': 'RECOVERY_KEY',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'revokedAt': null,
      };
      return _json(200, <String, Object?>{
        'coupleId': coupleId,
        'deviceId': newDevId,
      });
    }

    // Authenticated endpoints
    final String? deviceId = req.headers['X-Device-Id'];
    final Map<String, Object?>? dev = deviceId == null
        ? null
        : devices[deviceId];
    if (dev == null || dev['revokedAt'] != null) {
      return _json(401, <String, Object?>{
        'message': 'Device unknown or revoked',
      });
    }
    final Hash bodyHash = await _sha256.hash(req.bodyBytes);
    final String pathWithQuery =
        path + (req.url.hasQuery ? '?${req.url.query}' : '');
    final String canonical =
        '$method\n$pathWithQuery\n${req.headers['X-Timestamp']}\n${req.headers['X-Nonce']}\n${_toHex(bodyHash.bytes)}';
    final bool sigOk = await _ed25519.verify(
      utf8.encode(canonical),
      signature: Signature(
        _decodeB64(req.headers['X-Signature']!),
        publicKey: SimplePublicKey(
          _decodeB64(dev['authPublicKeyB64']! as String),
          type: KeyPairType.ed25519,
        ),
      ),
    );
    if (!sigOk) {
      return _json(401, <String, Object?>{'message': 'Invalid signature'});
    }
    final String coupleId = dev['coupleId']! as String;

    if (method == 'POST' && path == '/api/v1/pairing/enrollment-invites') {
      final String token = 'enroll-${_idCounter++}';
      invites[token] = <String, Object?>{
        'coupleId': coupleId,
        'creatorDeviceId': deviceId,
        'acceptedDeviceId': null,
      };
      return _json(201, <String, Object?>{
        'coupleId': coupleId,
        'deviceId': deviceId,
        'inviteToken': token,
        'expiresAt': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 15))
            .toIso8601String(),
      });
    }

    if (method == 'GET' &&
        path.startsWith('/api/v1/pairing/invites/') &&
        path.endsWith('/status')) {
      final String token = path.split('/')[5];
      final Map<String, Object?> inv = invites[token]!;
      final String? accId = inv['acceptedDeviceId'] as String?;
      if (accId == null) {
        return _json(200, <String, Object?>{'accepted': false});
      }
      final Map<String, Object?> accDev = devices[accId]!;
      return _json(200, <String, Object?>{
        'accepted': true,
        'acceptedDeviceId': accId,
        'acceptedLabel': accDev['label'],
        'acceptedAuthPublicKeyB64': accDev['authPublicKeyB64'],
        'acceptedKemPublicKeyB64': accDev['kemPublicKeyB64'],
      });
    }

    if (method == 'POST' && path == '/api/v1/pairing/key-deliveries') {
      final String toId = bodyJson['toDeviceId']! as String;
      deliveries[toId] = <String, Object?>{
        'coupleId': coupleId,
        'fromDeviceId': deviceId,
        'toDeviceId': toId,
        'nonceB64': bodyJson['nonceB64'],
        'ciphertextB64': bodyJson['ciphertextB64'],
      };
      return _json(201, null);
    }

    if (method == 'GET' && path == '/api/v1/pairing/key-deliveries/me') {
      return _json(200, deliveries[deviceId]!);
    }

    if (method == 'POST' &&
        path.startsWith('/api/v1/pairing/devices/') &&
        path.endsWith('/revoke')) {
      final String targetId = path.split('/')[5];
      devices[targetId]!['revokedAt'] = DateTime.now()
          .toUtc()
          .toIso8601String();
      return _json(204, null);
    }

    if (method == 'POST' && path == '/api/v1/sync/envelopes') {
      final Map<String, Object?> stored = <String, Object?>{
        'envelopeId': bodyJson['envelopeId'],
        'coupleId': coupleId,
        'senderDeviceId': deviceId,
        'seq': _seqCounter++,
        'channel': bodyJson['channel'],
        'keyEpoch': bodyJson['keyEpoch'],
        'nonceB64': bodyJson['nonceB64'],
        'ciphertextB64': bodyJson['ciphertextB64'],
        'createdAtServer': DateTime.now().toUtc().toIso8601String(),
      };
      envelopes.add(stored);
      return _json(201, stored);
    }

    if (method == 'GET' && path == '/api/v1/sync/envelopes') {
      final int afterSeq =
          int.tryParse(req.url.queryParameters['afterSeq'] ?? '0') ?? 0;
      final List<Map<String, Object?>> list = envelopes
          .where(
            (Map<String, Object?> e) =>
                e['coupleId'] == coupleId && (e['seq']! as int) > afterSeq,
          )
          .toList();
      return _json(200, list);
    }

    return _json(404, <String, Object?>{'message': 'Not found: $method $path'});
  }

  static http.Response _json(int status, Object? body) {
    return http.Response(
      body == null ? '' : jsonEncode(body),
      status,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }

  static Uint8List _decodeB64(String v) {
    final int rem = v.length % 4;
    return Uint8List.fromList(
      base64Url.decode(rem == 0 ? v : v.padRight(v.length + (4 - rem), '=')),
    );
  }

  static String _toHex(List<int> bytes) {
    final StringBuffer sb = StringBuffer();
    for (final int b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
