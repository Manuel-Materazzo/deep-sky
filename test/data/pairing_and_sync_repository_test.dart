import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/data/couple_api_client.dart';
import 'package:deep_sky/data/encrypted_local_cache.dart';
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
    final List<String> recordedWireTraffic = <String>[];
    final MockClient mockHttp = MockClient((http.Request req) {
      recordedWireTraffic.add(
        '${req.method} ${req.url} ${req.headers} ${req.body}',
      );
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
    expect(init.invite.sasSecret, isNotEmpty);
    final PendingJoinSession joinSession = await repoB.acceptInvite(
      serverUrl: 'https://test.local',
      inviteToken: init.invite.inviteToken,
      sasSecret: init.invite.sasSecret!,
      deviceLabel: 'Phone B',
    );
    final status = await repoA.checkInviteAndSas(
      init.invite.inviteToken,
      sasSecret: init.invite.sasSecret,
    );
    expect(status.status.accepted, isTrue);
    expect(status.sasCode, equals(joinSession.sasCode));
    expect(
      recordedWireTraffic.join('\n').contains(init.invite.sasSecret!),
      isFalse,
    );

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
      sasSecret: enrollInvite.sasSecret!,
      deviceLabel: 'New Phone B2',
    );
    final enrollStatus = await repoA.checkInviteAndSas(
      enrollInvite.inviteToken,
      sasSecret: enrollInvite.sasSecret,
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

    // 7. Device revocation (CA-02): Device A revokes Device B -> epoch rotates to 2,
    //    surviving Device B2 catches up automatically, reads epoch 1 + epoch 2 history,
    //    and pre-revocation epoch-1 seed cannot decrypt epoch-2 envelopes or recover.
    final Uint8List preRevocationSeed = Uint8List.fromList(
      init.identity.recoverySeed!,
    );
    await repoA.revokeDevice(idB.deviceId);
    await expectLater(
      repoB.fetchAndDecryptEvents(),
      throwsA(isA<ApiRequestException>()),
    );

    final LocalDeviceIdentity? rotatedA = await repoA.loadIdentity();
    expect(rotatedA?.currentKeyEpoch, 2);
    expect(rotatedA?.recoverySavedConfirmed, isFalse);
    await repoA.confirmRecoveryKeySaved();
    await repoA.sendEncryptedEvent(
      eventType: 'thinking_of_you',
      body: <String, Object?>{'note': 'Post-rotation secret'},
    );

    final List<DecryptedEventRecord> eventsOnB2 = await repoB2
        .fetchAndDecryptEvents();
    expect(eventsOnB2, hasLength(2));
    expect(eventsOnB2[0].envelope.keyEpoch, 1);
    expect(eventsOnB2[0].payload.body['title'], 'Anniversario');
    expect(eventsOnB2[1].envelope.keyEpoch, 2);
    expect(eventsOnB2[1].payload.body['note'], 'Post-rotation secret');

    // Revoked phone holding pre-revocation epoch-1 keys cannot decrypt epoch-2 envelope
    final Uint8List staleRootKey = await crypto.deriveCoupleRootKey(
      preRevocationSeed,
    );
    await expectLater(
      crypto.decryptEnvelope(
        rootKey: staleRootKey,
        expectedCoupleId: init.identity.coupleId,
        envelope: eventsOnB2[1].envelope,
      ),
      throwsA(isA<FormatException>()),
    );

    // Pre-revocation 24 words can no longer recover; rotated 24 words restore epochs 1 + 2
    await expectLater(
      makeRepo(InMemorySecureKeyStore()).recoverWithRecoveryKey(
        serverUrl: 'https://test.local',
        recoveryInput: RecoveryKeyCodec.toSentence(preRevocationSeed),
        deviceLabel: 'Stale Thief',
      ),
      throwsA(anything),
    );
    final PairingAndSyncRepository repoR2 = makeRepo(InMemorySecureKeyStore());
    await repoR2.recoverWithRecoveryKey(
      serverUrl: 'https://test.local',
      recoveryInput: RecoveryKeyCodec.toSentence(rotatedA!.recoverySeed!),
      deviceLabel: 'Recovered After Rotation',
    );
    final List<DecryptedEventRecord> r2Events = await repoR2
        .fetchAndDecryptEvents();
    expect(r2Events.map((e) => e.payload.body.values.first), <Object?>[
      'Anniversario',
      'Post-rotation secret',
    ]);
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

  test('AU-02: write-ahead epoch rotation survives lost HTTP response and app restart', () async {
    final _FakeServer fakeServer = _FakeServer();
    bool dropRevokeResponseAfterCommit = false;
    bool keepOfflineOnReconcile = false;
    final MockClient mockHttp = MockClient((http.Request req) async {
      final http.Response res = await fakeServer.handle(req);
      if (dropRevokeResponseAfterCommit &&
          req.method == 'POST' &&
          req.url.path.endsWith('/revoke')) {
        // Server already committed epoch 2, but network drops before client sees 204.
        dropRevokeResponseAfterCommit = false;
        throw const SocketException('Connection reset after commit');
      }
      if (keepOfflineOnReconcile &&
          req.method == 'GET' &&
          req.url.path == '/api/v1/pairing/epoch-rotations/me') {
        throw TimeoutException('Still offline during immediate reconcile');
      }
      return res;
    });
    final DeepSkyCrypto crypto = DeepSkyCrypto();
    final InMemorySecureKeyStore storeA = InMemorySecureKeyStore();
    final InMemorySecureKeyStore storeB = InMemorySecureKeyStore();

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

    final PairingAndSyncRepository repoA = makeRepo(storeA);
    final PairingAndSyncRepository repoB = makeRepo(storeB);

    final init = await repoA.createInitialInvite(
      serverUrl: 'https://test.local',
      deviceLabel: 'Phone A',
    );
    final PendingJoinSession joinB = await repoB.acceptInvite(
      serverUrl: 'https://test.local',
      inviteToken: init.invite.inviteToken,
      sasSecret: init.invite.sasSecret!,
      deviceLabel: 'Phone B',
    );
    final status = await repoA.checkInviteAndSas(
      init.invite.inviteToken,
      sasSecret: init.invite.sasSecret,
    );
    await repoA.confirmSasAndDeliverRootKey(
      targetDeviceId: status.status.acceptedDeviceId!,
      targetKemPublicKey: status.status.acceptedKemPublicKey!,
    );
    final LocalDeviceIdentity idB = await repoB.completeKeyDelivery(
      session: joinB,
    );

    // Case 1: Revoke commits on server, response drops, immediate reconcile fails (simulating crash/offline).
    dropRevokeResponseAfterCommit = true;
    keepOfflineOnReconcile = true;
    await expectLater(
      repoA.revokeDevice(idB.deviceId),
      throwsA(isA<SocketException>()),
    );
    // Pending rotation must remain persisted in storeA, while identity is still epoch 1.
    expect((await repoA.loadIdentity())?.currentKeyEpoch, 1);
    expect(await storeA.read('deep_sky.pending_rotation.v1'), isNotNull);

    // Simulate app restart with a fresh repository instance once network returns.
    keepOfflineOnReconcile = false;
    final PairingAndSyncRepository restartedRepoA = makeRepo(storeA);
    final LocalDeviceIdentity? reconciled = await restartedRepoA
        .reconcilePendingRotation();
    expect(reconciled, isNotNull);
    expect(reconciled!.currentKeyEpoch, 2);
    expect(reconciled.recoverySeed, isNot(equals(init.identity.recoverySeed)));
    expect(await storeA.read('deep_sky.pending_rotation.v1'), isNull);

    // Reconciled initiator can immediately upload at epoch 2 and recover using the new seed!
    await restartedRepoA.sendEncryptedEvent(
      eventType: 'thinking_of_you',
      body: <String, Object?>{'note': 'Recovered after drop'},
    );
    final PairingAndSyncRepository recoveredRepo = makeRepo(
      InMemorySecureKeyStore(),
    );
    await recoveredRepo.recoverWithRecoveryKey(
      serverUrl: 'https://test.local',
      recoveryInput: RecoveryKeyCodec.toSentence(reconciled.recoverySeed!),
      deviceLabel: 'New Phone',
    );
    final List<DecryptedEventRecord> events = await recoveredRepo
        .fetchAndDecryptEvents();
    expect(events, hasLength(1));
    expect(events.first.payload.body['note'], 'Recovered after drop');
  });

  group('AU-02 follow-up: rotation promotion, retry guard and mutex', () {
    Future<
      ({
        _FakeServer server,
        InMemorySecureKeyStore storeA,
        PairingAndSyncRepository Function(InMemorySecureKeyStore) makeRepo,
        PairingAndSyncRepository repoA,
        PairingAndSyncRepository repoB,
        LocalDeviceIdentity idA,
        LocalDeviceIdentity idB,
        LocalDeviceIdentity idC,
      })
    >
    pairThree(MockClient Function(_FakeServer) mockFor) async {
      final _FakeServer server = _FakeServer();
      final MockClient mockHttp = mockFor(server);
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
      final PairingAndSyncRepository repoA = makeRepo(storeA);
      final PairingAndSyncRepository repoB = makeRepo(InMemorySecureKeyStore());
      final PairingAndSyncRepository repoC = makeRepo(InMemorySecureKeyStore());

      final init = await repoA.createInitialInvite(
        serverUrl: 'https://test.local',
        deviceLabel: 'Phone A',
      );
      final PendingJoinSession joinB = await repoB.acceptInvite(
        serverUrl: 'https://test.local',
        inviteToken: init.invite.inviteToken,
        sasSecret: init.invite.sasSecret!,
        deviceLabel: 'Phone B',
      );
      final st = await repoA.checkInviteAndSas(
        init.invite.inviteToken,
        sasSecret: init.invite.sasSecret,
      );
      await repoA.confirmSasAndDeliverRootKey(
        targetDeviceId: st.status.acceptedDeviceId!,
        targetKemPublicKey: st.status.acceptedKemPublicKey!,
      );
      final LocalDeviceIdentity idB = await repoB.completeKeyDelivery(
        session: joinB,
      );

      final CreateInviteResponse enroll = await repoA.createEnrollmentInvite();
      final PendingJoinSession joinC = await repoC.acceptInvite(
        serverUrl: 'https://test.local',
        inviteToken: enroll.inviteToken,
        sasSecret: enroll.sasSecret!,
        deviceLabel: 'Phone C',
      );
      final st2 = await repoA.checkInviteAndSas(
        enroll.inviteToken,
        sasSecret: enroll.sasSecret,
      );
      await repoA.confirmSasAndDeliverRootKey(
        targetDeviceId: st2.status.acceptedDeviceId!,
        targetKemPublicKey: st2.status.acceptedKemPublicKey!,
      );
      final LocalDeviceIdentity idC = await repoC.completeKeyDelivery(
        session: joinC,
      );
      return (
        server: server,
        storeA: storeA,
        makeRepo: makeRepo,
        repoA: repoA,
        repoB: repoB,
        idA: init.identity,
        idB: idB,
        idC: idC,
      );
    }

    Future<String> serverRecoveryAuthPub(Uint8List seed) async {
      final SimpleKeyPair kp = await DeepSkyCrypto().deriveRecoveryAuthKeyPair(
        seed,
      );
      return base64UrlEncode((await kp.extractPublicKey()).bytes);
    }

    test('promotes committed rotation when an older EPOCH_ROTATION delivery exists for this device', () async {
      bool dropNextRevokeResponse = false;
      bool offlineOnReconcile = false;
      final f = await pairThree(
        (_FakeServer server) => MockClient((http.Request req) async {
          final http.Response res = await server.handle(req);
          if (dropNextRevokeResponse &&
              req.method == 'POST' &&
              req.url.path.endsWith('/revoke')) {
            dropNextRevokeResponse = false;
            throw const SocketException('reset after commit');
          }
          if (offlineOnReconcile &&
              req.url.path == '/api/v1/pairing/epoch-rotations/me') {
            throw TimeoutException('offline');
          }
          return res;
        }),
      );

      // B revokes C first: A receives an EPOCH_ROTATION delivery at epoch 2.
      await f.repoB.revokeDevice(f.idC.deviceId);
      await f.repoA.sendEncryptedEvent(
        eventType: 'thinking_of_you',
        body: <String, Object?>{'note': 'adopt epoch 2'},
      );
      expect((await f.repoA.loadIdentity())!.currentKeyEpoch, 2);
      expect(f.server.deliveries['epoch:${f.idA.deviceId}'], isNotNull);

      // A now revokes B; server commits epoch 3 but the response is lost.
      dropNextRevokeResponse = true;
      offlineOnReconcile = true;
      await expectLater(
        f.repoA.revokeDevice(f.idB.deviceId),
        throwsA(isA<SocketException>()),
      );
      expect(await f.storeA.read('deep_sky.pending_rotation.v1'), isNotNull);
      expect((await f.repoA.loadIdentity())!.currentKeyEpoch, 2);

      offlineOnReconcile = false;
      final LocalDeviceIdentity? promoted = await f.repoA
          .reconcilePendingRotation();
      expect(promoted!.currentKeyEpoch, 3);
      expect(await f.storeA.read('deep_sky.pending_rotation.v1'), isNull);
      final String couplePub =
          f.server.couples.values.single['recoveryAuthPublicKeyB64']! as String;
      expect(await serverRecoveryAuthPub(promoted.recoverySeed!), couplePub);
    });

    test('retry after lost response does not generate new keys and keeps committed ones', () async {
      bool dropNextRevokeResponse = false;
      bool offline = false;
      int revokePosts = 0;
      final f = await pairThree(
        (_FakeServer server) => MockClient((http.Request req) async {
          if (offline && req.url.path == '/api/v1/pairing/epoch-rotations/me') {
            throw TimeoutException('offline');
          }
          final http.Response res = await server.handle(req);
          if (req.method == 'POST' && req.url.path.endsWith('/revoke')) {
            revokePosts++;
            if (dropNextRevokeResponse) {
              dropNextRevokeResponse = false;
              throw const SocketException('reset after commit');
            }
          }
          return res;
        }),
      );

      dropNextRevokeResponse = true;
      offline = true;
      await expectLater(
        f.repoA.revokeDevice(f.idC.deviceId),
        throwsA(isA<SocketException>()),
      );
      final String? pendingRaw = await f.storeA.read(
        'deep_sky.pending_rotation.v1',
      );
      expect(pendingRaw, isNotNull);

      // Retry while the server state is still unknown: calm typed or network
      // error, no new keys, pending record untouched.
      await expectLater(
        f.repoA.revokeDevice(f.idC.deviceId),
        throwsA(isA<TimeoutException>()),
      );
      expect(await f.storeA.read('deep_sky.pending_rotation.v1'), pendingRaw);
      expect(revokePosts, 1);

      // Network back: retry resolves the committed rotation without a new POST.
      offline = false;
      final LocalDeviceIdentity result = await f.repoA.revokeDevice(
        f.idC.deviceId,
      );
      expect(revokePosts, 1);
      expect(result.currentKeyEpoch, 2);
      expect(await f.storeA.read('deep_sky.pending_rotation.v1'), isNull);
      final Map<String, Object?> pending =
          jsonDecode(pendingRaw!) as Map<String, Object?>;
      expect(base64UrlEncode(result.recoverySeed!), pending['recoverySeedB64']);
      final String couplePub =
          f.server.couples.values.single['recoveryAuthPublicKeyB64']! as String;
      expect(await serverRecoveryAuthPub(result.recoverySeed!), couplePub);

      // Partner B can adopt epoch 2 and A decrypts what B sends there.
      await f.repoB.sendEncryptedEvent(
        eventType: 'thinking_of_you',
        body: <String, Object?>{'note': 'hello at epoch 2'},
      );
      final List<DecryptedEventRecord> events = await f.repoA
          .fetchAndDecryptEvents();
      expect(events.map((e) => e.payload.body['note']), <Object?>[
        'hello at epoch 2',
      ]);
      expect(events.single.envelope.keyEpoch, 2);
    });

    test('reconcile running while revoke is in flight waits and does not delete the pending record', () async {
      final Completer<void> gate = Completer<void>();
      bool gateRevoke = false;
      final List<String> epochRotationGets = <String>[];
      final f = await pairThree(
        (_FakeServer server) => MockClient((http.Request req) async {
          if (req.url.path == '/api/v1/pairing/epoch-rotations/me') {
            epochRotationGets.add(req.url.path);
          }
          if (gateRevoke &&
              req.method == 'POST' &&
              req.url.path.endsWith('/revoke')) {
            await gate.future;
          }
          return server.handle(req);
        }),
      );

      gateRevoke = true;
      final Future<LocalDeviceIdentity> revoking = f.repoA.revokeDevice(
        f.idB.deviceId,
      );
      // Let the revoke reach the (blocked) HTTP call.
      for (int i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(await f.storeA.read('deep_sky.pending_rotation.v1'), isNotNull);
      epochRotationGets.clear();

      final Future<LocalDeviceIdentity?> reconciling = f.repoA
          .reconcilePendingRotation();
      for (int i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      // The concurrent reconcile must not have queried the server nor
      // dropped the write-ahead record.
      expect(epochRotationGets, isEmpty);
      expect(await f.storeA.read('deep_sky.pending_rotation.v1'), isNotNull);

      gate.complete();
      final LocalDeviceIdentity rotated = await revoking;
      final LocalDeviceIdentity? after = await reconciling;
      expect(rotated.currentKeyEpoch, 2);
      expect(after!.currentKeyEpoch, 2);
      expect(await f.storeA.read('deep_sky.pending_rotation.v1'), isNull);
      expect(
        (await f.repoA.loadIdentity())!.recoverySeed,
        orderedEquals(rotated.recoverySeed!),
      );
    });
  });

  test('AU-04: quarantined envelope is retried after app restart (cursor not advanced past it)', () async {
    final _FakeServer fakeServer = _FakeServer();
    final MockClient mockHttp = MockClient(
      (http.Request req) => fakeServer.handle(req),
    );
    final DeepSkyCrypto crypto = DeepSkyCrypto();
    final InMemorySecureKeyStore store = InMemorySecureKeyStore();
    PairingAndSyncRepository makeRepo() => PairingAndSyncRepository(
      keyStore: store,
      crypto: crypto,
      clientFactory: (String url) =>
          CoupleApiClient(baseUrl: url, httpClient: mockHttp, crypto: crypto),
    );
    final PairingAndSyncRepository repo = makeRepo();
    final init = await repo.createInitialInvite(
      serverUrl: 'https://test.local',
      deviceLabel: 'Phone A',
    );
    await repo.sendEncryptedEvent(
      eventType: 'thinking_of_you',
      body: <String, Object?>{'note': 'valid 1'},
    );
    // The corrupted envelope sits in the MIDDLE of the timeline: a later valid
    // envelope must not drag the persisted cursor past it.
    final int corruptedSeq = fakeServer._seqCounter++;
    fakeServer.envelopes.add(<String, Object?>{
      'envelopeId': 'corrupted-env-2',
      'coupleId': init.identity.coupleId,
      'senderDeviceId': init.identity.deviceId,
      'seq': corruptedSeq,
      'channel': 'EVENT',
      'keyEpoch': 1,
      'nonceB64': base64UrlEncode(List<int>.filled(24, 1)),
      'ciphertextB64': base64UrlEncode(List<int>.filled(48, 2)),
      'createdAtServer': DateTime.now().toUtc().toIso8601String(),
    });
    await repo.sendEncryptedEvent(
      eventType: 'thinking_of_you',
      body: <String, Object?>{'note': 'valid 2'},
    );

    final SyncEventsSnapshot first = await repo.syncEventsWithOfflineFallback();
    expect(first.quarantinedEnvelopes, hasLength(1));
    final CachedEventsSnapshot cached = await repo.loadCachedSnapshot();
    expect(
      cached.events.map((e) => e.seq ?? 0).reduce((a, b) => a > b ? a : b),
      greaterThan(corruptedSeq),
    );
    expect(cached.lastSeq, lessThan(corruptedSeq));

    // App restart: in-memory quarantine list is gone, persisted cursor must
    // still cause the bad envelope to be fetched (and reported) again.
    final PairingAndSyncRepository restarted = makeRepo();
    final SyncEventsSnapshot second = await restarted
        .syncEventsWithOfflineFallback();
    expect(second.quarantinedEnvelopes.map((q) => q.envelopeId), <String>[
      'corrupted-env-2',
    ]);
    expect(second.events, hasLength(2));
  });

  test('ApiRequestException.isClockSkew only falls back to message text without an errorCode', () {
    expect(const ApiRequestException(401, 'Bad timestamp').isClockSkew, isTrue);
    expect(
      const ApiRequestException(
        401,
        'Malformed X-Device-Id or X-Timestamp',
        errorCode: 'AUTH_HEADERS_INVALID',
      ).isClockSkew,
      isFalse,
    );
    expect(
      const ApiRequestException(
        401,
        'skew',
        errorCode: 'CLOCK_SKEW',
      ).isClockSkew,
      isTrue,
    );
  });

  test('AU-04: single corrupted envelope is quarantined without breaking timeline sync', () async {
    final _FakeServer fakeServer = _FakeServer();
    final MockClient mockHttp = MockClient(
      (http.Request req) => fakeServer.handle(req),
    );
    final DeepSkyCrypto crypto = DeepSkyCrypto();
    final PairingAndSyncRepository repoA = PairingAndSyncRepository(
      keyStore: InMemorySecureKeyStore(),
      crypto: crypto,
      clientFactory: (String url) =>
          CoupleApiClient(baseUrl: url, httpClient: mockHttp, crypto: crypto),
    );

    final init = await repoA.createInitialInvite(
      serverUrl: 'https://test.local',
      deviceLabel: 'Phone A',
    );
    await repoA.sendEncryptedEvent(
      eventType: 'thinking_of_you',
      body: <String, Object?>{'note': 'First valid'},
    );
    // Inject a corrupted envelope directly into the server history
    fakeServer.envelopes.add(<String, Object?>{
      'envelopeId': 'corrupted-env-1',
      'coupleId': init.identity.coupleId,
      'senderDeviceId': init.identity.deviceId,
      'seq': 99,
      'channel': 'EVENT',
      'keyEpoch': 1,
      'nonceB64': base64UrlEncode(List<int>.filled(24, 1)),
      'ciphertextB64': base64UrlEncode(List<int>.filled(48, 2)),
      'createdAtServer': DateTime.now().toUtc().toIso8601String(),
    });
    await repoA.sendEncryptedEvent(
      eventType: 'thinking_of_you',
      body: <String, Object?>{'note': 'Second valid'},
    );

    final SyncEventsSnapshot snap = await repoA.syncEventsWithOfflineFallback();
    expect(snap.isOffline, isFalse);
    expect(snap.events, hasLength(2));
    expect(snap.events.map((e) => e.payload.body['note']), <Object?>[
      'First valid',
      'Second valid',
    ]);
    expect(snap.quarantinedEnvelopes, hasLength(1));
    expect(snap.quarantinedEnvelopes.first.envelopeId, 'corrupted-env-1');
  });

  test(
    'AU-06: stalled HTTP request times out and triggers offline fallback',
    () async {
      final _FakeServer fakeServer = _FakeServer();
      bool stallSync = false;
      final MockClient mockHttp = MockClient((http.Request req) async {
        if (stallSync && req.url.path == '/api/v1/sync/envelopes') {
          await Future<void>.delayed(const Duration(seconds: 5));
        }
        return fakeServer.handle(req);
      });
      final DeepSkyCrypto crypto = DeepSkyCrypto();
      final PairingAndSyncRepository repoA = PairingAndSyncRepository(
        keyStore: InMemorySecureKeyStore(),
        crypto: crypto,
        clientFactory: (String url) => CoupleApiClient(
          baseUrl: url,
          httpClient: mockHttp,
          crypto: crypto,
          requestTimeout: const Duration(milliseconds: 50),
        ),
      );

      await repoA.createInitialInvite(
        serverUrl: 'https://test.local',
        deviceLabel: 'Phone A',
      );
      await repoA.sendEncryptedEvent(
        eventType: 'thinking_of_you',
        body: <String, Object?>{'note': 'Cached before stall'},
      );
      await repoA.syncEventsWithOfflineFallback();

      stallSync = true;
      final SyncEventsSnapshot offlineSnap = await repoA
          .syncEventsWithOfflineFallback();
      expect(offlineSnap.isOffline, isTrue);
      expect(offlineSnap.events, hasLength(1));
      expect(
        offlineSnap.events.first.payload.body['note'],
        'Cached before stall',
      );
    },
  );

  test('AU-05: incremental sync uses persisted lastSeq and encrypted file-backed cache', () async {
    final _FakeServer fakeServer = _FakeServer();
    final List<String> syncQueries = <String>[];
    final MockClient mockHttp = MockClient((http.Request req) {
      if (req.method == 'GET' && req.url.path == '/api/v1/sync/envelopes') {
        syncQueries.add(req.url.query);
      }
      return fakeServer.handle(req);
    });
    final Directory cacheDir = Directory.systemTemp.createTempSync(
      'deepsky_cache_',
    );
    addTearDown(() => cacheDir.deleteSync(recursive: true));

    final DeepSkyCrypto crypto = DeepSkyCrypto();
    final InMemorySecureKeyStore keyStore = InMemorySecureKeyStore();
    final PairingAndSyncRepository repoA = PairingAndSyncRepository(
      keyStore: keyStore,
      crypto: crypto,
      clientFactory: (String url) =>
          CoupleApiClient(baseUrl: url, httpClient: mockHttp, crypto: crypto),
      localCache: EncryptedLocalCache(
        keyStore: keyStore,
        resolveCacheRootDir: () async => cacheDir.path,
      ),
    );

    await repoA.createInitialInvite(
      serverUrl: 'https://test.local',
      deviceLabel: 'Phone A',
    );
    await repoA.sendEncryptedEvent(
      eventType: 'thinking_of_you',
      body: <String, Object?>{'note': 'First message'},
    );

    final SyncEventsSnapshot snap1 = await repoA
        .syncEventsWithOfflineFallback();
    expect(snap1.events, hasLength(1));
    expect(syncQueries.last, contains('afterSeq=0'));
    // Encrypted file exists on disk and SharedPreferences key stays empty
    final File encFile = File(
      '${cacheDir.path}${Platform.pathSeparator}offline_events.v1.enc',
    );
    expect(encFile.existsSync(), isTrue);
    expect(await keyStore.read('deep_sky.offline_cache.v1'), isNull);
    expect(encFile.readAsStringSync().contains('First message'), isFalse);

    await repoA.sendEncryptedEvent(
      eventType: 'thinking_of_you',
      body: <String, Object?>{'note': 'Second message'},
    );
    final SyncEventsSnapshot snap2 = await repoA
        .syncEventsWithOfflineFallback();
    expect(snap2.events, hasLength(2));
    expect(syncQueries.last, contains('afterSeq=1'));
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
      sasSecret: init.invite.sasSecret!,
      deviceLabel: 'Phone B',
    );
    final status = await repoA.checkInviteAndSas(
      init.invite.inviteToken,
      sasSecret: init.invite.sasSecret,
    );
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
        'currentKeyEpoch': 1,
        'recoveryKeyringNonceB64': null,
        'recoveryKeyringCiphertextB64': null,
      };
      devices[deviceId] = <String, Object?>{
        'deviceId': deviceId,
        'coupleId': coupleId,
        'label': bodyJson['deviceLabel'],
        'authPublicKeyB64': bodyJson['deviceAuthPublicKeyB64'],
        'kemPublicKeyB64': bodyJson['deviceKemPublicKeyB64'],
        'enrolledVia': 'INVITE_INIT',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'approved': true,
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

    if (method == 'POST' && path == '/api/v1/pairing/invites/accept') {
      final String token = bodyJson['inviteToken']! as String;
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
        'approved': false,
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
        'approved': true,
        'revokedAt': null,
      };
      final Map<String, Object?> couple = couples[coupleId]!;
      return _json(200, <String, Object?>{
        'coupleId': coupleId,
        'deviceId': newDevId,
        'currentKeyEpoch': couple['currentKeyEpoch'],
        'recoveryKeyringNonceB64': couple['recoveryKeyringNonceB64'],
        'recoveryKeyringCiphertextB64': couple['recoveryKeyringCiphertextB64'],
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

    if (method == 'POST' && path == '/api/v1/pairing/invites/status') {
      final String token = bodyJson['inviteToken']! as String;
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
      devices[toId]!['approved'] = true;
      deliveries[toId] = <String, Object?>{
        'coupleId': coupleId,
        'fromDeviceId': deviceId,
        'toDeviceId': toId,
        'nonceB64': bodyJson['nonceB64'],
        'ciphertextB64': bodyJson['ciphertextB64'],
        'deliveryKind': 'PAIRING_SEED',
        'keyEpoch':
            bodyJson['keyEpoch'] ?? couples[coupleId]!['currentKeyEpoch'],
      };
      return _json(201, null);
    }

    if (method == 'GET' && path == '/api/v1/pairing/key-deliveries/me') {
      return _json(200, deliveries[deviceId]!);
    }

    if (method == 'GET' && path == '/api/v1/pairing/devices') {
      return _json(
        200,
        devices.values
            .where((Map<String, Object?> d) => d['coupleId'] == coupleId)
            .toList(),
      );
    }

    if (method == 'GET' && path == '/api/v1/pairing/epoch-rotations/me') {
      final Map<String, Object?> couple = couples[coupleId]!;
      return _json(200, <String, Object?>{
        'currentKeyEpoch': couple['currentKeyEpoch'],
        'pendingDelivery': deliveries['epoch:$deviceId'],
      });
    }

    if (method == 'POST' &&
        path.startsWith('/api/v1/pairing/devices/') &&
        path.endsWith('/revoke')) {
      final String targetId = path.split('/')[5];
      if (bodyJson.isNotEmpty) {
        // Like the real server: a rotation must target exactly current + 1.
        final int currentEpoch = couples[coupleId]!['currentKeyEpoch']! as int;
        if (bodyJson['targetEpoch'] != currentEpoch + 1) {
          return _json(409, <String, Object?>{
            'code': 'STALE_KEY_EPOCH',
            'message': 'Epoch rotation target must be current + 1',
          });
        }
      }
      devices[targetId]!['revokedAt'] = DateTime.now()
          .toUtc()
          .toIso8601String();
      if (bodyJson.isNotEmpty) {
        final Map<String, Object?> couple = couples[coupleId]!;
        final int targetEpoch = bodyJson['targetEpoch']! as int;
        couple['currentKeyEpoch'] = targetEpoch;
        couple['recoveryAuthPublicKeyB64'] =
            bodyJson['newRecoveryAuthPublicKeyB64'];
        couple['recoveryKeyringNonceB64'] = bodyJson['recoveryKeyringNonceB64'];
        couple['recoveryKeyringCiphertextB64'] =
            bodyJson['recoveryKeyringCiphertextB64'];
        final List<Object?> items =
            bodyJson['deliveries'] as List<Object?>? ?? const <Object?>[];
        for (final Object? rawItem in items) {
          final Map<String, Object?> item = rawItem! as Map<String, Object?>;
          final String toId = item['toDeviceId']! as String;
          deliveries['epoch:$toId'] = <String, Object?>{
            'coupleId': coupleId,
            'fromDeviceId': deviceId,
            'toDeviceId': toId,
            'nonceB64': item['nonceB64'],
            'ciphertextB64': item['ciphertextB64'],
            'deliveryKind': 'EPOCH_ROTATION',
            'keyEpoch': targetEpoch,
          };
        }
      }
      return _json(204, null);
    }

    if (method == 'POST' && path == '/api/v1/sync/envelopes') {
      final int coupleEpoch = couples[coupleId]!['currentKeyEpoch']! as int;
      final int envEpoch = bodyJson['keyEpoch']! as int;
      if (envEpoch < coupleEpoch) {
        return _json(409, <String, Object?>{
          'code': 'STALE_KEY_EPOCH',
          'message': 'Envelope keyEpoch is older than couple active epoch',
        });
      }
      final Map<String, Object?> stored = <String, Object?>{
        'envelopeId': bodyJson['envelopeId'],
        'coupleId': coupleId,
        'senderDeviceId': deviceId,
        'seq': _seqCounter++,
        'channel': bodyJson['channel'],
        'keyEpoch': envEpoch,
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
      final int limit =
          int.tryParse(req.url.queryParameters['limit'] ?? '100') ?? 100;
      final List<Map<String, Object?>> matching = envelopes
          .where(
            (Map<String, Object?> e) =>
                e['coupleId'] == coupleId && (e['seq']! as int) > afterSeq,
          )
          .toList();
      final bool hasMore = matching.length > limit;
      final List<Map<String, Object?>> page = hasMore
          ? matching.sublist(0, limit)
          : matching;
      final int nextAfterSeq = page.isEmpty
          ? afterSeq
          : page.last['seq']! as int;
      return _json(200, <String, Object?>{
        'items': page,
        'nextAfterSeq': nextAfterSeq,
        'hasMore': hasMore,
        'coupleKeyEpoch': couples[coupleId]!['currentKeyEpoch'],
      });
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
