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

  /// Generates an independent 32-byte random epoch secret for `keyEpoch >= 2` (`CA-02`, `ADR-0012`).
  Uint8List generateEpochSecret() => generateRecoverySeed();

  /// Generates a 16-byte client-only out-of-band SAS secret (`CA-01`, `ADR-0011`).
  ///
  /// Carried only in the pairing QR/link fragment or manual pairing code and never
  /// transmitted to the coordination server.
  Uint8List generateSasSecret() {
    final Uint8List secret = Uint8List(16);
    for (int i = 0; i < secret.length; i++) {
      secret[i] = _random.nextInt(256);
    }
    return secret;
  }

  /// Generates an unpadded base64url-encoded out-of-band SAS secret (`CA-01`).
  String generateSasSecretB64() =>
      base64UrlEncode(generateSasSecret()).replaceAll('=', '');

  /// Decodes and validates an out-of-band SAS secret (`>= 16` bytes).
  static Uint8List decodeSasSecretB64(String raw) {
    final Uint8List decoded = Uint8List.fromList(
      base64Url.decode(base64Url.normalize(raw.trim())),
    );
    if (decoded.length < 16) {
      throw ArgumentError.value(
        decoded.length,
        'sasSecret',
        'Must be at least 16 bytes.',
      );
    }
    return decoded;
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

  /// Derives the legacy `v1` channel-specific symmetric key (`keyEpoch == 1`).
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

  /// Derives the epoch-isolated `v2` channel key from an independent random `epochSecret` (`keyEpoch >= 2`, `CA-02`).
  Future<Uint8List> deriveEpochChannelKey({
    required Uint8List epochSecret,
    required EnvelopeChannel channel,
    required int keyEpoch,
  }) async {
    _require32Bytes(epochSecret, 'epochSecret');
    if (keyEpoch < 2) {
      throw ArgumentError.value(keyEpoch, 'keyEpoch', 'Must be >= 2');
    }
    final String label = switch (channel) {
      EnvelopeChannel.event => 'events',
      EnvelopeChannel.snapshot => 'snapshots',
    };
    final SecretKeyData derived = await _hkdf.deriveKey(
      secretKey: SecretKey(epochSecret),
      nonce: const <int>[],
      info: utf8.encode('deep-sky:$label:v2|epoch=$keyEpoch'),
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
  /// binding the X25519 ECDH secret with the out-of-band `sasSecret` (`CA-01`, `ADR-0011`)
  /// so both partners can verify there is no MITM during pairing/enrollment.
  Future<String> computeSasCode({
    required Uint8List sharedSecret,
    required Uint8List sasSecret,
    required String coupleId,
    required Uint8List localKemPublicKey,
    required Uint8List peerKemPublicKey,
  }) async {
    _require32Bytes(sharedSecret, 'sharedSecret');
    if (sasSecret.length < 16) {
      throw ArgumentError.value(
        sasSecret.length,
        'sasSecret',
        'Must be at least 16 bytes.',
      );
    }
    _require32Bytes(localKemPublicKey, 'localKemPublicKey');
    _require32Bytes(peerKemPublicKey, 'peerKemPublicKey');

    final String a = base64UrlEncode(localKemPublicKey);
    final String b = base64UrlEncode(peerKemPublicKey);
    final List<String> ordered = <String>[a, b]..sort();
    final List<int> ikm = <int>[...sharedSecret, ...sasSecret];
    final Hkdf sasHkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 4);
    final SecretKeyData sasBytes = await sasHkdf.deriveKey(
      secretKey: SecretKey(ikm),
      nonce: utf8.encode(coupleId),
      info: utf8.encode('deep-sky:pairing-sas:v2|${ordered[0]}|${ordered[1]}'),
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

  /// Wraps a version-2 [KeyBundle] (`CA-02`) for an active or newly paired device.
  Future<WrappedKeyPackage> wrapKeyBundle({
    required KeyBundle bundle,
    required Uint8List sharedSecret,
    required String coupleId,
    required String fromDeviceId,
    required String toDeviceId,
    int? keyEpoch,
    String deliveryKind = 'PAIRING_SEED',
  }) async {
    _require32Bytes(bundle.recoverySeed, 'bundle.recoverySeed');
    _require32Bytes(sharedSecret, 'sharedSecret');
    final int effectiveEpoch = keyEpoch ?? bundle.currentKeyEpoch;
    final SecretKeyData wrapKey = await _hkdf.deriveKey(
      secretKey: SecretKey(sharedSecret),
      nonce: utf8.encode(coupleId),
      info: _pairingWrapInfo,
    );
    final List<int> aad = utf8.encode(
      'deep-sky:key-delivery:v2|coupleId=$coupleId|from=$fromDeviceId|to=$toDeviceId|epoch=$effectiveEpoch',
    );
    final List<int> clear = utf8.encode(jsonEncode(bundle.toJson()));
    final SecretBox box = await _aead.encrypt(
      clear,
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
      keyEpoch: effectiveEpoch,
      deliveryKind: deliveryKind,
    );
  }

  /// Unwraps either a v2 [KeyBundle] (`deep-sky:key-delivery:v2`) or legacy v1 `recoverySeed`.
  Future<KeyBundle> unwrapKeyBundle({
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
    final int split = package.ciphertextWithTag.length - 16;
    final SecretBox box = SecretBox(
      package.ciphertextWithTag.sublist(0, split),
      nonce: package.nonce,
      mac: Mac(package.ciphertextWithTag.sublist(split)),
    );
    final List<int> v2Aad = utf8.encode(
      'deep-sky:key-delivery:v2|coupleId=${package.coupleId}'
      '|from=${package.fromDeviceId}|to=${package.toDeviceId}|epoch=${package.keyEpoch}',
    );
    try {
      final List<int> clear = await _aead.decrypt(
        box,
        secretKey: wrapKey,
        aad: v2Aad,
      );
      final Object? decoded = jsonDecode(utf8.decode(clear));
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Wrapped KeyBundle payload is not JSON.');
      }
      final KeyBundle bundle = KeyBundle.fromJson(decoded);
      _require32Bytes(bundle.recoverySeed, 'bundle.recoverySeed');
      return bundle;
    } on SecretBoxAuthenticationError {
      if (package.keyEpoch != 1) {
        rethrow;
      }
      final Uint8List seed = await unwrapRecoverySeed(
        package: package,
        sharedSecret: sharedSecret,
        expectedCoupleId: expectedCoupleId,
        expectedToDeviceId: expectedToDeviceId,
      );
      return KeyBundle(
        recoverySeed: seed,
        currentKeyEpoch: 1,
        epochSecrets: const <int, Uint8List>{},
      );
    }
  }

  /// Encrypts historical epoch secrets under the active `recoverySeed` (`CA-02`, `ADR-0012`)
  /// so zero-second-phone recovery can decrypt both pre-rotation (`epoch = 1`) and post-rotation history.
  Future<({Uint8List nonce, Uint8List ciphertextWithTag})>
  encryptRecoveryKeyring({
    required Uint8List recoverySeed,
    required String coupleId,
    required int currentKeyEpoch,
    required Map<int, Uint8List> epochSecrets,
  }) async {
    _require32Bytes(recoverySeed, 'recoverySeed');
    final SecretKeyData ringKey = await _hkdf.deriveKey(
      secretKey: SecretKey(recoverySeed),
      nonce: utf8.encode(coupleId),
      info: utf8.encode('deep-sky:recovery-keyring:v1|epoch=$currentKeyEpoch'),
    );
    final List<int> aad = utf8.encode(
      'deep-sky:recovery-keyring:v1|coupleId=$coupleId|epoch=$currentKeyEpoch',
    );
    final List<int> clear = utf8.encode(
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'currentKeyEpoch': currentKeyEpoch,
        'epochSecretsB64': <String, String>{
          for (final MapEntry<int, Uint8List> entry in epochSecrets.entries)
            entry.key.toString(): base64UrlEncode(entry.value),
        },
      }),
    );
    final SecretBox box = await _aead.encrypt(
      clear,
      secretKey: ringKey,
      aad: aad,
    );
    return (
      nonce: Uint8List.fromList(box.nonce),
      ciphertextWithTag: Uint8List.fromList(<int>[
        ...box.cipherText,
        ...box.mac.bytes,
      ]),
    );
  }

  /// Decrypts server-stored recovery keyring using the recovered `recoverySeed` (`CA-02`).
  Future<Map<int, Uint8List>> decryptRecoveryKeyring({
    required Uint8List recoverySeed,
    required String coupleId,
    required int currentKeyEpoch,
    required Uint8List nonce,
    required Uint8List ciphertextWithTag,
  }) async {
    _require32Bytes(recoverySeed, 'recoverySeed');
    if (ciphertextWithTag.length <= 16) {
      throw const FormatException('Recovery keyring ciphertext too short.');
    }
    final SecretKeyData ringKey = await _hkdf.deriveKey(
      secretKey: SecretKey(recoverySeed),
      nonce: utf8.encode(coupleId),
      info: utf8.encode('deep-sky:recovery-keyring:v1|epoch=$currentKeyEpoch'),
    );
    final List<int> aad = utf8.encode(
      'deep-sky:recovery-keyring:v1|coupleId=$coupleId|epoch=$currentKeyEpoch',
    );
    final int split = ciphertextWithTag.length - 16;
    final SecretBox box = SecretBox(
      ciphertextWithTag.sublist(0, split),
      nonce: nonce,
      mac: Mac(ciphertextWithTag.sublist(split)),
    );
    final List<int> clear = await _aead.decrypt(
      box,
      secretKey: ringKey,
      aad: aad,
    );
    final Object? decoded = jsonDecode(utf8.decode(clear));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Recovery keyring payload is not JSON.');
    }
    final Map<int, Uint8List> out = <int, Uint8List>{};
    final Object? rawMap = decoded['epochSecretsB64'];
    if (rawMap is Map) {
      for (final MapEntry<Object?, Object?> entry in rawMap.entries) {
        final int epoch = int.parse(entry.key.toString());
        final Uint8List bytes = Uint8List.fromList(
          base64Url.decode(base64Url.normalize(entry.value! as String)),
        );
        _require32Bytes(bytes, 'epochSecrets[$epoch]');
        out[epoch] = bytes;
      }
    }
    return Map<int, Uint8List>.unmodifiable(out);
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
    Uint8List? rootKey,
    Uint8List? epochSecret,
    required String coupleId,
    required String envelopeId,
    required String senderDeviceId,
    required EnvelopeChannel channel,
    required int keyEpoch,
    required DecryptedEnvelopePayload payload,
  }) async {
    final Uint8List channelKey;
    if (keyEpoch == 1) {
      if (rootKey == null) {
        throw ArgumentError.notNull('rootKey');
      }
      channelKey = await deriveChannelKey(
        rootKey: rootKey,
        channel: channel,
        keyEpoch: 1,
      );
    } else {
      if (epochSecret == null) {
        throw ArgumentError(
          'epochSecret is required for keyEpoch=$keyEpoch (>= 2).',
        );
      }
      channelKey = await deriveEpochChannelKey(
        epochSecret: epochSecret,
        channel: channel,
        keyEpoch: keyEpoch,
      );
    }
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

  /// Decrypts and authenticates an [EncryptedEnvelope], rejecting any tampering,
  /// missing epoch secrets, or cross-couple relocation.
  Future<DecryptedEnvelopePayload> decryptEnvelope({
    required Uint8List rootKey,
    Map<int, Uint8List>? epochSecrets,
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

    final Uint8List channelKey;
    if (envelope.keyEpoch == 1) {
      channelKey = await deriveChannelKey(
        rootKey: epochSecrets?[1] ?? rootKey,
        channel: envelope.channel,
        keyEpoch: 1,
      );
    } else {
      final Uint8List? epochSecret = epochSecrets?[envelope.keyEpoch];
      if (epochSecret == null) {
        throw FormatException(
          'Missing epoch secret for keyEpoch=${envelope.keyEpoch}.',
        );
      }
      channelKey = await deriveEpochChannelKey(
        epochSecret: epochSecret,
        channel: envelope.channel,
        keyEpoch: envelope.keyEpoch,
      );
    }
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
