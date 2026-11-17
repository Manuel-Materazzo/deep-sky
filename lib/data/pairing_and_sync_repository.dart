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
        if (invite.sasSecret != null) 'sasSecret': invite.sasSecret,
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
        sasSecret: json['sasSecret'] as String?,
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
    final CreateInviteResponse serverInvite = await api.createInitialInvite(
      deviceLabel: deviceLabel,
      deviceAuthPublicKey: authPub,
      deviceKemPublicKey: kemPub,
      recoveryAuthPublicKey: recoveryAuthPub,
    );
    final CreateInviteResponse invite = serverInvite.copyWith(
      sasSecret: _crypto.generateSasSecretB64(),
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
      nameSetupCompleted: false,
    );
    await saveIdentity(identity);
    await savePendingInvite(invite);
    return (identity: identity, invite: invite);
  }

  /// Existing active device creates a one-time enrollment invite for a new phone (`F-20`).
  Future<CreateInviteResponse> createEnrollmentInvite() async {
    final LocalDeviceIdentity identity = await _requireRootIdentity();
    final CreateInviteResponse serverInvite = await _clientFactory(
      identity.serverUrl,
    ).createEnrollmentInvite(identity: identity);
    final CreateInviteResponse invite = serverInvite.copyWith(
      sasSecret: _crypto.generateSasSecretB64(),
    );
    await savePendingInvite(invite);
    return invite;
  }

  /// Partner A (or enrolling device) checks if the invite was accepted and computes SAS.
  Future<({InviteStatusResponse status, String? sasCode})> checkInviteAndSas(
    String inviteToken, {
    String? sasSecret,
  }) async {
    final LocalDeviceIdentity identity = await _requireRootIdentity();
    final InviteStatusResponse status = await _clientFactory(identity.serverUrl)
        .getInviteStatus(identity: identity, inviteToken: inviteToken);
    if (!status.accepted || status.acceptedKemPublicKey == null) {
      return (status: status, sasCode: null);
    }

    String? resolvedSas = sasSecret?.trim();
    if (resolvedSas == null || resolvedSas.isEmpty) {
      final CreateInviteResponse? pending = await loadPendingInvite();
      if (pending != null && pending.inviteToken == inviteToken) {
        resolvedSas = pending.sasSecret;
      }
    }
    if (resolvedSas == null || resolvedSas.isEmpty) {
      throw StateError(
        'Missing out-of-band SAS secret for invite $inviteToken.',
      );
    }
    final Uint8List sasSecretBytes = DeepSkyCrypto.decodeSasSecretB64(
      resolvedSas,
    );

    final SimpleKeyPair myKem = await _crypto.deviceKemKeyPairFromPrivateBytes(
      identity.kemPrivateKey,
    );
    final Uint8List shared = await _crypto.computeSharedSecret(
      myKemKeyPair: myKem,
      peerKemPublicKey: status.acceptedKemPublicKey!,
    );
    final String sas = await _crypto.computeSasCode(
      sharedSecret: shared,
      sasSecret: sasSecretBytes,
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
    final WrappedKeyPackage pkg;
    if (identity.currentKeyEpoch > 1 || identity.epochSecrets.isNotEmpty) {
      pkg = await _crypto.wrapKeyBundle(
        bundle: KeyBundle(
          recoverySeed: identity.recoverySeed!,
          currentKeyEpoch: identity.currentKeyEpoch,
          epochSecrets: identity.epochSecrets,
        ),
        sharedSecret: shared,
        coupleId: identity.coupleId,
        fromDeviceId: identity.deviceId,
        toDeviceId: targetDeviceId,
        keyEpoch: identity.currentKeyEpoch,
        deliveryKind: 'PAIRING_SEED',
      );
    } else {
      pkg = await _crypto.wrapRecoverySeed(
        recoverySeed: identity.recoverySeed!,
        sharedSecret: shared,
        coupleId: identity.coupleId,
        fromDeviceId: identity.deviceId,
        toDeviceId: targetDeviceId,
      );
    }
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
    required String sasSecret,
    required String deviceLabel,
  }) async {
    final Uint8List sasSecretBytes = DeepSkyCrypto.decodeSasSecretB64(
      sasSecret,
    );
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
      nameSetupCompleted: false,
    );
    await clearPendingInvite();
    await saveIdentity(identity);

    final Uint8List shared = await _crypto.computeSharedSecret(
      myKemKeyPair: kemKp,
      peerKemPublicKey: accepted.peerKemPublicKey,
    );
    final String sas = await _crypto.computeSasCode(
      sharedSecret: shared,
      sasSecret: sasSecretBytes,
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
    final KeyBundle bundle = await _crypto.unwrapKeyBundle(
      package: pkg,
      sharedSecret: shared,
      expectedCoupleId: session.identity.coupleId,
      expectedToDeviceId: session.identity.deviceId,
    );

    final LocalDeviceIdentity completed = session.identity.copyWith(
      recoverySeed: bundle.recoverySeed,
      currentKeyEpoch: bundle.currentKeyEpoch,
      epochSecrets: bundle.epochSecrets,
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

    final RecoveryCompleteResponse recoveryRes = await api.completeRecovery(
      challengeId: challenge.challengeId,
      deviceLabel: deviceLabel,
      newDeviceAuthPublicKey: authPub,
      newDeviceKemPublicKey: kemPub,
      recoverySignatureB64: sig,
    );

    Map<int, Uint8List> epochSecrets = const <int, Uint8List>{};
    if (recoveryRes.currentKeyEpoch >= 2) {
      if (recoveryRes.recoveryKeyringNonce == null ||
          recoveryRes.recoveryKeyringCiphertextWithTag == null) {
        throw StateError(
          'Missing recovery keyring for couple at keyEpoch=${recoveryRes.currentKeyEpoch}.',
        );
      }
      epochSecrets = await _crypto.decryptRecoveryKeyring(
        recoverySeed: recoverySeed,
        coupleId: challenge.coupleId,
        currentKeyEpoch: recoveryRes.currentKeyEpoch,
        nonce: recoveryRes.recoveryKeyringNonce!,
        ciphertextWithTag: recoveryRes.recoveryKeyringCiphertextWithTag!,
      );
    }

    final LocalDeviceIdentity recovered = LocalDeviceIdentity(
      serverUrl: serverUrl,
      coupleId: challenge.coupleId,
      deviceId: recoveryRes.deviceId,
      deviceLabel: deviceLabel,
      authPrivateKeySeed: authSeed,
      authPublicKey: authPub,
      kemPrivateKey: kemPriv,
      kemPublicKey: kemPub,
      recoverySeed: recoverySeed,
      currentKeyEpoch: recoveryRes.currentKeyEpoch,
      epochSecrets: epochSecrets,
      recoverySavedConfirmed: true,
      pairingCompleted: true,
      nameSetupCompleted: false,
    );
    await clearPendingInvite();
    await saveIdentity(recovered);
    return recovered;
  }

  /// Encrypts and uploads an event envelope (`S-01`, `CA-02`).
  Future<EncryptedEnvelope> sendEncryptedEvent({
    required String eventType,
    required Map<String, Object?> body,
    EnvelopeChannel channel = EnvelopeChannel.event,
    int? keyEpoch,
  }) async {
    LocalDeviceIdentity identity = await _requireRootIdentity();
    final CoupleApiClient api = _clientFactory(identity.serverUrl);
    final String envelopeId = _crypto.generateUuidV4();
    final DecryptedEnvelopePayload payload = DecryptedEnvelopePayload(
      schemaVersion: 1,
      eventType: eventType,
      createdAtClient: DateTime.now().toUtc(),
      authorDeviceId: identity.deviceId,
      body: body,
    );

    Future<EncryptedEnvelope> buildAndUpload(LocalDeviceIdentity id) async {
      final int effectiveEpoch = keyEpoch ?? id.currentKeyEpoch;
      final Uint8List rootKey =
          id.epochSecrets[1] ??
          await _crypto.deriveCoupleRootKey(id.recoverySeed!);
      final EncryptedEnvelope encrypted = await _crypto.encryptEnvelope(
        rootKey: rootKey,
        epochSecret: effectiveEpoch >= 2
            ? id.epochSecrets[effectiveEpoch]
            : null,
        coupleId: id.coupleId,
        envelopeId: envelopeId,
        senderDeviceId: id.deviceId,
        channel: channel,
        keyEpoch: effectiveEpoch,
        payload: payload,
      );
      return api.uploadEnvelope(identity: id, envelope: encrypted);
    }

    try {
      return await buildAndUpload(identity);
    } on ApiRequestException catch (ex) {
      if (!ex.isStaleKeyEpoch || keyEpoch != null) {
        rethrow;
      }
      identity = await _syncEpochFromServer(api, identity);
      return buildAndUpload(identity);
    }
  }

  /// Downloads and locally decrypts all envelopes after `afterSeq`,
  /// syncing any new epoch rotation bundles first (`CA-02`, `AD-06`, `TC-07`).
  Future<List<DecryptedEventRecord>> fetchAndDecryptEvents({
    int afterSeq = 0,
  }) async {
    LocalDeviceIdentity identity = await _requireRootIdentity();
    final CoupleApiClient api = _clientFactory(identity.serverUrl);
    final pageRes = await api.listEnvelopesWithEpoch(
      identity: identity,
      afterSeq: afterSeq,
    );
    if (pageRes.coupleKeyEpoch > identity.currentKeyEpoch) {
      identity = await _syncEpochFromServer(api, identity);
    }
    final Uint8List activeRootKey = await _crypto.deriveCoupleRootKey(
      identity.recoverySeed!,
    );
    final Uint8List epoch1RootKey = identity.epochSecrets[1] ?? activeRootKey;

    final List<DecryptedEventRecord> decrypted = <DecryptedEventRecord>[];
    for (final EncryptedEnvelope env in pageRes.envelopes) {
      final DecryptedEnvelopePayload payload = await _crypto.decryptEnvelope(
        rootKey: epoch1RootKey,
        epochSecrets: identity.epochSecrets,
        expectedCoupleId: identity.coupleId,
        envelope: env,
      );
      decrypted.add(DecryptedEventRecord(envelope: env, payload: payload));
    }

    if (afterSeq == 0) {
      await _localCache.saveEvents(
        coupleRootKey: activeRootKey,
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
        coupleRootKey: activeRootKey,
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

  /// Updates the visible label for the current device locally and on the server (`S1-D07-2`).
  ///
  /// When [bestEffortRemote] is true (e.g. completing the initial welcome setup),
  /// a missing endpoint on older servers (`404`/`405`) or transient offline
  /// failure will not block local completion.
  Future<LocalDeviceIdentity> updateOwnDeviceLabel({
    required String deviceLabel,
    bool markNameSetupCompleted = false,
    bool bestEffortRemote = false,
  }) async {
    final LocalDeviceIdentity current = await _requireIdentity();
    final String trimmed = deviceLabel.trim();
    final String clean = trimmed.length > 64
        ? trimmed.substring(0, 64)
        : trimmed;
    final LocalDeviceIdentity updated = current.copyWith(
      deviceLabel: clean,
      nameSetupCompleted: markNameSetupCompleted
          ? true
          : current.nameSetupCompleted,
    );
    await saveIdentity(updated);

    try {
      await _clientFactory(updated.serverUrl)
          .updateMyDeviceLabel(identity: updated, deviceLabel: clean);
    } on ClientUpgradeRequiredException {
      rethrow;
    } on ApiRequestException catch (ex) {
      if (bestEffortRemote || ex.statusCode == 404 || ex.statusCode == 405) {
        return updated;
      }
      rethrow;
    } on SocketException {
      if (!bestEffortRemote) rethrow;
    } on http.ClientException {
      if (!bestEffortRemote) rethrow;
    } on TimeoutException {
      if (!bestEffortRemote) rethrow;
    }
    return updated;
  }

  Future<List<DeviceSummary>> listDevices() async {
    final LocalDeviceIdentity identity = await _requireIdentity();
    return _clientFactory(identity.serverUrl).listDevices(identity: identity);
  }

  /// Revokes a device and, when revoking a peer device, atomically rotates
  /// epoch keys, recovery seed, and recovery keyring (`CA-02`, `ADR-0012`).
  Future<LocalDeviceIdentity> revokeDevice(String targetDeviceId) async {
    final LocalDeviceIdentity identity = await _requireRootIdentity();
    final CoupleApiClient api = _clientFactory(identity.serverUrl);
    if (targetDeviceId == identity.deviceId) {
      await api.revokeDevice(
        identity: identity,
        targetDeviceId: targetDeviceId,
      );
      return identity;
    }

    final List<DeviceSummary> devices = await api.listDevices(
      identity: identity,
    );
    final List<DeviceSummary> peersToRekey = devices
        .where(
          (DeviceSummary d) =>
              d.revokedAt == null &&
              d.approved &&
              d.deviceId != identity.deviceId &&
              d.deviceId != targetDeviceId,
        )
        .toList(growable: false);

    final int nextEpoch = identity.currentKeyEpoch + 1;
    final Uint8List oldActiveRootKey = await _crypto.deriveCoupleRootKey(
      identity.recoverySeed!,
    );
    final Uint8List epoch1RootKey =
        identity.epochSecrets[1] ?? oldActiveRootKey;
    final Uint8List newEpochSecret = _crypto.generateEpochSecret();
    final Uint8List newRecoverySeed = _crypto.generateRecoverySeed();
    final Map<int, Uint8List> nextEpochs = Map<int, Uint8List>.unmodifiable(
      <int, Uint8List>{
        ...identity.epochSecrets,
        1: epoch1RootKey,
        nextEpoch: newEpochSecret,
      },
    );

    final SimpleKeyPair newRecoveryAuthKp = await _crypto
        .deriveRecoveryAuthKeyPair(newRecoverySeed);
    final Uint8List newRecoveryAuthPub = Uint8List.fromList(
      (await newRecoveryAuthKp.extractPublicKey()).bytes,
    );
    final keyring = await _crypto.encryptRecoveryKeyring(
      recoverySeed: newRecoverySeed,
      coupleId: identity.coupleId,
      currentKeyEpoch: nextEpoch,
      epochSecrets: nextEpochs,
    );

    final KeyBundle bundle = KeyBundle(
      recoverySeed: newRecoverySeed,
      currentKeyEpoch: nextEpoch,
      epochSecrets: nextEpochs,
    );
    final SimpleKeyPair myKem = await _crypto.deviceKemKeyPairFromPrivateBytes(
      identity.kemPrivateKey,
    );
    final List<Map<String, Object?>> deliveries = <Map<String, Object?>>[];
    for (final DeviceSummary peer in peersToRekey) {
      if (peer.kemPublicKey == null || peer.kemPublicKey!.length != 32) {
        throw StateError(
          'Missing KEM public key for surviving device ${peer.deviceId}.',
        );
      }
      final Uint8List shared = await _crypto.computeSharedSecret(
        myKemKeyPair: myKem,
        peerKemPublicKey: peer.kemPublicKey!,
      );
      final WrappedKeyPackage pkg = await _crypto.wrapKeyBundle(
        bundle: bundle,
        sharedSecret: shared,
        coupleId: identity.coupleId,
        fromDeviceId: identity.deviceId,
        toDeviceId: peer.deviceId,
        keyEpoch: nextEpoch,
        deliveryKind: 'EPOCH_ROTATION',
      );
      deliveries.add(<String, Object?>{
        'toDeviceId': peer.deviceId,
        'nonceB64': base64UrlEncode(pkg.nonce),
        'ciphertextB64': base64UrlEncode(pkg.ciphertextWithTag),
      });
    }

    await api.revokeDevice(
      identity: identity,
      targetDeviceId: targetDeviceId,
      rotationBody: <String, Object?>{
        'targetEpoch': nextEpoch,
        'newRecoveryAuthPublicKeyB64': base64UrlEncode(newRecoveryAuthPub),
        'recoveryKeyringNonceB64': base64UrlEncode(keyring.nonce),
        'recoveryKeyringCiphertextB64': base64UrlEncode(
          keyring.ciphertextWithTag,
        ),
        'deliveries': deliveries,
      },
    );

    final LocalDeviceIdentity rotated = identity.copyWith(
      recoverySeed: newRecoverySeed,
      currentKeyEpoch: nextEpoch,
      epochSecrets: nextEpochs,
      recoverySavedConfirmed: false,
    );
    await _reencryptLocalCacheBestEffort(
      oldRootKey: oldActiveRootKey,
      newIdentity: rotated,
    );
    await saveIdentity(rotated);
    return rotated;
  }

  Future<LocalDeviceIdentity> _syncEpochFromServer(
    CoupleApiClient api,
    LocalDeviceIdentity identity,
  ) async {
    final EpochRotationStateResponse rot = await api.fetchMyEpochRotation(
      identity: identity,
    );
    final WrappedKeyPackage? pkg = rot.pendingDelivery;
    if (pkg == null) {
      throw StateError(
        'Missing epoch rotation delivery (server epoch=${rot.currentKeyEpoch}).',
      );
    }
    final List<DeviceSummary> devices = await api.listDevices(
      identity: identity,
    );
    final DeviceSummary sender = devices.firstWhere(
      (DeviceSummary d) => d.deviceId == pkg.fromDeviceId,
      orElse: () => throw StateError(
        'Epoch rotation sender ${pkg.fromDeviceId} not found.',
      ),
    );
    if (sender.kemPublicKey == null || sender.kemPublicKey!.length != 32) {
      throw StateError(
        'Missing KEM public key for epoch rotation sender ${pkg.fromDeviceId}.',
      );
    }

    final SimpleKeyPair myKem = await _crypto.deviceKemKeyPairFromPrivateBytes(
      identity.kemPrivateKey,
    );
    final Uint8List shared = await _crypto.computeSharedSecret(
      myKemKeyPair: myKem,
      peerKemPublicKey: sender.kemPublicKey!,
    );
    final KeyBundle bundle = await _crypto.unwrapKeyBundle(
      package: pkg,
      sharedSecret: shared,
      expectedCoupleId: identity.coupleId,
      expectedToDeviceId: identity.deviceId,
    );

    final Uint8List oldActiveRootKey = await _crypto.deriveCoupleRootKey(
      identity.recoverySeed!,
    );
    final LocalDeviceIdentity updated = identity.copyWith(
      recoverySeed: bundle.recoverySeed,
      currentKeyEpoch: bundle.currentKeyEpoch,
      epochSecrets: bundle.epochSecrets,
      recoverySavedConfirmed: false,
    );
    await _reencryptLocalCacheBestEffort(
      oldRootKey: oldActiveRootKey,
      newIdentity: updated,
    );
    await saveIdentity(updated);
    return updated;
  }

  Future<void> _reencryptLocalCacheBestEffort({
    required Uint8List oldRootKey,
    required LocalDeviceIdentity newIdentity,
  }) async {
    try {
      final List<CachedEventEntry> cached = await _localCache.loadEvents(
        coupleRootKey: oldRootKey,
        coupleId: newIdentity.coupleId,
      );
      if (cached.isNotEmpty) {
        final Uint8List newRootKey = await _crypto.deriveCoupleRootKey(
          newIdentity.recoverySeed!,
        );
        await _localCache.saveEvents(
          coupleRootKey: newRootKey,
          coupleId: newIdentity.coupleId,
          entries: cached,
        );
      }
    } catch (_) {
      // Cache will be rebuilt by fetchAndDecryptEvents if unavailable.
    }
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
