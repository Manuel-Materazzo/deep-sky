package com.vectevo.deep_sky_server.pairing;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.vectevo.deep_sky_server.push.PushService;
import com.vectevo.deep_sky_server.shared.DevicePrincipal;
import com.vectevo.deep_sky_server.shared.PartnerWakeupRequestedEvent;
import com.vectevo.deep_sky_server.shared.RateLimitExceededException;
import com.vectevo.deep_sky_server.shared.RotationRequiredException;
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.Signature;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Arrays;
import java.util.Base64;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;

/**
 * Pure JVM unit tests for CA-03 (approval state lifecycle) and CA-04 (for-update lock usage).
 */
class PairingServiceUnitTest {

	private CoupleRepository coupleRepository;
	private DeviceRepository deviceRepository;
	private PairingInviteRepository inviteRepository;
	private KeyDeliveryRepository keyDeliveryRepository;
	private RecoveryChallengeRepository challengeRepository;
	private PushService pushService;
	private ApplicationEventPublisher eventPublisher;
	private PairingService pairingService;

	@BeforeEach
	void setUp() {
		coupleRepository = mock(CoupleRepository.class);
		deviceRepository = mock(DeviceRepository.class);
		inviteRepository = mock(PairingInviteRepository.class);
		keyDeliveryRepository = mock(KeyDeliveryRepository.class);
		challengeRepository = mock(RecoveryChallengeRepository.class);
		pushService = mock(PushService.class);
		eventPublisher = mock(ApplicationEventPublisher.class);
		pairingService = new PairingService(
				coupleRepository,
				deviceRepository,
				inviteRepository,
				keyDeliveryRepository,
				challengeRepository,
				pushService,
				eventPublisher);
	}

	@Test
	void initialCreatorIsApprovedJoinerIsUnapprovedAndKeyDeliveryApprovesJoiner() {
		when(coupleRepository.findByRecoveryAuthPublicKey(any())).thenReturn(Optional.empty());
		String b64Key = Base64.getUrlEncoder().encodeToString(new byte[32]);

		var created = pairingService.createInitialInvite("Phone A", b64Key, b64Key, b64Key);
		ArgumentCaptor<DeviceEntity> savedCaptor = ArgumentCaptor.forClass(DeviceEntity.class);
		verify(deviceRepository).save(savedCaptor.capture());
		DeviceEntity creator = savedCaptor.getValue();
		assertThat(creator.getApprovedAt()).isNotNull();

		PairingInviteEntity invite = new PairingInviteEntity();
		invite.setId(UUID.randomUUID());
		invite.setCoupleId(created.coupleId());
		invite.setCreatorDeviceId(created.deviceId());
		invite.setInviteKind("INITIAL_PAIRING");
		invite.setExpiresAt(Instant.now().plusSeconds(300));

		CoupleEntity couple = new CoupleEntity();
		couple.setId(created.coupleId());

		when(inviteRepository.findByTokenHashForUpdate(any())).thenReturn(Optional.of(invite));
		when(coupleRepository.findById(created.coupleId())).thenReturn(Optional.of(couple));
		when(deviceRepository.findById(created.deviceId())).thenReturn(Optional.of(creator));

		var accepted = pairingService.acceptInvite(created.inviteToken(), "Phone B", b64Key, b64Key);
		verify(inviteRepository).findByTokenHashForUpdate(any());
		verify(eventPublisher).publishEvent(new PartnerWakeupRequestedEvent(
				created.coupleId(), accepted.deviceId(), "wakeup.pairing_request"));

		ArgumentCaptor<DeviceEntity> joinerCaptor = ArgumentCaptor.forClass(DeviceEntity.class);
		verify(deviceRepository, org.mockito.Mockito.times(2)).save(joinerCaptor.capture());
		DeviceEntity joiner = joinerCaptor.getAllValues().get(1);
		assertThat(joiner.getApprovedAt()).isNull();

		// Storing key delivery sets approvedAt on the target device
		when(deviceRepository.findById(accepted.deviceId())).thenReturn(Optional.of(joiner));
		String wrapCipher = Base64.getUrlEncoder().encodeToString(new byte[32]);
		String wrapNonce = Base64.getUrlEncoder().encodeToString(new byte[24]);
		pairingService.storeKeyDelivery(
				new DevicePrincipal(created.coupleId(), created.deviceId(), true),
				accepted.deviceId(),
				wrapNonce,
				wrapCipher);

		assertThat(joiner.getApprovedAt()).isNotNull();
	}

	@Test
	void completeRecoveryLocksChallengeAndApprovesRecoveredDevice() throws Exception {
		UUID coupleId = UUID.randomUUID();
		UUID challengeId = UUID.randomUUID();
		KeyPair recKp = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
		byte[] recPubEncoded = recKp.getPublic().getEncoded();
		byte[] recPubRaw = Arrays.copyOfRange(recPubEncoded, recPubEncoded.length - 32, recPubEncoded.length);
		byte[] nonce = new byte[32];

		CoupleEntity couple = new CoupleEntity();
		couple.setId(coupleId);
		couple.setRecoveryAuthPublicKey(recPubRaw);

		RecoveryChallengeEntity challenge = new RecoveryChallengeEntity();
		challenge.setId(challengeId);
		challenge.setCoupleId(coupleId);
		challenge.setNonce(nonce);
		challenge.setExpiresAt(Instant.now().plusSeconds(300));

		when(challengeRepository.findByIdForUpdate(challengeId)).thenReturn(Optional.of(challenge));
		when(coupleRepository.findById(coupleId)).thenReturn(Optional.of(couple));

		String b64Key = Base64.getUrlEncoder().encodeToString(new byte[32]);
		String claim = String.join(
				"|",
				"deep-sky:recovery:v1",
				coupleId.toString(),
				challengeId.toString(),
				Base64.getUrlEncoder().encodeToString(nonce),
				b64Key,
				b64Key);
		Signature sig = Signature.getInstance("Ed25519");
		sig.initSign(recKp.getPrivate());
		sig.update(claim.getBytes(StandardCharsets.UTF_8));
		String sigB64 = Base64.getUrlEncoder().encodeToString(sig.sign());

		pairingService.completeRecovery(challengeId, "Recovered", b64Key, b64Key, sigB64);
		verify(challengeRepository).findByIdForUpdate(challengeId);

		ArgumentCaptor<DeviceEntity> recoveredCaptor = ArgumentCaptor.forClass(DeviceEntity.class);
		verify(deviceRepository).save(recoveredCaptor.capture());
		assertThat(recoveredCaptor.getValue().getApprovedAt()).isNotNull();
		assertThat(challenge.getUsedAt()).isNotNull();

		// Second attempt on same challenge throws conflict
		assertThatThrownBy(() -> pairingService.completeRecovery(challengeId, "Recovered", b64Key, b64Key, sigB64))
				.isInstanceOf(IllegalStateException.class);
	}

	@Test
	void cleanupPurgesOrphanNeverPairedCouplesWithoutTouchingActiveState() {
		RequestNonceRepository nonceRepository = mock(RequestNonceRepository.class);
		PairingCleanupService cleanup = new PairingCleanupService(
				nonceRepository,
				challengeRepository,
				inviteRepository,
				deviceRepository,
				coupleRepository,
				pushService);
		UUID orphanCoupleId = UUID.randomUUID();
		Instant cutoff = Instant.now();
		when(coupleRepository.findOrphanNeverPairedCoupleIds(cutoff)).thenReturn(List.of(orphanCoupleId));

		int removed = cleanup.purgeOrphanNeverPairedCouples(cutoff);
		assertThat(removed).isEqualTo(1);
		verify(pushService).unregisterCouple(orphanCoupleId);
		verify(deviceRepository).deleteByCoupleId(orphanCoupleId);
		verify(coupleRepository).deleteAllByIdInBatch(List.of(orphanCoupleId));
	}

	@Test
	void revokeDeviceWithEpochRotationUpdatesCoupleAndDeliversOnlyToActiveApprovedPeers() {
		UUID coupleId = UUID.randomUUID();
		UUID deviceAId = UUID.randomUUID();
		UUID revokedBId = UUID.randomUUID();
		UUID survivingCId = UUID.randomUUID();

		CoupleEntity couple = new CoupleEntity();
		couple.setId(coupleId);
		couple.setCurrentKeyEpoch(1);
		couple.setRecoveryAuthPublicKey(new byte[32]);

		DeviceEntity devA = new DeviceEntity();
		devA.setId(deviceAId);
		devA.setCoupleId(coupleId);
		devA.setApprovedAt(Instant.now());

		DeviceEntity devB = new DeviceEntity();
		devB.setId(revokedBId);
		devB.setCoupleId(coupleId);
		devB.setApprovedAt(Instant.now());

		DeviceEntity devC = new DeviceEntity();
		devC.setId(survivingCId);
		devC.setCoupleId(coupleId);
		devC.setApprovedAt(Instant.now());

		when(deviceRepository.findById(revokedBId)).thenReturn(Optional.of(devB));
		when(deviceRepository.findById(survivingCId)).thenReturn(Optional.of(devC));
		when(deviceRepository.findAllByCoupleIdOrderByCreatedAtAsc(coupleId)).thenReturn(List.of(devA, devB, devC));
		when(coupleRepository.findByIdForUpdate(coupleId)).thenReturn(Optional.of(couple));
		when(coupleRepository.findByRecoveryAuthPublicKey(any())).thenReturn(Optional.empty());

		String b64Key = Base64.getUrlEncoder().encodeToString(new byte[32]);
		String b64Nonce = Base64.getUrlEncoder().encodeToString(new byte[24]);
		String b64Cipher = Base64.getUrlEncoder().encodeToString(new byte[40]);

		// Missing surviving peer C must be rejected
		var missingPeerRotation = new PairingService.EpochRotationRequestData(
				2, b64Key, b64Nonce, b64Cipher, List.of());
		assertThatThrownBy(() -> pairingService.revokeDevice(
				new DevicePrincipal(coupleId, deviceAId, true), revokedBId, missingPeerRotation))
				.isInstanceOf(IllegalArgumentException.class);

		// Valid rotation targets surviving peer C and bumps epoch to 2
		var validRotation = new PairingService.EpochRotationRequestData(
				2,
				b64Key,
				b64Nonce,
				b64Cipher,
				List.of(new PairingService.EpochKeyDeliveryInput(survivingCId, b64Nonce, b64Cipher)));
		pairingService.revokeDevice(new DevicePrincipal(coupleId, deviceAId, true), revokedBId, validRotation);

		assertThat(devB.getRevokedAt()).isNotNull();
		assertThat(couple.getCurrentKeyEpoch()).isEqualTo(2);
		ArgumentCaptor<KeyDeliveryEntity> kdCaptor = ArgumentCaptor.forClass(KeyDeliveryEntity.class);
		verify(keyDeliveryRepository).save(kdCaptor.capture());
		assertThat(kdCaptor.getValue().getToDeviceId()).isEqualTo(survivingCId);
		assertThat(kdCaptor.getValue().getDeliveryKind()).isEqualTo("EPOCH_ROTATION");
		assertThat(kdCaptor.getValue().getKeyEpoch()).isEqualTo(2);
	}

	@Test
	void recoveryEndpointsEnforcePerCoupleSlidingWindowRateLimit() {
		Clock fixedClock = Clock.fixed(Instant.parse("2026-11-17T22:00:00Z"), ZoneOffset.UTC);
		PairingService limited = new PairingService(
				coupleRepository,
				deviceRepository,
				inviteRepository,
				keyDeliveryRepository,
				challengeRepository,
				pushService,
				eventPublisher,
				fixedClock,
				2,
				15);

		UUID coupleAId = UUID.randomUUID();
		CoupleEntity coupleA = new CoupleEntity();
		coupleA.setId(coupleAId);
		byte[] keyA = new byte[32];
		Arrays.fill(keyA, (byte) 0x0A);
		String b64KeyA = Base64.getUrlEncoder().encodeToString(keyA);

		UUID coupleBId = UUID.randomUUID();
		CoupleEntity coupleB = new CoupleEntity();
		coupleB.setId(coupleBId);
		byte[] keyB = new byte[32];
		Arrays.fill(keyB, (byte) 0x0B);
		String b64KeyB = Base64.getUrlEncoder().encodeToString(keyB);

		when(coupleRepository.findByRecoveryAuthPublicKey(keyA)).thenReturn(Optional.of(coupleA));
		when(coupleRepository.findByRecoveryAuthPublicKey(keyB)).thenReturn(Optional.of(coupleB));

		// AU-23: Creating challenges using the public recovery key does not lock out the couple
		assertThat(limited.createRecoveryChallenge(b64KeyA).coupleId()).isEqualTo(coupleAId);
		assertThat(limited.createRecoveryChallenge(b64KeyA).coupleId()).isEqualTo(coupleAId);
		assertThat(limited.createRecoveryChallenge(b64KeyA).coupleId()).isEqualTo(coupleAId);
		assertThat(limited.createRecoveryChallenge(b64KeyB).coupleId()).isEqualTo(coupleBId);

		// Invalid signature attempts on completeRecovery are capped per couple (AU-23)
		UUID challengeAId = UUID.randomUUID();
		RecoveryChallengeEntity challengeA = new RecoveryChallengeEntity();
		challengeA.setId(challengeAId);
		challengeA.setCoupleId(coupleAId);
		challengeA.setNonce(new byte[32]);
		challengeA.setExpiresAt(fixedClock.instant().plusSeconds(300));
		coupleA.setRecoveryAuthPublicKey(keyA);
		when(challengeRepository.findByIdForUpdate(challengeAId)).thenReturn(Optional.of(challengeA));
		when(coupleRepository.findById(coupleAId)).thenReturn(Optional.of(coupleA));

		String badSig = Base64.getUrlEncoder().encodeToString(new byte[64]);
		assertThatThrownBy(() -> limited.completeRecovery(challengeAId, "Phone", b64KeyA, b64KeyA, badSig))
				.isInstanceOf(SecurityException.class);
		assertThatThrownBy(() -> limited.completeRecovery(challengeAId, "Phone", b64KeyA, b64KeyA, badSig))
				.isInstanceOf(SecurityException.class);
		assertThatThrownBy(() -> limited.completeRecovery(challengeAId, "Phone", b64KeyA, b64KeyA, badSig))
				.isInstanceOf(RateLimitExceededException.class);
	}

	@Test
	void storeKeyDeliveryRejectsMismatchedEpochAndFetchNeverFallsBackToEpochRotation() {
		UUID coupleId = UUID.randomUUID();
		UUID deviceAId = UUID.randomUUID();
		UUID deviceBId = UUID.randomUUID();

		CoupleEntity couple = new CoupleEntity();
		couple.setId(coupleId);
		couple.setCurrentKeyEpoch(2);
		DeviceEntity devB = new DeviceEntity();
		devB.setId(deviceBId);
		devB.setCoupleId(coupleId);

		when(deviceRepository.findById(deviceBId)).thenReturn(Optional.of(devB));
		when(coupleRepository.findById(coupleId)).thenReturn(Optional.of(couple));

		String nonce = Base64.getUrlEncoder().encodeToString(new byte[24]);
		String cipher = Base64.getUrlEncoder().encodeToString(new byte[40]);
		// AU-27: mismatched keyEpoch is rejected
		assertThatThrownBy(() -> pairingService.storeKeyDelivery(
				new DevicePrincipal(coupleId, deviceAId, true), deviceBId, nonce, cipher, 1))
				.isInstanceOf(IllegalArgumentException.class);

		// AU-27: fetchPendingKeyDelivery only queries PAIRING_SEED and never falls back to EPOCH_ROTATION
		when(keyDeliveryRepository.findFirstByToDeviceIdAndDeliveryKindOrderByKeyEpochDescCreatedAtDesc(
				deviceBId, "PAIRING_SEED")).thenReturn(Optional.empty());
		assertThatThrownBy(() -> pairingService.fetchPendingKeyDelivery(
				new DevicePrincipal(coupleId, deviceBId, false)))
				.isInstanceOf(java.util.NoSuchElementException.class);
	}

	@Test
	void pd19ServerAcceptsLegacyPayloadsWithoutKeyEpochOrRotationBody() {
		UUID coupleId = UUID.randomUUID();
		UUID deviceAId = UUID.randomUUID();
		UUID deviceBId = UUID.randomUUID();

		CoupleEntity couple = new CoupleEntity();
		couple.setId(coupleId);
		couple.setCurrentKeyEpoch(1);
		DeviceEntity devB = new DeviceEntity();
		devB.setId(deviceBId);
		devB.setCoupleId(coupleId);

		when(deviceRepository.findById(deviceBId)).thenReturn(Optional.of(devB));
		when(coupleRepository.findById(coupleId)).thenReturn(Optional.of(couple));

		String nonce = Base64.getUrlEncoder().encodeToString(new byte[24]);
		String cipher = Base64.getUrlEncoder().encodeToString(new byte[40]);
		pairingService.storeKeyDelivery(new DevicePrincipal(coupleId, deviceAId, true), deviceBId, nonce, cipher);
		ArgumentCaptor<KeyDeliveryEntity> kdCaptor = ArgumentCaptor.forClass(KeyDeliveryEntity.class);
		verify(keyDeliveryRepository).save(kdCaptor.capture());
		assertThat(kdCaptor.getValue().getKeyEpoch()).isEqualTo(1);
		assertThat(kdCaptor.getValue().getDeliveryKind()).isEqualTo("PAIRING_SEED");

		// Legacy empty-body self-revoke succeeds without touching keyEpoch
		pairingService.revokeDevice(new DevicePrincipal(coupleId, deviceBId, true), deviceBId);
		assertThat(devB.getRevokedAt()).isNotNull();
		assertThat(couple.getCurrentKeyEpoch()).isEqualTo(1);
	}

	@Test
	void revokingAnotherApprovedDeviceWithoutRotationIsRejectedWithRotationRequired() {
		UUID coupleId = UUID.randomUUID();
		UUID deviceAId = UUID.randomUUID();
		UUID deviceBId = UUID.randomUUID();
		UUID unapprovedCId = UUID.randomUUID();

		DeviceEntity devB = new DeviceEntity();
		devB.setId(deviceBId);
		devB.setCoupleId(coupleId);
		devB.setApprovedAt(Instant.now());

		DeviceEntity devC = new DeviceEntity();
		devC.setId(unapprovedCId);
		devC.setCoupleId(coupleId);
		devC.setApprovedAt(null);

		when(deviceRepository.findById(deviceBId)).thenReturn(Optional.of(devB));
		when(deviceRepository.findById(unapprovedCId)).thenReturn(Optional.of(devC));

		DevicePrincipal principalA = new DevicePrincipal(coupleId, deviceAId, true);
		assertThatThrownBy(() -> pairingService.revokeDevice(principalA, deviceBId, null))
				.isInstanceOf(RotationRequiredException.class);
		assertThat(devB.getRevokedAt()).isNull();

		// Revoking an unapproved peer without rotation remains allowed
		pairingService.revokeDevice(principalA, unapprovedCId, null);
		assertThat(devC.getRevokedAt()).isNotNull();
	}
}
