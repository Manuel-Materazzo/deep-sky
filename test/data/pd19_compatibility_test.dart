import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/data/couple_api_client.dart';
import 'package:deep_sky/data/pairing_and_sync_repository.dart';
import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/domain/crypto/deep_sky_crypto.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Automated n-1 <-> n compatibility tests (`PD-19`, `S1-QA-01`).
void main() {
  test('PD-19: n client loads n-1 LocalDeviceIdentity, unwraps legacy v1 key delivery, and reads n-1 + n JSON payloads', () async {
    final DeepSkyCrypto crypto = DeepSkyCrypto();
    final SimpleKeyPair authKp = await crypto.generateDeviceAuthKeyPair();
    final SimpleKeyPair kemKp = await crypto.generateDeviceKemKeyPair();
    final SimpleKeyPair peerKemKp = await crypto.generateDeviceKemKeyPair();
    final Uint8List recoverySeed = crypto.generateRecoverySeed();
    final Uint8List root1 = await crypto.deriveCoupleRootKey(recoverySeed);

    // Simulate persisted n-1 LocalDeviceIdentity JSON (no currentKeyEpoch or epochSecretsB64)
    final Map<String, Object?> legacyIdentityJson = <String, Object?>{
      'serverUrl': 'https://test.local',
      'coupleId': '11111111-1111-4111-8111-111111111111',
      'deviceId': '22222222-2222-4222-8222-222222222222',
      'deviceLabel': 'Legacy Phone',
      'authPrivateKeySeedB64': base64UrlEncode(
        await authKp.extractPrivateKeyBytes(),
      ),
      'authPublicKeyB64': base64UrlEncode(
        (await authKp.extractPublicKey()).bytes,
      ),
      'kemPrivateKeyB64': base64UrlEncode(await kemKp.extractPrivateKeyBytes()),
      'kemPublicKeyB64': base64UrlEncode(
        (await kemKp.extractPublicKey()).bytes,
      ),
      'recoverySeedB64': base64UrlEncode(recoverySeed),
      'recoverySavedConfirmed': true,
      'pairingCompleted': true,
      'nameSetupCompleted': true,
    };
    final LocalDeviceIdentity loaded = LocalDeviceIdentity.fromJson(
      legacyIdentityJson,
    );
    expect(loaded.currentKeyEpoch, 1);
    expect(loaded.epochSecrets, isEmpty);
    expect(loaded.hasCoupleRoot, isTrue);

    // Legacy v1 WrappedKeyPackage JSON (no keyEpoch / deliveryKind) unwraps to epoch 1 bundle
    final Uint8List shared = await crypto.computeSharedSecret(
      myKemKeyPair: peerKemKp,
      peerKemPublicKey: loaded.kemPublicKey,
    );
    final WrappedKeyPackage v1Pkg = await crypto.wrapRecoverySeed(
      recoverySeed: recoverySeed,
      sharedSecret: shared,
      coupleId: loaded.coupleId,
      fromDeviceId: '33333333-3333-4333-8333-333333333333',
      toDeviceId: loaded.deviceId,
    );
    final Map<String, Object?> legacyPkgJson = <String, Object?>{
      'coupleId': v1Pkg.coupleId,
      'fromDeviceId': v1Pkg.fromDeviceId,
      'toDeviceId': v1Pkg.toDeviceId,
      'nonceB64': base64UrlEncode(v1Pkg.nonce),
      'ciphertextB64': base64UrlEncode(v1Pkg.ciphertextWithTag),
    };
    final KeyBundle unwrappedV1 = await crypto.unwrapKeyBundle(
      package: WrappedKeyPackage.fromJson(legacyPkgJson),
      sharedSecret: await crypto.computeSharedSecret(
        myKemKeyPair: kemKp,
        peerKemPublicKey: Uint8List.fromList(
          (await peerKemKp.extractPublicKey()).bytes,
        ),
      ),
      expectedCoupleId: loaded.coupleId,
      expectedToDeviceId: loaded.deviceId,
    );
    expect(unwrappedV1.currentKeyEpoch, 1);
    expect(unwrappedV1.recoverySeed, orderedEquals(recoverySeed));

    // Simulate an n-1 envelope written at epoch=1 alongside an n envelope written at epoch=2
    final EncryptedEnvelope legacyEnv = await crypto.encryptEnvelope(
      rootKey: root1,
      coupleId: loaded.coupleId,
      envelopeId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
      senderDeviceId: loaded.deviceId,
      channel: EnvelopeChannel.event,
      keyEpoch: 1,
      payload: DecryptedEnvelopePayload(
        schemaVersion: 1,
        eventType: 'thinking_of_you',
        createdAtClient: DateTime.utc(2026, 11, 15),
        authorDeviceId: loaded.deviceId,
        body: const <String, Object?>{'note': 'From n-1 client'},
      ),
    );

    // n-1 server response shapes (missing coupleKeyEpoch, kemPublicKeyB64, approved)
    final MockClient mockHttp = MockClient((http.Request req) async {
      if (req.method == 'GET' && req.url.path == '/api/v1/sync/envelopes') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'items': <Map<String, Object?>>[
              <String, Object?>{
                'envelopeId': legacyEnv.envelopeId,
                'coupleId': legacyEnv.coupleId,
                'senderDeviceId': legacyEnv.senderDeviceId,
                'seq': 1,
                'channel': legacyEnv.channel.wireValue,
                'keyEpoch': legacyEnv.keyEpoch,
                'nonceB64': base64UrlEncode(legacyEnv.nonce),
                'ciphertextB64': base64UrlEncode(legacyEnv.ciphertextWithTag),
                'createdAtServer': DateTime.utc(2026, 11, 15).toIso8601String(),
              },
            ],
            'nextAfterSeq': 1,
            'hasMore': false,
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      if (req.method == 'GET' && req.url.path == '/api/v1/pairing/devices') {
        return http.Response(
          jsonEncode(<Map<String, Object?>>[
            <String, Object?>{
              'deviceId': loaded.deviceId,
              'label': loaded.deviceLabel,
              'enrolledVia': 'INVITE_INIT',
              'createdAt': DateTime.utc(2026, 11, 15).toIso8601String(),
              'revokedAt': null,
            },
          ]),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    final InMemorySecureKeyStore store = InMemorySecureKeyStore();
    final PairingAndSyncRepository repo = PairingAndSyncRepository(
      keyStore: store,
      crypto: crypto,
      clientFactory: (String url) =>
          CoupleApiClient(baseUrl: url, httpClient: mockHttp, crypto: crypto),
    );
    await repo.saveIdentity(loaded);

    final List<DecryptedEventRecord> events = await repo
        .fetchAndDecryptEvents();
    expect(events, hasLength(1));
    expect(events.single.payload.body['note'], 'From n-1 client');

    final List<DeviceSummary> devices = await repo.listDevices();
    expect(devices, hasLength(1));
    expect(devices.single.kemPublicKey, isNull);
    expect(devices.single.approved, isTrue);
  });
}
