import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:deep_sky/data/couple_api_client.dart';
import 'package:deep_sky/data/encrypted_local_cache.dart';
import 'package:deep_sky/data/secure_key_store.dart';
import 'package:deep_sky/domain/crypto/deep_sky_crypto.dart';
import 'package:deep_sky/domain/crypto/e2ee_models.dart';
import 'package:deep_sky/domain/crypto/recovery_key_codec.dart';
import 'package:http/http.dart' as http;

class PendingJoinSession {
  const PendingJoinSession({
    required this.identity,
    required this.peerDeviceId,
    required this.peerLabel,
    required this.peerKemPublicKey,
    required this.sasCode,
  });

  final LocalDeviceIdentity identity;
  final String peerDeviceId;
  final String peerLabel;
  final Uint8List peerKemPublicKey;
  final String sasCode;
}

class DecryptedEventRecord {
  const DecryptedEventRecord({required this.envelope, required this.payload});

  final EncryptedEnvelope envelope;
  final DecryptedEnvelopePayload payload;
}

class SyncEventsSnapshot {
  const SyncEventsSnapshot({required this.events, required this.isOffline});

  final List<CachedEventEntry> events;
  final bool isOffline;
}

/// High-level client repository coordinating SP-02 pairing, key delivery,
/// 24-word/QR recovery, new-device enrollment, offline encrypted cache, and E2EE event sync.
class PairingAndSyncRepository {
  PairingAndSyncRepository({
    required this._keyStore,
    DeepSkyCrypto? crypto,
    CoupleApiClient Function(String baseUrl)? clientFactory,
    EncryptedLocalCache? localCache,
  }) : _crypto = crypto ?? DeepSkyCrypto(),
       _clientFactory =
           clientFactory ?? ((String url) => CoupleApiClient(baseUrl: url)),
       _localCache = localCache ?? EncryptedLocalCache(keyStore: _keyStore);

  static const String _identityStorageKey = 'deep_sky.device_identity.v1';
  static const String _pendingInviteStorageKey = 'deep_sky.pending_invite.v1';

  final SecureKeyStore _keyStore;
  final DeepSkyCrypto _crypto;
  final CoupleApiClient Function(String baseUrl) _clientFactory;
  final EncryptedLocalCache _localCache;

  Future<LocalDeviceIdentity?> loadIdentity() async {
    final String? raw = await _keyStore.read(_identityStorageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return LocalDeviceIdentity.fromJson(
      jsonDecode(raw) as Map<String, Object?>,
    );
  }

  Future<void> saveIdentity(LocalDeviceIdentity identity) async {
    await _keyStore.write(_identityStorageKey, jsonEncode(identity.toJson()));
  }

  Future<void> savePendingInvite(CreateInviteResponse invite) async {
    await _keyStore.write(
      _pendingInviteStorageKey,
      jsonEncode(<String, Object?>{
        'coupleId': invite.coupleId,
        'deviceId': invite.deviceId,
        'inviteToken': invite.inviteToken,
        'expiresAt': invite.expiresAt.toUtc().toIso8601String(),
      }),
    );
  }

  Future<CreateInviteResponse?> loadPendingInvite() async {
    final String? raw = await _keyStore.read(_pendingInviteStorageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Map<String, Object?> json = jsonDecode(raw) as Map<String, Object?>;
      return CreateInviteResponse(
        coupleId: json['coupleId'] as String,
        deviceId: json['deviceId'] as String,
        inviteToken: json['inviteToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String).toUtc(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPendingInvite() async {
    await _keyStore.delete(_pendingInviteStorageKey);
  }

  Future<void> clearIdentity() async {
    await _localCache.clear();
    await clearPendingInvite();
    await _keyStore.delete(_identityStorageKey);
  }

  /// Partner A starts a new couple and creates an initial invite (`SP02-04`).
  Future<({LocalDeviceIdentity identity, CreateInviteResponse invite})>
  createInitialInvite({
    required String serverUrl,
    required String deviceLabel,
  }) async {
    final Uint8List recoverySeed = _crypto.generateRecoverySeed();
    final SimpleKeyPair recoveryAuthKp = await _crypto
        .deriveRecoveryAuthKeyPair(recoverySeed);
    final SimpleKeyPair authKp = await _crypto.generateDeviceAuthKeyPair();
    final SimpleKeyPair kemKp = await _crypto.generateDeviceKemKeyPair();

    final Uint8List authSeed = Uint8List.fromList(
      await authKp.extractPrivateKeyBytes(),
    );
    final Uint8List authPub = Uint8List.fromList(
      (await authKp.extractPublicKey()).bytes,
    );
    final Uint8List kemPriv = Uint8List.fromList(
      await kemKp.extractPrivateKeyBytes(),
    );
    final Uint8List kemPub = Uint8List.fromList(
      (await kemKp.extractPublicKey()).bytes,
    );
    final Uint8List recoveryAuthPub = Uint8List.fromList(
      (await recoveryAuthKp.extractPublicKey()).bytes,
    );

    final CoupleApiClient api = _clientFactory(serverUrl);
    final CreateInviteResponse invite = await api.createInitialInvite(
      deviceLabel: deviceLabel,
      deviceAuthPublicKey: authPub,
      deviceKemPublicKey: kemPub,
      recoveryAuthPublicKey: recoveryAuthPub,
    );

    final LocalDeviceIdentity identity = LocalDeviceIdentity(
      serverUrl: serverUrl,
      coupleId: invite.coupleId,
      deviceId: invite.deviceId,
      deviceLabel: deviceLabel,
      authPrivateKeySeed: authSeed,
      authPublicKey: authPub,
      kemPrivateKey: kemPriv,
      kemPublicKey: kemPub,
      recoverySeed: recoverySeed,
      pairingCompleted: false,
    );
    await saveIdentity(identity);
    await savePendingInvite(invite);
    return (identity: identity, invite: invite);
  }

  /// Existing active device creates a one-time enrollment invite for a new phone (`F-20`).
  Future<CreateInviteResponse> createEnrollmentInvite() async {
    final LocalDeviceIdentity identity = await _requireRootIdentity();
    final CreateInviteResponse invite = await _clientFactory(identity.serverUrl)
        .createEnrollmentInvite(identity: identity);
    if (!identity.pairingCompleted) {
      await savePendingInvite(invite);
    }
    return invite;
  }

  /// Partner A (or enrolling device) checks if the invite was accepted and computes SAS.
  Future<({InviteStatusResponse status, String? sasCode})> checkInviteAndSas(
    String inviteToken,
  ) async {
    final LocalDeviceIdentity identity = await _requireRootIdentity();
    final InviteStatusResponse status = await _clientFactory(identity.serverUrl)
        .getInviteStatus(identity: identity, inviteToken: inviteToken);
    if (!status.accepted || status.acceptedKemPublicKey == null) {
      return (status: status, sasCode: null);
    }

    final SimpleKeyPair myKem = await _crypto.deviceKemKeyPairFromPrivateBytes(
      identity.kemPrivateKey,
    );
    final Uint8List shared = await _crypto.computeSharedSecret(
      myKemKeyPair: myKem,
      peerKemPublicKey: status.acceptedKemPublicKey!,
    );
    final String sas = await _crypto.computeSasCode(
      sharedSecret: shared,
      coupleId: identity.coupleId,
      localKemPublicKey: identity.kemPublicKey,
      peerKemPublicKey: status.acceptedKemPublicKey!,
    );
    return (status: status, sasCode: sas);
  }

  /// Partner A confirms the SAS code matches and delivers the wrapped `recoverySeed`.
  Future<void> confirmSasAndDeliverRootKey({
    required String targetDeviceId,
    required Uint8List targetKemPublicKey,
  }) async {
    final LocalDeviceIdentity identity = await _requireRootIdentity();
    final SimpleKeyPair myKem = await _crypto.deviceKemKeyPairFromPrivateBytes(
      identity.kemPrivateKey,
    );
    final Uint8List shared = await _crypto.computeSharedSecret(
      myKemKeyPair: myKem,
      peerKemPublicKey: targetKemPublicKey,
    );
    final WrappedKeyPackage pkg = await _crypto.wrapRecoverySeed(
      recoverySeed: identity.recoverySeed!,
      sharedSecret: shared,
      coupleId: identity.coupleId,
      fromDeviceId: identity.deviceId,
      toDeviceId: targetDeviceId,
    );
    await _clientFactory(identity.serverUrl)
        .uploadKeyDelivery(identity: identity, package: pkg);
    if (!identity.pairingCompleted) {
      await saveIdentity(identity.copyWith(pairingCompleted: true));
    }
    await clearPendingInvite();
  }

  /// Partner B (or new phone) accepts an invite link/token and calculates SAS.
  Future<PendingJoinSession> acceptInvite({
    required String serverUrl,
    required String inviteToken,
    required String deviceLabel,
  }) async {
    final SimpleKeyPair authKp = await _crypto.generateDeviceAuthKeyPair();
    final SimpleKeyPair kemKp = await _crypto.generateDeviceKemKeyPair();
    final Uint8List authSeed = Uint8List.fromList(
      await authKp.extractPrivateKeyBytes(),
    );
    final Uint8List authPub = Uint8List.fromList(
      (await authKp.extractPublicKey()).bytes,
    );
    final Uint8List kemPriv = Uint8List.fromList(
      await kemKp.extractPrivateKeyBytes(),
    );
    final Uint8List kemPub = Uint8List.fromList(
      (await kemKp.extractPublicKey()).bytes,
    );

    final AcceptInviteResponse accepted = await _clientFactory(serverUrl)
        .acceptInvite(
          inviteToken: inviteToken,
          deviceLabel: deviceLabel,
          deviceAuthPublicKey: authPub,
          deviceKemPublicKey: kemPub,
        );

    final LocalDeviceIdentity identity = LocalDeviceIdentity(
      serverUrl: serverUrl,
      coupleId: accepted.coupleId,
      deviceId: accepted.deviceId,
      deviceLabel: deviceLabel,
      authPrivateKeySeed: authSeed,
      authPublicKey: authPub,
      kemPrivateKey: kemPriv,
      kemPublicKey: kemPub,
      pairingCompleted: false,
    );
    await clearPendingInvite();
    await saveIdentity(identity);

    final Uint8List shared = await _crypto.computeSharedSecret(
      myKemKeyPair: kemKp,
      peerKemPublicKey: accepted.peerKemPublicKey,
    );
    final String sas = await _crypto.computeSasCode(
      sharedSecret: shared,
      coupleId: accepted.coupleId,
      localKemPublicKey: kemPub,
      peerKemPublicKey: accepted.peerKemPublicKey,
    );

    return PendingJoinSession(
      identity: identity,
      peerDeviceId: accepted.peerDeviceId,
      peerLabel: accepted.peerLabel,
      peerKemPublicKey: accepted.peerKemPublicKey,
      sasCode: sas,
    );
  }

  /// Partner B fetches the wrapped `recoverySeed`, verifies AAD, and persists `recoverySeed`.
  Future<LocalDeviceIdentity> completeKeyDelivery({
    required PendingJoinSession session,
  }) async {
    final CoupleApiClient api = _clientFactory(session.identity.serverUrl);
    final WrappedKeyPackage pkg = await api.fetchMyKeyDelivery(
      identity: session.identity,
    );
    if (pkg.fromDeviceId != session.peerDeviceId) {
      throw const FormatException(
        'Key delivery sender does not match expected peer device.',
      );
    }

    final SimpleKeyPair myKem = await _crypto.deviceKemKeyPairFromPrivateBytes(
      session.identity.kemPrivateKey,
    );
    final Uint8List shared = await _crypto.computeSharedSecret(
      myKemKeyPair: myKem,
      peerKemPublicKey: session.peerKemPublicKey,
    );
    final Uint8List recoverySeed = await _crypto.unwrapRecoverySeed(
      package: pkg,
      sharedSecret: shared,
      expectedCoupleId: session.identity.coupleId,
      expectedToDeviceId: session.identity.deviceId,
    );

    final LocalDeviceIdentity completed = session.identity.copyWith(
      recoverySeed: recoverySeed,
      pairingCompleted: true,
    );
    await saveIdentity(completed);
    await clearPendingInvite();
    return completed;
  }

  /// Records that the user confirmed saving their 24-word/QR recovery key (`S-06`).
  Future<LocalDeviceIdentity> confirmRecoveryKeySaved() async {
    final LocalDeviceIdentity identity = await _requireRootIdentity();
    final LocalDeviceIdentity updated = identity.copyWith(
      recoverySavedConfirmed: true,
      pairingCompleted: true,
    );
    await saveIdentity(updated);
    return updated;
  }

  /// Recovers full couple access on a brand new phone from 24 words or QR alone (`SP02-05`).
  Future<LocalDeviceIdentity> recoverWithRecoveryKey({
    required String serverUrl,
    required String recoveryInput,
    required String deviceLabel,
  }) async {
    final Uint8List recoverySeed = RecoveryKeyCodec.parseUserInput(
      recoveryInput,
    );
    final SimpleKeyPair recoveryAuthKp = await _crypto
        .deriveRecoveryAuthKeyPair(recoverySeed);
    final Uint8List recoveryAuthPub = Uint8List.fromList(
      (await recoveryAuthKp.extractPublicKey()).bytes,
    );

    final CoupleApiClient api = _clientFactory(serverUrl);
    final RecoveryChallengeResponse challenge = await api
        .createRecoveryChallenge(recoveryAuthPublicKey: recoveryAuthPub);

    final SimpleKeyPair authKp = await _crypto.generateDeviceAuthKeyPair();
    final SimpleKeyPair kemKp = await _crypto.generateDeviceKemKeyPair();
    final Uint8List authSeed = Uint8List.fromList(
      await authKp.extractPrivateKeyBytes(),
    );
    final Uint8List authPub = Uint8List.fromList(
      (await authKp.extractPublicKey()).bytes,
    );
    final Uint8List kemPriv = Uint8List.fromList(
      await kemKp.extractPrivateKeyBytes(),
    );
    final Uint8List kemPub = Uint8List.fromList(
      (await kemKp.extractPublicKey()).bytes,
    );

    final String sig = await _crypto.signRecoveryClaim(
      recoveryAuthKeyPair: recoveryAuthKp,
      coupleId: challenge.coupleId,
      challengeId: challenge.challengeId,
      nonce: challenge.nonceB64,
      newDeviceAuthPublicKey: authPub,
      newDeviceKemPublicKey: kemPub,
    );

    final String newDeviceId = await api.completeRecovery(
      challengeId: challenge.challengeId,
      deviceLabel: deviceLabel,
      newDeviceAuthPublicKey: authPub,
      newDeviceKemPublicKey: kemPub,
      recoverySignatureB64: sig,
    );

    final LocalDeviceIdentity recovered = LocalDeviceIdentity(
      serverUrl: serverUrl,
      coupleId: challenge.coupleId,
      deviceId: newDeviceId,
      deviceLabel: deviceLabel,
      authPrivateKeySeed: authSeed,
      authPublicKey: authPub,
      kemPrivateKey: kemPriv,
      kemPublicKey: kemPub,
      recoverySeed: recoverySeed,
      recoverySavedConfirmed: true,
      pairingCompleted: true,
    );
    await clearPendingInvite();
    await saveIdentity(recovered);
    return recovered;
  }

  /// Encrypts and uploads an event envelope (`S-01`).
  Future<EncryptedEnvelope> sendEncryptedEvent({
    required String eventType,
    required Map<String, Object?> body,
    EnvelopeChannel channel = EnvelopeChannel.event,
    int keyEpoch = 1,
  }) async {
    final LocalDeviceIdentity identity = await _requireRootIdentity();
    final Uint8List rootKey = await _crypto.deriveCoupleRootKey(
      identity.recoverySeed!,
    );
    final String envelopeId = _crypto.generateUuidV4();
    final DecryptedEnvelopePayload payload = DecryptedEnvelopePayload(
      schemaVersion: 1,
      eventType: eventType,
      createdAtClient: DateTime.now().toUtc(),
      authorDeviceId: identity.deviceId,
      body: body,
    );
    final EncryptedEnvelope encrypted = await _crypto.encryptEnvelope(
      rootKey: rootKey,
      coupleId: identity.coupleId,
      envelopeId: envelopeId,
      senderDeviceId: identity.deviceId,
      channel: channel,
      keyEpoch: keyEpoch,
      payload: payload,
    );
    return _clientFactory(identity.serverUrl)
        .uploadEnvelope(identity: identity, envelope: encrypted);
  }

  /// Downloads and locally decrypts all envelopes after `afterSeq`,
  /// updating the encrypted local offline cache (`AD-06`, `TC-07`).
  Future<List<DecryptedEventRecord>> fetchAndDecryptEvents({
    int afterSeq = 0,
  }) async {
    final LocalDeviceIdentity identity = await _requireRootIdentity();
    final Uint8List rootKey = await _crypto.deriveCoupleRootKey(
      identity.recoverySeed!,
    );
    final List<EncryptedEnvelope> raw = await _clientFactory(identity.serverUrl)
        .listEnvelopes(identity: identity, afterSeq: afterSeq);

    final List<DecryptedEventRecord> decrypted = <DecryptedEventRecord>[];
    for (final EncryptedEnvelope env in raw) {
      final DecryptedEnvelopePayload payload = await _crypto.decryptEnvelope(
        rootKey: rootKey,
        expectedCoupleId: identity.coupleId,
        envelope: env,
      );
      decrypted.add(DecryptedEventRecord(envelope: env, payload: payload));
    }

    if (afterSeq == 0) {
      await _localCache.saveEvents(
        coupleRootKey: rootKey,
        coupleId: identity.coupleId,
        entries: decrypted.map(_toCacheEntry).toList(growable: false),
      );
    } else if (decrypted.isNotEmpty) {
      final List<CachedEventEntry> existing = await loadCachedEvents();
      final Map<String, CachedEventEntry> byId = <String, CachedEventEntry>{
        for (final CachedEventEntry entry in existing) entry.envelopeId: entry,
      };
      for (final DecryptedEventRecord rec in decrypted) {
        byId[rec.envelope.envelopeId] = _toCacheEntry(rec);
      }
      await _localCache.saveEvents(
        coupleRootKey: rootKey,
        coupleId: identity.coupleId,
        entries: byId.values.toList(growable: false),
      );
    }
    return decrypted;
  }

  /// Loads decrypted events from the encrypted local cache (`TC-07`).
  Future<List<CachedEventEntry>> loadCachedEvents() async {
    final LocalDeviceIdentity identity = await _requireRootIdentity();
    final Uint8List rootKey = await _crypto.deriveCoupleRootKey(
      identity.recoverySeed!,
    );
    return _localCache.loadEvents(
      coupleRootKey: rootKey,
      coupleId: identity.coupleId,
    );
  }

  /// Fetches live events from the server or falls back to the encrypted local
  /// cache in read-only offline mode when network connectivity fails (`TC-07`).
  Future<SyncEventsSnapshot> syncEventsWithOfflineFallback() async {
    try {
      final List<DecryptedEventRecord> fresh = await fetchAndDecryptEvents();
      return SyncEventsSnapshot(
        events: fresh.map(_toCacheEntry).toList(growable: false),
        isOffline: false,
      );
    } on ClientUpgradeRequiredException {
      rethrow;
    } on SocketException {
      return SyncEventsSnapshot(
        events: await loadCachedEvents(),
        isOffline: true,
      );
    } on http.ClientException {
      return SyncEventsSnapshot(
        events: await loadCachedEvents(),
        isOffline: true,
      );
    } on TimeoutException {
      return SyncEventsSnapshot(
        events: await loadCachedEvents(),
        isOffline: true,
      );
    }
  }

  static CachedEventEntry _toCacheEntry(DecryptedEventRecord rec) =>
      CachedEventEntry(
        envelopeId: rec.envelope.envelopeId,
        coupleId: rec.envelope.coupleId,
        senderDeviceId: rec.envelope.senderDeviceId,
        channel: rec.envelope.channel,
        keyEpoch: rec.envelope.keyEpoch,
        seq: rec.envelope.seq,
        createdAtServer: rec.envelope.createdAtServer,
        payload: rec.payload,
      );

  Future<List<DeviceSummary>> listDevices() async {
    final LocalDeviceIdentity identity = await _requireIdentity();
    return _clientFactory(identity.serverUrl).listDevices(identity: identity);
  }

  Future<void> revokeDevice(String targetDeviceId) async {
    final LocalDeviceIdentity identity = await _requireIdentity();
    await _clientFactory(identity.serverUrl)
        .revokeDevice(identity: identity, targetDeviceId: targetDeviceId);
  }

  /// Unlinks ONLY the current device on the server (best-effort) and clears
  /// local identity and encrypted offline cache (`F-20`, `S-06`).
  ///
  /// Leaves the couple and any other paired devices active. When [localOnly] is
  /// true, or if the device is already unknown/revoked (`401`/`404`) or the
  /// server is unreachable, local state is still cleared cleanly.
  Future<void> unlinkCurrentDevice({bool localOnly = false}) async {
    if (!localOnly) {
      final LocalDeviceIdentity? identity = await loadIdentity();
      if (identity != null) {
        try {
          await _clientFactory(
            identity.serverUrl,
          ).revokeDevice(identity: identity, targetDeviceId: identity.deviceId);
        } on ClientUpgradeRequiredException {
          rethrow;
        } on ApiRequestException catch (ex) {
          if (ex.statusCode != 401 && ex.statusCode != 404) {
            rethrow;
          }
        } on SocketException {
          // Offline / unreachable server: proceed with local wipe.
        } on http.ClientException {
          // Network error: proceed with local wipe.
        } on TimeoutException {
          // Timeout: proceed with local wipe.
        }
      }
    }
    await clearIdentity();
  }

  Future<void> unpairCouple() async {
    final LocalDeviceIdentity identity = await _requireIdentity();
    await _clientFactory(identity.serverUrl).unpair(identity: identity);
    await clearIdentity();
  }

  Future<Map<String, Object?>> fetchVisibilityAudit() async {
    final LocalDeviceIdentity identity = await _requireIdentity();
    return _clientFactory(identity.serverUrl)
        .fetchVisibilityAudit(identity: identity);
  }

  Future<LocalDeviceIdentity> _requireIdentity() async {
    final LocalDeviceIdentity? id = await loadIdentity();
    if (id == null) {
      throw StateError('Device is not paired yet.');
    }
    return id;
  }

  Future<LocalDeviceIdentity> _requireRootIdentity() async {
    final LocalDeviceIdentity id = await _requireIdentity();
    if (!id.hasCoupleRoot) {
      throw StateError('Couple root key is not available on this device yet.');
    }
    return id;
  }
}
