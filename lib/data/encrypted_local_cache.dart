import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';

/// Cached decrypted event record stored for offline read-only access (`TC-07`, `AD-06`).
class CachedEventEntry {
  const CachedEventEntry({
    required this.envelopeId,
    required this.coupleId,
    required this.senderDeviceId,
    required this.channel,
    required this.keyEpoch,
    required this.payload,
    this.seq,
    this.createdAtServer,
  });

  final String envelopeId;
  final String coupleId;
  final String senderDeviceId;
  final EnvelopeChannel channel;
  final int keyEpoch;
  final DecryptedEnvelopePayload payload;
  final int? seq;
  final DateTime? createdAtServer;

  Map<String, Object?> toJson() => <String, Object?>{
    'envelopeId': envelopeId,
    'coupleId': coupleId,
    'senderDeviceId': senderDeviceId,
    'channel': channel.wireValue,
    'keyEpoch': keyEpoch,
    'seq': seq,
    'createdAtServer': createdAtServer?.toUtc().toIso8601String(),
    'payload': payload.toJson(),
  };

  factory CachedEventEntry.fromJson(Map<String, Object?> json) {
    return CachedEventEntry(
      envelopeId: json['envelopeId'] as String,
      coupleId: json['coupleId'] as String,
      senderDeviceId: json['senderDeviceId'] as String,
      channel: EnvelopeChannel.fromWire(json['channel'] as String),
      keyEpoch: json['keyEpoch'] as int,
      seq: json['seq'] as int?,
      createdAtServer: json['createdAtServer'] == null
          ? null
          : DateTime.parse(json['createdAtServer'] as String).toUtc(),
      payload: DecryptedEnvelopePayload.fromJson(
        json['payload']! as Map<String, Object?>,
      ),
    );
  }
}

/// Encrypted at-rest offline read-only cache (`AD-06`, `TC-07`).
///
/// Encrypts cached decrypted events under an HKDF key derived from the couple's
/// root key using XChaCha20-Poly1305 with `coupleId` AAD, stored inside
/// [SecureKeyStore] (excluded from Android Auto Backup via `AndroidManifest.xml`).
class EncryptedLocalCache {
  EncryptedLocalCache({required this._keyStore});

  static const String _storageKey = 'deep_sky.offline_cache.v1';

  final SecureKeyStore _keyStore;
  final Xchacha20 _aead = Xchacha20.poly1305Aead();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  Future<void> saveEvents({
    required Uint8List coupleRootKey,
    required String coupleId,
    required List<CachedEventEntry> entries,
  }) async {
    final SecretKey cacheKey = await _deriveCacheKey(coupleRootKey);
    final List<int> nonce = _aead.newNonce();
    final Map<String, Object?> clearObj = <String, Object?>{
      'schemaVersion': 1,
      'coupleId': coupleId,
      'entries': entries
          .map((CachedEventEntry e) => e.toJson())
          .toList(growable: false),
    };
    final SecretBox box = await _aead.encrypt(
      utf8.encode(jsonEncode(clearObj)),
      secretKey: cacheKey,
      nonce: nonce,
      aad: _aadFor(coupleId),
    );
    final String wrapped = jsonEncode(<String, Object?>{
      'nonceB64': base64UrlEncode(box.nonce),
      'ciphertextB64': base64UrlEncode(box.cipherText),
      'macB64': base64UrlEncode(box.mac.bytes),
    });
    await _keyStore.write(_storageKey, wrapped);
  }

  Future<List<CachedEventEntry>> loadEvents({
    required Uint8List coupleRootKey,
    required String coupleId,
  }) async {
    final String? raw = await _keyStore.read(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const <CachedEventEntry>[];
    }
    final Object? decodedOuter = jsonDecode(raw);
    if (decodedOuter is! Map<String, Object?>) {
      throw const FormatException('Offline cache envelope is malformed.');
    }
    final SecretKey cacheKey = await _deriveCacheKey(coupleRootKey);
    final SecretBox box = SecretBox(
      _decodeB64(decodedOuter['ciphertextB64']! as String),
      nonce: _decodeB64(decodedOuter['nonceB64']! as String),
      mac: Mac(_decodeB64(decodedOuter['macB64']! as String)),
    );
    final List<int> clearBytes = await _aead.decrypt(
      box,
      secretKey: cacheKey,
      aad: _aadFor(coupleId),
    );
    final Map<String, Object?> clearObj =
        jsonDecode(utf8.decode(clearBytes)) as Map<String, Object?>;
    if (clearObj['coupleId'] != coupleId) {
      throw const FormatException('Offline cache coupleId mismatch.');
    }
    final List<Object?> rawEntries =
        clearObj['entries'] as List<Object?>? ?? const <Object?>[];
    return rawEntries
        .cast<Map<String, Object?>>()
        .map(CachedEventEntry.fromJson)
        .toList(growable: false);
  }

  Future<void> clear() => _keyStore.delete(_storageKey);

  Future<SecretKey> _deriveCacheKey(Uint8List coupleRootKey) {
    return _hkdf.deriveKey(
      secretKey: SecretKey(coupleRootKey),
      nonce: const <int>[],
      info: utf8.encode('deep-sky:offline-cache:v1'),
    );
  }

  static List<int> _aadFor(String coupleId) =>
      utf8.encode('deep-sky:offline-cache:v1|$coupleId');

  static List<int> _decodeB64(String input) {
    final int rem = input.length % 4;
    final String padded = rem == 0
        ? input
        : input.padRight(input.length + (4 - rem), '=');
    return base64Url.decode(padded);
  }
}
