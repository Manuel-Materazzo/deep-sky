import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';

/// End-to-end cryptographic operations for Deep Sky (`SP02-02`, `S-01`, `S-06`, `AD-01`).
/// Uses mature primitives from `package:cryptography`:
/// - X25519 for ECDH key agreement
/// - Ed25519 for device authentication & recovery claims
/// - HKDF-SHA256 for domain-separated key derivation
/// - XChaCha20-Poly1305 for authenticated envelope and key-wrap encryption
class DeepSkyCrypto {
  DeepSkyCrypto({Cipher? aeadCipher})
    : _aead = aeadCipher ?? Xchacha20.poly1305Aead();

  static final List<int> _rootSalt = utf8.encode('deep-sky:salt:v1');
  static final List<int> _rootInfo = utf8.encode('deep-sky:couple-root:v1');
  static final List<int> _recoveryAuthInfo = utf8.encode(
    'deep-sky:recovery-auth:v1',
  );
  static final List<int> _pairingWrapInfo = utf8.encode(
    'deep-sky:pairing-wrap:v1',
  );

  final Cipher _aead;
  final X25519 _x25519 = X25519();
  final Ed25519 _ed25519 = Ed25519();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final Sha256 _sha256 = Sha256();
  final Random _random = Random.secure();

  /// Generates a 32-byte cryptographically random recovery seed.
  Uint8List generateRecoverySeed() {
    final Uint8List seed = Uint8List(32);
    for (int i = 0; i < seed.length; i++) {
      seed[i] = _random.nextInt(256);
    }
    return seed;
  }

  /// Generates a random UUIDv4 string for client-side envelope identifiers.
  String generateUuidV4() {
    final Uint8List bytes = Uint8List(16);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final String hex = _toHex(bytes);
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Generates a fresh Ed25519 keypair for device HTTP request authentication.
  Future<SimpleKeyPair> generateDeviceAuthKeyPair() => _ed25519.newKeyPair();

  /// Reconstructs an Ed25519 keypair from its 32-byte private seed.
  Future<SimpleKeyPair> deviceAuthKeyPairFromSeed(Uint8List seed) =>
      _ed25519.newKeyPairFromSeed(seed);

  /// Generates a fresh X25519 keypair for pairing/enrollment ECDH key delivery.
  Future<SimpleKeyPair> generateDeviceKemKeyPair() => _x25519.newKeyPair();

  /// Reconstructs an X25519 keypair from its 32-byte private key bytes.
  Future<SimpleKeyPair> deviceKemKeyPairFromPrivateBytes(Uint8List bytes) =>
      _x25519.newKeyPairFromSeed(bytes);

  /// Derives the 32-byte Couple Root Key (`K_root`) from `recoverySeed`.
  Future<Uint8List> deriveCoupleRootKey(Uint8List recoverySeed) async {
    _require32Bytes(recoverySeed, 'recoverySeed');
    final SecretKeyData derived = await _hkdf.deriveKey(
      secretKey: SecretKey(recoverySeed),
      nonce: _rootSalt,
      info: _rootInfo,
    );
    return Uint8List.fromList(await derived.extractBytes());
  }

  /// Derives the deterministic Ed25519 `recoveryAuthKeyPair` from `recoverySeed`.
  Future<SimpleKeyPair> deriveRecoveryAuthKeyPair(
    Uint8List recoverySeed,
  ) async {
    _require32Bytes(recoverySeed, 'recoverySeed');
    final SecretKeyData seed = await _hkdf.deriveKey(
      secretKey: SecretKey(recoverySeed),
      nonce: _rootSalt,
      info: _recoveryAuthInfo,
    );
    return _ed25519.newKeyPairFromSeed(await seed.extractBytes());
  }

  /// Derives the channel-specific symmetric key (`K_events`, `K_snapshots`, `K_blobs`).
  Future<Uint8List> deriveChannelKey({
    required Uint8List rootKey,
    required EnvelopeChannel channel,
    required int keyEpoch,
  }) async {
    _require32Bytes(rootKey, 'rootKey');
    if (keyEpoch < 1) {
      throw ArgumentError.value(keyEpoch, 'keyEpoch', 'Must be >= 1');
    }
    final String label = switch (channel) {
      EnvelopeChannel.event => 'events',
      EnvelopeChannel.snapshot => 'snapshots',
    };
    final SecretKeyData derived = await _hkdf.deriveKey(
      secretKey: SecretKey(rootKey),
      nonce: const <int>[],
      info: utf8.encode('deep-sky:$label:v1|epoch=$keyEpoch'),
    );
    return Uint8List.fromList(await derived.extractBytes());
  }

  /// Computes an X25519 ECDH shared secret with a peer's X25519 public key.
  Future<Uint8List> computeSharedSecret({
    required SimpleKeyPair myKemKeyPair,
    required Uint8List peerKemPublicKey,
  }) async {
    _require32Bytes(peerKemPublicKey, 'peerKemPublicKey');
    final SecretKey shared = await _x25519.sharedSecretKey(
      keyPair: myKemKeyPair,
      remotePublicKey: SimplePublicKey(
        peerKemPublicKey,
        type: KeyPairType.x25519,
      ),
    );
    return Uint8List.fromList(await shared.extractBytes());
  }

  /// Computes a symmetric, order-independent 6-digit SAS code (`XXX-XXX`)
  /// so both partners can verify there is no MITM during pairing/enrollment.
  Future<String> computeSasCode({
    required Uint8List sharedSecret,
    required String coupleId,
    required Uint8List localKemPublicKey,
    required Uint8List peerKemPublicKey,
  }) async {
    _require32Bytes(sharedSecret, 'sharedSecret');
    _require32Bytes(localKemPublicKey, 'localKemPublicKey');
    _require32Bytes(peerKemPublicKey, 'peerKemPublicKey');

    final String a = base64UrlEncode(localKemPublicKey);
    final String b = base64UrlEncode(peerKemPublicKey);
    final List<String> ordered = <String>[a, b]..sort();
    final Hkdf sasHkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 4);
    final SecretKeyData sasBytes = await sasHkdf.deriveKey(
      secretKey: SecretKey(sharedSecret),
      nonce: utf8.encode(coupleId),
      info: utf8.encode('deep-sky:pairing-sas:v1|${ordered[0]}|${ordered[1]}'),
    );
    final List<int> bytes = await sasBytes.extractBytes();
    final int value =
        ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) &
        0x7FFFFFFF;
    final String digits = (value % 1000000).toString().padLeft(6, '0');
    return '${digits.substring(0, 3)}-${digits.substring(3)}';
  }

  /// Wraps `recoverySeed` for a target device after SAS verification.
  Future<WrappedKeyPackage> wrapRecoverySeed({
    required Uint8List recoverySeed,
    required Uint8List sharedSecret,
    required String coupleId,
    required String fromDeviceId,
    required String toDeviceId,
  }) async {
    _require32Bytes(recoverySeed, 'recoverySeed');
    _require32Bytes(sharedSecret, 'sharedSecret');

    final SecretKeyData wrapKey = await _hkdf.deriveKey(
      secretKey: SecretKey(sharedSecret),
      nonce: utf8.encode(coupleId),
      info: _pairingWrapInfo,
    );
    final List<int> aad = utf8.encode(
      'deep-sky:key-delivery:v1|coupleId=$coupleId|from=$fromDeviceId|to=$toDeviceId',
    );
    final SecretBox box = await _aead.encrypt(
      recoverySeed,
      secretKey: wrapKey,
      aad: aad,
    );
    return WrappedKeyPackage(
      coupleId: coupleId,
      fromDeviceId: fromDeviceId,
      toDeviceId: toDeviceId,
      nonce: Uint8List.fromList(box.nonce),
      ciphertextWithTag: Uint8List.fromList(<int>[
        ...box.cipherText,
        ...box.mac.bytes,
      ]),
    );
  }

  /// Unwraps `recoverySeed` from a verified [WrappedKeyPackage].
  Future<Uint8List> unwrapRecoverySeed({
    required WrappedKeyPackage package,
    required Uint8List sharedSecret,
    required String expectedCoupleId,
    required String expectedToDeviceId,
  }) async {
    _require32Bytes(sharedSecret, 'sharedSecret');
    if (package.coupleId != expectedCoupleId ||
        package.toDeviceId != expectedToDeviceId) {
      throw const FormatException('Wrapped key package metadata mismatch.');
    }
    if (package.ciphertextWithTag.length <= 16) {
      throw const FormatException('Wrapped key ciphertext too short.');
    }

    final SecretKeyData wrapKey = await _hkdf.deriveKey(
      secretKey: SecretKey(sharedSecret),
      nonce: utf8.encode(expectedCoupleId),
      info: _pairingWrapInfo,
    );
    final List<int> aad = utf8.encode(
      'deep-sky:key-delivery:v1|coupleId=${package.coupleId}'
      '|from=${package.fromDeviceId}|to=${package.toDeviceId}',
    );
    final int split = package.ciphertextWithTag.length - 16;
    final SecretBox box = SecretBox(
      package.ciphertextWithTag.sublist(0, split),
      nonce: package.nonce,
      mac: Mac(package.ciphertextWithTag.sublist(split)),
    );
    final List<int> clear = await _aead.decrypt(
      box,
      secretKey: wrapKey,
      aad: aad,
    );
    final Uint8List seed = Uint8List.fromList(clear);
    _require32Bytes(seed, 'unwrapped recoverySeed');
    return seed;
  }

  /// Builds canonical AEAD AAD binding envelope metadata to ciphertext (`SP02-01`).
  List<int> buildEnvelopeAad({
    required String coupleId,
    required String envelopeId,
    required String senderDeviceId,
    required EnvelopeChannel channel,
    required int keyEpoch,
  }) {
    return utf8.encode(
      'deep-sky:envelope:v1|coupleId=$coupleId|envelopeId=$envelopeId'
      '|senderDeviceId=$senderDeviceId|channel=${channel.wireValue}|keyEpoch=$keyEpoch',
    );
  }

  /// Encrypts a plaintext payload into an authenticated [EncryptedEnvelope].
  Future<EncryptedEnvelope> encryptEnvelope({
    required Uint8List rootKey,
    required String coupleId,
    required String envelopeId,
    required String senderDeviceId,
    required EnvelopeChannel channel,
    required int keyEpoch,
    required DecryptedEnvelopePayload payload,
  }) async {
    final Uint8List channelKey = await deriveChannelKey(
      rootKey: rootKey,
      channel: channel,
      keyEpoch: keyEpoch,
    );
    final List<int> plaintext = utf8.encode(jsonEncode(payload.toJson()));
    final List<int> aad = buildEnvelopeAad(
      coupleId: coupleId,
      envelopeId: envelopeId,
      senderDeviceId: senderDeviceId,
      channel: channel,
      keyEpoch: keyEpoch,
    );
    final SecretBox box = await _aead.encrypt(
      plaintext,
      secretKey: SecretKey(channelKey),
      aad: aad,
    );
    return EncryptedEnvelope(
      envelopeId: envelopeId,
      coupleId: coupleId,
      senderDeviceId: senderDeviceId,
      channel: channel,
      keyEpoch: keyEpoch,
      nonce: Uint8List.fromList(box.nonce),
      ciphertextWithTag: Uint8List.fromList(<int>[
        ...box.cipherText,
        ...box.mac.bytes,
      ]),
    );
  }

  /// Decrypts and authenticates an [EncryptedEnvelope], rejecting any tampering
  /// or cross-couple relocation.
  Future<DecryptedEnvelopePayload> decryptEnvelope({
    required Uint8List rootKey,
    required String expectedCoupleId,
    required EncryptedEnvelope envelope,
  }) async {
    if (envelope.coupleId != expectedCoupleId) {
      throw const FormatException(
        'Envelope coupleId does not match local couple.',
      );
    }
    if (envelope.ciphertextWithTag.length <= 16) {
      throw const FormatException('Envelope ciphertext is truncated.');
    }

    final Uint8List channelKey = await deriveChannelKey(
      rootKey: rootKey,
      channel: envelope.channel,
      keyEpoch: envelope.keyEpoch,
    );
    final List<int> aad = buildEnvelopeAad(
      coupleId: expectedCoupleId,
      envelopeId: envelope.envelopeId,
      senderDeviceId: envelope.senderDeviceId,
      channel: envelope.channel,
      keyEpoch: envelope.keyEpoch,
    );
    final int split = envelope.ciphertextWithTag.length - 16;
    final SecretBox box = SecretBox(
      envelope.ciphertextWithTag.sublist(0, split),
      nonce: envelope.nonce,
      mac: Mac(envelope.ciphertextWithTag.sublist(split)),
    );
    final List<int> clearBytes = await _aead.decrypt(
      box,
      secretKey: SecretKey(channelKey),
      aad: aad,
    );
    final Object? decoded = jsonDecode(utf8.decode(clearBytes));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Decrypted envelope payload is not JSON.');
    }
    return DecryptedEnvelopePayload.fromJson(decoded);
  }

  /// Signs an authenticated HTTP request using the device's Ed25519 keypair (`AD-02`).
  Future<String> signHttpRequest({
    required SimpleKeyPair deviceAuthKeyPair,
    required String method,
    required String pathWithQuery,
    required int timestampSeconds,
    required String nonce,
    required List<int> bodyBytes,
  }) async {
    final Hash bodyHash = await _sha256.hash(bodyBytes);
    final String canonical =
        '${method.toUpperCase()}\n$pathWithQuery\n$timestampSeconds\n$nonce\n${_toHex(bodyHash.bytes)}';
    final Signature signature = await _ed25519.sign(
      utf8.encode(canonical),
      keyPair: deviceAuthKeyPair,
    );
    return base64UrlEncode(signature.bytes);
  }

  /// Signs a zero-second-phone recovery claim with `recoveryAuthKeyPair` (`SP02-05`).
  Future<String> signRecoveryClaim({
    required SimpleKeyPair recoveryAuthKeyPair,
    required String coupleId,
    required String challengeId,
    required String nonce,
    required Uint8List newDeviceAuthPublicKey,
    required Uint8List newDeviceKemPublicKey,
  }) async {
    final String canonical =
        'deep-sky:recovery:v1|$coupleId|$challengeId|$nonce|'
        '${base64UrlEncode(newDeviceAuthPublicKey)}|${base64UrlEncode(newDeviceKemPublicKey)}';
    final Signature signature = await _ed25519.sign(
      utf8.encode(canonical),
      keyPair: recoveryAuthKeyPair,
    );
    return base64UrlEncode(signature.bytes);
  }

  static void _require32Bytes(Uint8List bytes, String name) {
    if (bytes.length != 32) {
      throw ArgumentError.value(bytes.length, name, 'Must be 32 bytes.');
    }
  }

  static String _toHex(List<int> bytes) {
    final StringBuffer sb = StringBuffer();
    for (final int b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
