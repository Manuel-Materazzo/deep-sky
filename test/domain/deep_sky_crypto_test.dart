import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/domain/crypto/deep_sky_crypto.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';
import 'package:deep_sky/domain/crypto/recovery_key_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecoveryKeyCodec (SP02-05)', () {
    test('encodes and decodes 256-bit seed as 24 BIP-39 words', () {
      final Uint8List seed = Uint8List.fromList(
        List<int>.generate(32, (int i) => i),
      );
      final List<String> words = RecoveryKeyCodec.toWords(seed);
      expect(words.length, 24);
      // Known BIP-39 vector for 0x00..0x1f entropy
      expect(words.first, 'abandon');
      expect(words[1], 'amount');
      expect(words[2], 'liar');

      final Uint8List decoded = RecoveryKeyCodec.fromSentence(words.join('  '));
      expect(decoded, orderedEquals(seed));
    });

    test('rejects mnemonic with tampered word (checksum mismatch)', () {
      final Uint8List seed = Uint8List.fromList(
        List<int>.generate(32, (int i) => i + 1),
      );
      final List<String> words = RecoveryKeyCodec.toWords(seed).toList();
      words[23] = words[23] == 'abandon' ? 'ability' : 'abandon';

      expect(
        () => RecoveryKeyCodec.fromSentence(words.join(' ')),
        throwsFormatException,
      );
    });

    test('encodes and decodes checksummed QR payload', () {
      final Uint8List seed = Uint8List.fromList(
        List<int>.generate(32, (int i) => (i * 7 + 3) & 0xFF),
      );
      final String qr = RecoveryKeyCodec.toQrPayload(seed);
      expect(qr.startsWith(RecoveryKeyCodec.qrPrefix), isTrue);
      expect(RecoveryKeyCodec.parseUserInput(qr), orderedEquals(seed));

      final String tampered =
          '${qr.substring(0, qr.length - 2)}${qr.endsWith('A') ? 'B' : 'A'}';
      expect(
        () => RecoveryKeyCodec.fromQrPayload(tampered),
        throwsFormatException,
      );
    });
  });

  group('DeepSkyCrypto (SP02-02)', () {
    late DeepSkyCrypto crypto;

    setUp(() {
      crypto = DeepSkyCrypto();
    });

    test(
      'derives deterministic HKDF-SHA256 keys from fixed test vector',
      () async {
        final Uint8List fixedSeed = Uint8List.fromList(
          List<int>.generate(32, (int i) => i),
        );
        final Uint8List kRoot1 = await crypto.deriveCoupleRootKey(fixedSeed);
        final Uint8List kRoot2 = await crypto.deriveCoupleRootKey(fixedSeed);
        expect(kRoot1.length, 32);
        expect(kRoot1, orderedEquals(kRoot2));
        expect(kRoot1, isNot(orderedEquals(fixedSeed)));

        final SimpleKeyPair auth1 = await crypto.deriveRecoveryAuthKeyPair(
          fixedSeed,
        );
        final SimpleKeyPair auth2 = await crypto.deriveRecoveryAuthKeyPair(
          fixedSeed,
        );
        final SimplePublicKey pub1 = await auth1.extractPublicKey();
        final SimplePublicKey pub2 = await auth2.extractPublicKey();
        expect(pub1.bytes, orderedEquals(pub2.bytes));

        final Uint8List kEvents = await crypto.deriveChannelKey(
          rootKey: kRoot1,
          channel: EnvelopeChannel.event,
          keyEpoch: 1,
        );
        final Uint8List kSnapshots = await crypto.deriveChannelKey(
          rootKey: kRoot1,
          channel: EnvelopeChannel.snapshot,
          keyEpoch: 1,
        );
        final Uint8List kEventsEpoch2 = await crypto.deriveChannelKey(
          rootKey: kRoot1,
          channel: EnvelopeChannel.event,
          keyEpoch: 2,
        );
        expect(kEvents, isNot(orderedEquals(kSnapshots)));
        expect(kEvents, isNot(orderedEquals(kEventsEpoch2)));
      },
    );

    test(
      'SAS code is symmetric between partner A and B and detects MITM',
      () async {
        final SimpleKeyPair kemA = await crypto.generateDeviceKemKeyPair();
        final SimpleKeyPair kemB = await crypto.generateDeviceKemKeyPair();
        final SimpleKeyPair kemMitm = await crypto.generateDeviceKemKeyPair();

        final Uint8List pubA = Uint8List.fromList(
          (await kemA.extractPublicKey()).bytes,
        );
        final Uint8List pubB = Uint8List.fromList(
          (await kemB.extractPublicKey()).bytes,
        );
        final Uint8List pubMitm = Uint8List.fromList(
          (await kemMitm.extractPublicKey()).bytes,
        );

        const String coupleId = '11111111-1111-4111-8111-111111111111';
        final Uint8List secretA = await crypto.computeSharedSecret(
          myKemKeyPair: kemA,
          peerKemPublicKey: pubB,
        );
        final Uint8List secretB = await crypto.computeSharedSecret(
          myKemKeyPair: kemB,
          peerKemPublicKey: pubA,
        );
        expect(secretA, orderedEquals(secretB));

        final String sasA = await crypto.computeSasCode(
          sharedSecret: secretA,
          coupleId: coupleId,
          localKemPublicKey: pubA,
          peerKemPublicKey: pubB,
        );
        final String sasB = await crypto.computeSasCode(
          sharedSecret: secretB,
          coupleId: coupleId,
          localKemPublicKey: pubB,
          peerKemPublicKey: pubA,
        );
        expect(sasA, matches(RegExp(r'^\d{3}-\d{3}$')));
        expect(sasA, equals(sasB));

        final Uint8List mitmSecret = await crypto.computeSharedSecret(
          myKemKeyPair: kemA,
          peerKemPublicKey: pubMitm,
        );
        final String sasMitm = await crypto.computeSasCode(
          sharedSecret: mitmSecret,
          coupleId: coupleId,
          localKemPublicKey: pubA,
          peerKemPublicKey: pubMitm,
        );
        expect(sasMitm, isNot(equals(sasA)));
      },
    );

    test(
      'wraps and unwraps recoverySeed and rejects tampered package',
      () async {
        final Uint8List seed = crypto.generateRecoverySeed();
        final SimpleKeyPair kemA = await crypto.generateDeviceKemKeyPair();
        final SimpleKeyPair kemB = await crypto.generateDeviceKemKeyPair();
        final Uint8List pubB = Uint8List.fromList(
          (await kemB.extractPublicKey()).bytes,
        );
        final Uint8List pubA = Uint8List.fromList(
          (await kemA.extractPublicKey()).bytes,
        );
        final Uint8List sharedA = await crypto.computeSharedSecret(
          myKemKeyPair: kemA,
          peerKemPublicKey: pubB,
        );
        final Uint8List sharedB = await crypto.computeSharedSecret(
          myKemKeyPair: kemB,
          peerKemPublicKey: pubA,
        );

        const String coupleId = '22222222-2222-4222-8222-222222222222';
        const String devA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
        const String devB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

        final WrappedKeyPackage pkg = await crypto.wrapRecoverySeed(
          recoverySeed: seed,
          sharedSecret: sharedA,
          coupleId: coupleId,
          fromDeviceId: devA,
          toDeviceId: devB,
        );

        final Uint8List unwrapped = await crypto.unwrapRecoverySeed(
          package: pkg,
          sharedSecret: sharedB,
          expectedCoupleId: coupleId,
          expectedToDeviceId: devB,
        );
        expect(unwrapped, orderedEquals(seed));

        final Uint8List tamperedCipher = Uint8List.fromList(
          pkg.ciphertextWithTag,
        );
        tamperedCipher[0] ^= 0xFF;
        await expectLater(
          crypto.unwrapRecoverySeed(
            package: WrappedKeyPackage(
              coupleId: pkg.coupleId,
              fromDeviceId: pkg.fromDeviceId,
              toDeviceId: pkg.toDeviceId,
              nonce: pkg.nonce,
              ciphertextWithTag: tamperedCipher,
            ),
            sharedSecret: sharedB,
            expectedCoupleId: coupleId,
            expectedToDeviceId: devB,
          ),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
      },
    );

    test('encrypts and decrypts envelope and rejects tampering or couple relocation', () async {
      final Uint8List seed = crypto.generateRecoverySeed();
      final Uint8List kRoot = await crypto.deriveCoupleRootKey(seed);
      const String coupleId = '33333333-3333-4333-8333-333333333333';
      const String otherCoupleId = '44444444-4444-4444-8444-444444444444';
      const String envelopeId = '55555555-5555-4555-8555-555555555555';
      const String deviceId = '66666666-6666-4666-8666-666666666666';

      final DecryptedEnvelopePayload payload = DecryptedEnvelopePayload(
        schemaVersion: 1,
        eventType: 'time_capsule',
        createdAtClient: DateTime.utc(2026, 11, 14, 21, 0),
        authorDeviceId: deviceId,
        body: <String, Object?>{
          'title': 'Our next trip',
          'unlockAt': '2027-02-14T00:00:00.000Z',
        },
      );

      final EncryptedEnvelope envelope = await crypto.encryptEnvelope(
        rootKey: kRoot,
        coupleId: coupleId,
        envelopeId: envelopeId,
        senderDeviceId: deviceId,
        channel: EnvelopeChannel.event,
        keyEpoch: 1,
        payload: payload,
      );

      // Plaintext markers must not appear in serialized ciphertext
      final String wireB64 = base64UrlEncode(envelope.ciphertextWithTag);
      expect(wireB64.contains('time_capsule'), isFalse);
      expect(wireB64.contains('2027-02-14'), isFalse);

      final DecryptedEnvelopePayload decrypted = await crypto.decryptEnvelope(
        rootKey: kRoot,
        expectedCoupleId: coupleId,
        envelope: envelope,
      );
      expect(decrypted.eventType, 'time_capsule');
      expect(decrypted.body['unlockAt'], '2027-02-14T00:00:00.000Z');

      // 1. Tampered ciphertext rejected
      final Uint8List badCipher = Uint8List.fromList(
        envelope.ciphertextWithTag,
      );
      badCipher[3] ^= 0x01;
      await expectLater(
        crypto.decryptEnvelope(
          rootKey: kRoot,
          expectedCoupleId: coupleId,
          envelope: EncryptedEnvelope(
            envelopeId: envelope.envelopeId,
            coupleId: envelope.coupleId,
            senderDeviceId: envelope.senderDeviceId,
            channel: envelope.channel,
            keyEpoch: envelope.keyEpoch,
            nonce: envelope.nonce,
            ciphertextWithTag: badCipher,
          ),
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );

      // 2. Relocated between couples rejected
      await expectLater(
        crypto.decryptEnvelope(
          rootKey: kRoot,
          expectedCoupleId: otherCoupleId,
          envelope: envelope,
        ),
        throwsFormatException,
      );

      // 3. Altered senderDeviceId (AAD mismatch) rejected
      await expectLater(
        crypto.decryptEnvelope(
          rootKey: kRoot,
          expectedCoupleId: coupleId,
          envelope: EncryptedEnvelope(
            envelopeId: envelope.envelopeId,
            coupleId: envelope.coupleId,
            senderDeviceId: '77777777-7777-4777-8777-777777777777',
            channel: envelope.channel,
            keyEpoch: envelope.keyEpoch,
            nonce: envelope.nonce,
            ciphertextWithTag: envelope.ciphertextWithTag,
          ),
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });
}
