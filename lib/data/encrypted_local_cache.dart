import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';

/// Cached decrypted event snapshot including incremental sync cursor (`AU-05`).
class CachedEventsSnapshot {
  const CachedEventsSnapshot({
    required this.events,
    required this.lastSeq,
    this.lastEpoch = 1,
  });

  final List<CachedEventEntry> events;
  final int lastSeq;
  final int lastEpoch;
}

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

/// Encrypted at-rest offline read-only cache (`AD-06`, `TC-07`, `AU-05`).
///
/// Encrypts cached decrypted events under an HKDF key derived from the couple's
/// root key using XChaCha20-Poly1305 with `coupleId` AAD. When a local app-support
/// directory is provided via [resolveCacheRootDir], the encrypted blob is written
/// atomically to a file on disk instead of `flutter_secure_storage` (keeping
/// SharedPreferences small), and windowed to the newest [maxCachedEvents] entries.
class EncryptedLocalCache {
  EncryptedLocalCache({
    required this._keyStore,
    this._resolveCacheRootDir,
    this.maxCachedEvents = defaultMaxCachedEvents,
  });

  static const String _storageKey = 'deep_sky.offline_cache.v1';
  static const String _cacheFileName = 'offline_events.v1.enc';
  static const int defaultMaxCachedEvents = 500;

  final SecureKeyStore _keyStore;
  final Future<String?> Function()? _resolveCacheRootDir;
  final int maxCachedEvents;
  final Xchacha20 _aead = Xchacha20.poly1305Aead();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  Future<void> saveEvents({
    required Uint8List coupleRootKey,
    required String coupleId,
    required List<CachedEventEntry> entries,
    int? lastSeq,
    int? lastEpoch,
  }) async {
    final List<CachedEventEntry> windowed = _windowEntries(entries);
    // An explicit cursor is authoritative: it may intentionally sit below the
    // highest cached seq so quarantined envelopes are refetched (`AU-04`).
    int computedLastSeq = lastSeq ?? 0;
    if (lastSeq == null) {
      for (final CachedEventEntry entry in entries) {
        if ((entry.seq ?? 0) > computedLastSeq) {
          computedLastSeq = entry.seq!;
        }
      }
    }
    final SecretKey cacheKey = await _deriveCacheKey(coupleRootKey);
    final List<int> nonce = _aead.newNonce();
    final Map<String, Object?> clearObj = <String, Object?>{
      'schemaVersion': 2,
      'coupleId': coupleId,
      'lastSeq': computedLastSeq,
      'lastEpoch': lastEpoch ?? 1,
      'entries': windowed
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

    final File? cacheFile = await _resolveCacheFile();
    if (cacheFile != null) {
      cacheFile.parent.createSync(recursive: true);
      final File tmpFile = File('${cacheFile.path}.tmp');
      await tmpFile.writeAsString(wrapped, flush: true);
      if (cacheFile.existsSync()) {
        await cacheFile.delete();
      }
      await tmpFile.rename(cacheFile.path);
      // Remove any legacy SharedPreferences copy once migrated to disk.
      await _keyStore.delete(_storageKey);
    } else {
      await _keyStore.write(_storageKey, wrapped);
    }
  }

  Future<CachedEventsSnapshot> loadSnapshot({
    required Uint8List coupleRootKey,
    required String coupleId,
  }) async {
    String? raw;
    final File? cacheFile = await _resolveCacheFile();
    if (cacheFile != null && cacheFile.existsSync()) {
      raw = await cacheFile.readAsString();
    }
    if (raw == null || raw.isEmpty) {
      raw = await _keyStore.read(_storageKey);
    }
    if (raw == null || raw.isEmpty) {
      return const CachedEventsSnapshot(
        events: <CachedEventEntry>[],
        lastSeq: 0,
      );
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
    final List<CachedEventEntry> events = rawEntries
        .cast<Map<String, Object?>>()
        .map(CachedEventEntry.fromJson)
        .toList(growable: false);
    // Schema 2+ persists an authoritative cursor (`AU-04`, `AU-05`); only
    // legacy schema 1 caches derive it from the highest cached seq.
    final int? persistedLastSeq = clearObj['lastSeq'] as int?;
    int storedLastSeq = persistedLastSeq ?? 0;
    if (persistedLastSeq == null) {
      for (final CachedEventEntry entry in events) {
        if ((entry.seq ?? 0) > storedLastSeq) {
          storedLastSeq = entry.seq!;
        }
      }
    }
    final int storedLastEpoch = clearObj['lastEpoch'] as int? ?? 1;
    return CachedEventsSnapshot(
      events: events,
      lastSeq: storedLastSeq,
      lastEpoch: storedLastEpoch,
    );
  }

  Future<List<CachedEventEntry>> loadEvents({
    required Uint8List coupleRootKey,
    required String coupleId,
  }) async {
    final CachedEventsSnapshot snap = await loadSnapshot(
      coupleRootKey: coupleRootKey,
      coupleId: coupleId,
    );
    return snap.events;
  }

  Future<void> clear() async {
    await _keyStore.delete(_storageKey);
    final File? cacheFile = await _resolveCacheFile();
    if (cacheFile != null && cacheFile.existsSync()) {
      try {
        await cacheFile.delete();
      } catch (_) {}
    }
  }

  List<CachedEventEntry> _windowEntries(List<CachedEventEntry> entries) {
    if (entries.length <= maxCachedEvents) {
      return entries;
    }
    final List<CachedEventEntry> sorted = List<CachedEventEntry>.from(entries)
      ..sort((CachedEventEntry a, CachedEventEntry b) {
        final int seqCmp = (a.seq ?? 0).compareTo(b.seq ?? 0);
        if (seqCmp != 0) return seqCmp;
        return a.envelopeId.compareTo(b.envelopeId);
      });
    return sorted.sublist(sorted.length - maxCachedEvents);
  }

  Future<File?> _resolveCacheFile() async {
    final Future<String?> Function()? resolver = _resolveCacheRootDir;
    if (resolver == null) {
      return null;
    }
    final String? root = await resolver();
    if (root == null || root.trim().isEmpty) {
      return null;
    }
    return File('$root${Platform.pathSeparator}$_cacheFileName');
  }

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
