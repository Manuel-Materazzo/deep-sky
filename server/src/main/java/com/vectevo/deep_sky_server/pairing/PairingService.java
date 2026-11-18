package com.vectevo.deep_sky_server.pairing;

import com.vectevo.deep_sky_server.push.PushService;
import com.vectevo.deep_sky_server.shared.DevicePrincipal;
import com.vectevo.deep_sky_server.shared.Ed25519SignatureVerifier;
import com.vectevo.deep_sky_server.shared.PartnerWakeupRequestedEvent;
import com.vectevo.deep_sky_server.shared.RateLimitExceededException;
import com.vectevo.deep_sky_server.shared.SlidingWindowLimiter;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import java.util.HashSet;
import java.util.List;
import java.util.NoSuchElementException;
import java.util.Set;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Pairing, new-device enrollment, recovery, and device revocation orchestration (`SP-02`, `F-01`, `F-20`, `S-03`, `S-06`).
 */
@Service
public class PairingService {

	private static final Duration INVITE_TTL = Duration.ofMinutes(15);
	private static final Duration CHALLENGE_TTL = Duration.ofMinutes(5);

	private final CoupleRepository coupleRepository;
	private final DeviceRepository deviceRepository;
	private final PairingInviteRepository inviteRepository;
	private final KeyDeliveryRepository keyDeliveryRepository;
	private final RecoveryChallengeRepository challengeRepository;
	private final PushService pushService;
	private final ApplicationEventPublisher eventPublisher;
	private final Clock clock;
	private final SlidingWindowLimiter coupleRecoveryLimiter;
	private final SecureRandom secureRandom = new SecureRandom();

	public PairingService(
			CoupleRepository coupleRepository,
			DeviceRepository deviceRepository,
			PairingInviteRepository inviteRepository,
			KeyDeliveryRepository keyDeliveryRepository,
			RecoveryChallengeRepository challengeRepository,
			PushService pushService,
			ApplicationEventPublisher eventPublisher) {
		this(
				coupleRepository,
				deviceRepository,
				inviteRepository,
				keyDeliveryRepository,
				challengeRepository,
				pushService,
				eventPublisher,
				Clock.systemUTC(),
				5,
				15);
	}

	@Autowired
	public PairingService(
			CoupleRepository coupleRepository,
			DeviceRepository deviceRepository,
			PairingInviteRepository inviteRepository,
			KeyDeliveryRepository keyDeliveryRepository,
			RecoveryChallengeRepository challengeRepository,
			PushService pushService,
			ApplicationEventPublisher eventPublisher,
			Clock clock,
			@Value("${deepsky.rate-limit.couple-recovery-max:5}") int coupleRecoveryMaxAttempts,
			@Value("${deepsky.rate-limit.couple-recovery-window-minutes:15}") int coupleRecoveryWindowMinutes) {
		this.coupleRepository = coupleRepository;
		this.deviceRepository = deviceRepository;
		this.inviteRepository = inviteRepository;
		this.keyDeliveryRepository = keyDeliveryRepository;
		this.challengeRepository = challengeRepository;
		this.pushService = pushService;
		this.eventPublisher = eventPublisher;
		this.clock = clock;
		this.coupleRecoveryLimiter = new SlidingWindowLimiter(
				clock,
				Duration.ofMinutes(Math.max(1, coupleRecoveryWindowMinutes)),
				coupleRecoveryMaxAttempts);
	}

	public record CreateInviteResult(UUID coupleId, UUID deviceId, String inviteToken, Instant expiresAt) {}

	public record AcceptInviteResult(
			UUID coupleId,
			UUID deviceId,
			UUID peerDeviceId,
			String peerLabel,
			String peerAuthPublicKeyB64,
			String peerKemPublicKeyB64) {}

	public record InviteStatusResult(
			boolean accepted,
			UUID acceptedDeviceId,
			String acceptedLabel,
			String acceptedAuthPublicKeyB64,
			String acceptedKemPublicKeyB64) {}

	public record KeyDeliveryView(
			UUID coupleId,
			UUID fromDeviceId,
			UUID toDeviceId,
			String nonceB64,
			String ciphertextB64,
			Instant createdAt,
			String deliveryKind,
			int keyEpoch) {
		public KeyDeliveryView(
				UUID coupleId,
				UUID fromDeviceId,
				UUID toDeviceId,
				String nonceB64,
				String ciphertextB64,
				Instant createdAt) {
			this(coupleId, fromDeviceId, toDeviceId, nonceB64, ciphertextB64, createdAt, "PAIRING_SEED", 1);
		}
	}

	public record DeviceView(
			UUID deviceId,
			String label,
			String enrolledVia,
			Instant createdAt,
			Instant revokedAt,
			String kemPublicKeyB64,
			boolean approved) {
		public DeviceView(
				UUID deviceId,
				String label,
				String enrolledVia,
				Instant createdAt,
				Instant revokedAt) {
			this(deviceId, label, enrolledVia, createdAt, revokedAt, null, false);
		}
	}

	public record RecoveryChallengeResult(UUID challengeId, UUID coupleId, String nonceB64, Instant expiresAt) {}

	public record RecoveryCompleteResult(
			UUID coupleId,
			UUID deviceId,
			int currentKeyEpoch,
			String recoveryKeyringNonceB64,
			String recoveryKeyringCiphertextB64) {
		public RecoveryCompleteResult(UUID coupleId, UUID deviceId) {
			this(coupleId, deviceId, 1, null, null);
		}
	}

	public record EpochKeyDeliveryInput(UUID toDeviceId, String nonceB64, String ciphertextB64) {}

	public record EpochRotationRequestData(
			int targetEpoch,
			String newRecoveryAuthPublicKeyB64,
			String recoveryKeyringNonceB64,
			String recoveryKeyringCiphertextB64,
			List<EpochKeyDeliveryInput> deliveries) {}

	public record EpochRotationStateView(int currentKeyEpoch, KeyDeliveryView pendingDelivery) {}

	public record PairingVisibilityAudit(
			UUID coupleId,
			Instant coupleCreatedAt,
			Instant coupleUnpairedAt,
			String recoveryAuthPublicKeyHex,
			List<DeviceVisibilityRow> devices,
			List<InviteVisibilityRow> invites,
			List<KeyDeliveryVisibilityRow> keyDeliveries) {}

	public record DeviceVisibilityRow(
			UUID id,
			String label,
			String authPublicKeyHex,
			String kemPublicKeyHex,
			String enrolledVia,
			Instant createdAt,
			Instant revokedAt) {}

	public record InviteVisibilityRow(
			UUID id,
			UUID creatorDeviceId,
			String tokenHashHex,
			String inviteKind,
			Instant expiresAt,
			Instant acceptedAt,
			UUID acceptedDeviceId) {}

	public record KeyDeliveryVisibilityRow(
			UUID id,
			UUID fromDeviceId,
			UUID toDeviceId,
			String nonceHex,
			int ciphertextBytes,
			String ciphertextHexPreview,
			Instant createdAt,
			Instant deliveredAt) {}

	@Transactional
	public CreateInviteResult createInitialInvite(
			String deviceLabel,
			String deviceAuthPublicKeyB64,
			String deviceKemPublicKeyB64,
			String recoveryAuthPublicKeyB64) {
		byte[] authPub = Ed25519SignatureVerifier.decodeBase64Url(deviceAuthPublicKeyB64, 32, "deviceAuthPublicKeyB64");
		byte[] kemPub = Ed25519SignatureVerifier.decodeBase64Url(deviceKemPublicKeyB64, 32, "deviceKemPublicKeyB64");
		byte[] recoveryAuthPub = Ed25519SignatureVerifier.decodeBase64Url(
				recoveryAuthPublicKeyB64, 32, "recoveryAuthPublicKeyB64");

		if (coupleRepository.findByRecoveryAuthPublicKey(recoveryAuthPub).isPresent()) {
			throw new IllegalStateException("A couple with this recoveryAuthPublicKey already exists");
		}

		Instant now = Instant.now();
		UUID coupleId = UUID.randomUUID();
		CoupleEntity couple = new CoupleEntity();
		couple.setId(coupleId);
		couple.setRecoveryAuthPublicKey(recoveryAuthPub);
		couple.setCreatedAt(now);
		coupleRepository.save(couple);

		UUID deviceId = UUID.randomUUID();
		DeviceEntity device = new DeviceEntity();
		device.setId(deviceId);
		device.setCoupleId(coupleId);
		device.setLabel(sanitizeLabel(deviceLabel));
		device.setAuthPublicKey(authPub);
		device.setKemPublicKey(kemPub);
		device.setEnrolledVia("INVITE_INIT");
		device.setCreatedAt(now);
		device.setApprovedAt(now);
		deviceRepository.save(device);

		String rawToken = generateToken();
		PairingInviteEntity invite = new PairingInviteEntity();
		invite.setId(UUID.randomUUID());
		invite.setCoupleId(coupleId);
		invite.setCreatorDeviceId(deviceId);
		invite.setTokenHash(hashToken(rawToken));
		invite.setInviteKind("INITIAL_PAIRING");
		invite.setExpiresAt(now.plus(INVITE_TTL));
		inviteRepository.save(invite);

		return new CreateInviteResult(coupleId, deviceId, rawToken, invite.getExpiresAt());
	}

	@Transactional
	public CreateInviteResult createEnrollmentInvite(DevicePrincipal principal) {
		Instant now = Instant.now();
		String rawToken = generateToken();
		PairingInviteEntity invite = new PairingInviteEntity();
		invite.setId(UUID.randomUUID());
		invite.setCoupleId(principal.coupleId());
		invite.setCreatorDeviceId(principal.deviceId());
		invite.setTokenHash(hashToken(rawToken));
		invite.setInviteKind("DEVICE_ENROLLMENT");
		invite.setExpiresAt(now.plus(INVITE_TTL));
		inviteRepository.save(invite);
		return new CreateInviteResult(principal.coupleId(), principal.deviceId(), rawToken, invite.getExpiresAt());
	}

	@Transactional
	public AcceptInviteResult acceptInvite(
			String rawToken,
			String deviceLabel,
			String deviceAuthPublicKeyB64,
			String deviceKemPublicKeyB64) {
		byte[] authPub = Ed25519SignatureVerifier.decodeBase64Url(deviceAuthPublicKeyB64, 32, "deviceAuthPublicKeyB64");
		byte[] kemPub = Ed25519SignatureVerifier.decodeBase64Url(deviceKemPublicKeyB64, 32, "deviceKemPublicKeyB64");

		PairingInviteEntity invite = inviteRepository.findByTokenHashForUpdate(hashToken(rawToken))
				.orElseThrow(() -> new IllegalStateException("Invite is invalid, expired, or already used"));

		Instant now = Instant.now();
		if (!invite.getExpiresAt().isAfter(now) || invite.getAcceptedAt() != null) {
			throw new IllegalStateException("Invite is invalid, expired, or already used");
		}
		CoupleEntity couple = coupleRepository.findById(invite.getCoupleId())
				.orElseThrow(() -> new IllegalStateException("Invite is invalid, expired, or already used"));
		if (couple.getUnpairedAt() != null) {
			throw new IllegalStateException("Invite is invalid, expired, or already used");
		}

		DeviceEntity creatorDevice = deviceRepository.findById(invite.getCreatorDeviceId())
				.orElseThrow(() -> new IllegalStateException("Invite is invalid, expired, or already used"));
		if (creatorDevice.getRevokedAt() != null) {
			throw new IllegalStateException("Invite is invalid, expired, or already used");
		}

		UUID newDeviceId = UUID.randomUUID();
		DeviceEntity newDevice = new DeviceEntity();
		newDevice.setId(newDeviceId);
		newDevice.setCoupleId(invite.getCoupleId());
		newDevice.setLabel(sanitizeLabel(deviceLabel));
		newDevice.setAuthPublicKey(authPub);
		newDevice.setKemPublicKey(kemPub);
		newDevice.setEnrolledVia("INITIAL_PAIRING".equals(invite.getInviteKind()) ? "INVITE_JOIN" : "ENROLLMENT");
		newDevice.setCreatedAt(now);
		newDevice.setApprovedAt(null);
		deviceRepository.save(newDevice);

		invite.setAcceptedAt(now);
		invite.setAcceptedDeviceId(newDeviceId);
		inviteRepository.save(invite);

		// Notify the approving/inviting device after commit with a generic data-only wakeup (`S-02`, `S1-SRV-02`, `CA-07`).
		eventPublisher.publishEvent(new PartnerWakeupRequestedEvent(
				invite.getCoupleId(), newDeviceId, "wakeup.pairing_request"));

		return new AcceptInviteResult(
				invite.getCoupleId(),
				newDeviceId,
				creatorDevice.getId(),
				creatorDevice.getLabel(),
				Ed25519SignatureVerifier.encodeBase64Url(creatorDevice.getAuthPublicKey()),
				Ed25519SignatureVerifier.encodeBase64Url(creatorDevice.getKemPublicKey()));
	}

	@Transactional(readOnly = true)
	public InviteStatusResult getInviteStatus(DevicePrincipal principal, String rawToken) {
		PairingInviteEntity invite = inviteRepository.findByTokenHash(hashToken(rawToken))
				.orElseThrow(() -> new NoSuchElementException("Invite not found"));
		if (!invite.getCoupleId().equals(principal.coupleId())) {
			throw new NoSuchElementException("Invite not found");
		}
		if (invite.getAcceptedDeviceId() == null) {
			return new InviteStatusResult(false, null, null, null, null);
		}
		DeviceEntity acceptedDevice = deviceRepository.findById(invite.getAcceptedDeviceId())
				.orElseThrow(() -> new NoSuchElementException("Accepted device not found"));
		return new InviteStatusResult(
				true,
				acceptedDevice.getId(),
				acceptedDevice.getLabel(),
				Ed25519SignatureVerifier.encodeBase64Url(acceptedDevice.getAuthPublicKey()),
				Ed25519SignatureVerifier.encodeBase64Url(acceptedDevice.getKemPublicKey()));
	}

	@Transactional
	public void storeKeyDelivery(
			DevicePrincipal principal,
			UUID toDeviceId,
			String nonceB64,
			String ciphertextB64) {
		storeKeyDelivery(principal, toDeviceId, nonceB64, ciphertextB64, null);
	}

	@Transactional
	public void storeKeyDelivery(
			DevicePrincipal principal,
			UUID toDeviceId,
			String nonceB64,
			String ciphertextB64,
			Integer requestedKeyEpoch) {
		DeviceEntity target = deviceRepository.findById(toDeviceId)
				.orElseThrow(() -> new NoSuchElementException("Target device not found"));
		if (!target.getCoupleId().equals(principal.coupleId()) || target.getRevokedAt() != null) {
			throw new IllegalArgumentException("Target device is not active in this couple");
		}
		byte[] nonce = Ed25519SignatureVerifier.decodeBase64Url(nonceB64, 24, "nonceB64");
		byte[] ciphertext = Ed25519SignatureVerifier.decodeBase64UrlVariable(ciphertextB64, "ciphertextB64");
		if (ciphertext.length <= 16) {
			throw new IllegalArgumentException("Wrapped key ciphertext too short");
		}
		int keyEpoch = requestedKeyEpoch != null
				? requestedKeyEpoch
				: coupleRepository.findById(principal.coupleId())
						.map(CoupleEntity::getCurrentKeyEpoch)
						.orElse(1);
		if (keyEpoch < 1) {
			throw new IllegalArgumentException("keyEpoch must be >= 1");
		}

		Instant now = Instant.now();
		if (target.getApprovedAt() == null) {
			target.setApprovedAt(now);
			deviceRepository.save(target);
		}

		KeyDeliveryEntity entity = new KeyDeliveryEntity();
		entity.setId(UUID.randomUUID());
		entity.setCoupleId(principal.coupleId());
		entity.setFromDeviceId(principal.deviceId());
		entity.setToDeviceId(toDeviceId);
		entity.setNonce(nonce);
		entity.setCiphertext(ciphertext);
		entity.setCreatedAt(now);
		entity.setDeliveryKind("PAIRING_SEED");
		entity.setKeyEpoch(keyEpoch);
		keyDeliveryRepository.save(entity);
	}

	@Transactional
	public KeyDeliveryView fetchPendingKeyDelivery(DevicePrincipal principal) {
		KeyDeliveryEntity entity = keyDeliveryRepository
				.findFirstByToDeviceIdAndDeliveryKindOrderByKeyEpochDescCreatedAtDesc(
						principal.deviceId(), "PAIRING_SEED")
				.or(() -> keyDeliveryRepository.findFirstByToDeviceIdOrderByCreatedAtDesc(principal.deviceId()))
				.orElseThrow(() -> new NoSuchElementException("No key delivery ready for this device"));
		if (entity.getDeliveredAt() == null) {
			entity.setDeliveredAt(Instant.now());
			keyDeliveryRepository.save(entity);
		}
		return toKeyDeliveryView(entity);
	}

	@Transactional
	public EpochRotationStateView fetchPendingEpochRotation(DevicePrincipal principal) {
		CoupleEntity couple = coupleRepository.findById(principal.coupleId())
				.orElseThrow(() -> new NoSuchElementException("Couple not found"));
		KeyDeliveryView pending = keyDeliveryRepository
				.findFirstByToDeviceIdAndDeliveryKindOrderByKeyEpochDescCreatedAtDesc(
						principal.deviceId(), "EPOCH_ROTATION")
				.map(entity -> {
					if (entity.getDeliveredAt() == null) {
						entity.setDeliveredAt(Instant.now());
						keyDeliveryRepository.save(entity);
					}
					return toKeyDeliveryView(entity);
				})
				.orElse(null);
		return new EpochRotationStateView(couple.getCurrentKeyEpoch(), pending);
	}

	private static KeyDeliveryView toKeyDeliveryView(KeyDeliveryEntity entity) {
		return new KeyDeliveryView(
				entity.getCoupleId(),
				entity.getFromDeviceId(),
				entity.getToDeviceId(),
				Ed25519SignatureVerifier.encodeBase64Url(entity.getNonce()),
				Ed25519SignatureVerifier.encodeBase64Url(entity.getCiphertext()),
				entity.getCreatedAt(),
				entity.getDeliveryKind(),
				entity.getKeyEpoch());
	}

	@Transactional(readOnly = true)
	public List<DeviceView> listDevices(DevicePrincipal principal) {
		return deviceRepository.findAllByCoupleIdOrderByCreatedAtAsc(principal.coupleId()).stream()
				.map(PairingService::toDeviceView)
				.toList();
	}

	@Transactional
	public DeviceView updateOwnDeviceLabel(DevicePrincipal principal, String deviceLabel) {
		DeviceEntity device = deviceRepository.findById(principal.deviceId())
				.orElseThrow(() -> new NoSuchElementException("Device not found"));
		if (!device.getCoupleId().equals(principal.coupleId()) || device.getRevokedAt() != null) {
			throw new NoSuchElementException("Device not found");
		}
		device.setLabel(sanitizeLabel(deviceLabel));
		deviceRepository.save(device);
		return toDeviceView(device);
	}

	private static DeviceView toDeviceView(DeviceEntity device) {
		return new DeviceView(
				device.getId(),
				device.getLabel(),
				device.getEnrolledVia(),
				device.getCreatedAt(),
				device.getRevokedAt(),
				device.getKemPublicKey() == null
						? null
						: Ed25519SignatureVerifier.encodeBase64Url(device.getKemPublicKey()),
				device.getApprovedAt() != null);
	}

	@Transactional
	public void revokeDevice(DevicePrincipal principal, UUID targetDeviceId) {
		revokeDevice(principal, targetDeviceId, null);
	}

	@Transactional
	public void revokeDevice(DevicePrincipal principal, UUID targetDeviceId, EpochRotationRequestData rotation) {
		DeviceEntity target = deviceRepository.findById(targetDeviceId)
				.orElseThrow(() -> new NoSuchElementException("Device not found"));
		if (!target.getCoupleId().equals(principal.coupleId())) {
			throw new NoSuchElementException("Device not found");
		}
		Instant now = Instant.now();
		if (target.getRevokedAt() == null) {
			target.setRevokedAt(now);
			deviceRepository.save(target);
		}
		pushService.unregisterDevice(target.getId());
		if (rotation != null) {
			applyEpochRotation(principal, rotation, now);
		}
	}

	@Transactional
	public int rotateEpoch(DevicePrincipal principal, EpochRotationRequestData rotation) {
		return applyEpochRotation(principal, rotation, Instant.now());
	}

	private int applyEpochRotation(DevicePrincipal principal, EpochRotationRequestData rotation, Instant now) {
		CoupleEntity couple = coupleRepository.findByIdForUpdate(principal.coupleId())
				.orElseThrow(() -> new NoSuchElementException("Couple not found"));
		if (couple.getUnpairedAt() != null) {
			throw new IllegalStateException("Couple has been unpaired");
		}
		int expectedEpoch = couple.getCurrentKeyEpoch() + 1;
		if (rotation.targetEpoch() != expectedEpoch) {
			throw new IllegalStateException("Expected targetEpoch " + expectedEpoch);
		}
		byte[] newRecoveryAuthPub = Ed25519SignatureVerifier.decodeBase64Url(
				rotation.newRecoveryAuthPublicKeyB64(), 32, "newRecoveryAuthPublicKeyB64");
		byte[] keyringNonce = Ed25519SignatureVerifier.decodeBase64Url(
				rotation.recoveryKeyringNonceB64(), 24, "recoveryKeyringNonceB64");
		byte[] keyringCiphertext = Ed25519SignatureVerifier.decodeBase64UrlVariable(
				rotation.recoveryKeyringCiphertextB64(), "recoveryKeyringCiphertextB64");
		if (keyringCiphertext.length <= 16) {
			throw new IllegalArgumentException("Recovery keyring ciphertext too short");
		}
		coupleRepository.findByRecoveryAuthPublicKey(newRecoveryAuthPub)
				.filter(other -> !other.getId().equals(couple.getId()))
				.ifPresent(other -> {
					throw new IllegalStateException("Recovery key already registered to another couple");
				});

		List<EpochKeyDeliveryInput> deliveries =
				rotation.deliveries() == null ? List.of() : rotation.deliveries();
		Set<UUID> deliveredTargets = new HashSet<>();
		for (EpochKeyDeliveryInput item : deliveries) {
			if (item.toDeviceId() == null) {
				throw new IllegalArgumentException("Delivery target deviceId required");
			}
			if (item.toDeviceId().equals(principal.deviceId())) {
				throw new IllegalArgumentException("Cannot target initiating device for epoch rotation delivery");
			}
			if (!deliveredTargets.add(item.toDeviceId())) {
				throw new IllegalArgumentException("Duplicate epoch rotation delivery target");
			}
			DeviceEntity recipient = deviceRepository.findById(item.toDeviceId())
					.orElseThrow(() -> new NoSuchElementException("Delivery recipient device not found"));
			if (!recipient.getCoupleId().equals(principal.coupleId())
					|| recipient.getRevokedAt() != null
					|| recipient.getApprovedAt() == null) {
				throw new IllegalArgumentException("Epoch rotation recipient must be active and approved in couple");
			}
			byte[] nonce = Ed25519SignatureVerifier.decodeBase64Url(item.nonceB64(), 24, "nonceB64");
			byte[] ciphertext = Ed25519SignatureVerifier.decodeBase64UrlVariable(
					item.ciphertextB64(), "ciphertextB64");
			if (ciphertext.length <= 16) {
				throw new IllegalArgumentException("Wrapped epoch key ciphertext too short");
			}
			KeyDeliveryEntity entity = new KeyDeliveryEntity();
			entity.setId(UUID.randomUUID());
			entity.setCoupleId(principal.coupleId());
			entity.setFromDeviceId(principal.deviceId());
			entity.setToDeviceId(recipient.getId());
			entity.setNonce(nonce);
			entity.setCiphertext(ciphertext);
			entity.setCreatedAt(now);
			entity.setDeliveryKind("EPOCH_ROTATION");
			entity.setKeyEpoch(rotation.targetEpoch());
			keyDeliveryRepository.save(entity);
		}

		List<DeviceEntity> coupleDevices = deviceRepository.findAllByCoupleIdOrderByCreatedAtAsc(principal.coupleId());
		for (DeviceEntity d : coupleDevices) {
			if (!d.getId().equals(principal.deviceId())
					&& d.getRevokedAt() == null
					&& d.getApprovedAt() != null
					&& !deliveredTargets.contains(d.getId())) {
				throw new IllegalArgumentException("Missing epoch rotation delivery for active device " + d.getId());
			}
		}

		couple.setCurrentKeyEpoch(rotation.targetEpoch());
		couple.setRecoveryAuthPublicKey(newRecoveryAuthPub);
		couple.setRecoveryKeyringNonce(keyringNonce);
		couple.setRecoveryKeyringCiphertext(keyringCiphertext);
		coupleRepository.save(couple);
		return couple.getCurrentKeyEpoch();
	}

	@Transactional
	public void unpairCouple(DevicePrincipal principal) {
		CoupleEntity couple = coupleRepository.findById(principal.coupleId())
				.orElseThrow(() -> new NoSuchElementException("Couple not found"));
		Instant now = Instant.now();
		couple.setUnpairedAt(now);
		coupleRepository.save(couple);
		List<DeviceEntity> devices = deviceRepository.findAllByCoupleIdOrderByCreatedAtAsc(principal.coupleId());
		for (DeviceEntity device : devices) {
			if (device.getRevokedAt() == null) {
				device.setRevokedAt(now);
			}
		}
		deviceRepository.saveAll(devices);
		pushService.unregisterCouple(couple.getId());
	}

	@Transactional
	public RecoveryChallengeResult createRecoveryChallenge(String recoveryAuthPublicKeyB64) {
		byte[] recoveryAuthPub = Ed25519SignatureVerifier.decodeBase64Url(
				recoveryAuthPublicKeyB64, 32, "recoveryAuthPublicKeyB64");
		enforceCoupleRecoveryLimit("challenge:" + Ed25519SignatureVerifier.encodeBase64Url(recoveryAuthPub));
		CoupleEntity couple = coupleRepository.findByRecoveryAuthPublicKey(recoveryAuthPub)
				.orElseThrow(() -> new NoSuchElementException("Couple not found for recovery key"));
		if (couple.getUnpairedAt() != null) {
			throw new IllegalStateException("Couple has been unpaired");
		}

		byte[] nonce = new byte[32];
		secureRandom.nextBytes(nonce);
		Instant expiresAt = clock.instant().plus(CHALLENGE_TTL);
		RecoveryChallengeEntity challenge = new RecoveryChallengeEntity();
		challenge.setId(UUID.randomUUID());
		challenge.setCoupleId(couple.getId());
		challenge.setNonce(nonce);
		challenge.setExpiresAt(expiresAt);
		challengeRepository.save(challenge);

		return new RecoveryChallengeResult(
				challenge.getId(),
				couple.getId(),
				Ed25519SignatureVerifier.encodeBase64Url(nonce),
				expiresAt);
	}

	@Transactional
	public RecoveryCompleteResult completeRecovery(
			UUID challengeId,
			String deviceLabel,
			String newDeviceAuthPublicKeyB64,
			String newDeviceKemPublicKeyB64,
			String recoverySignatureB64) {
		RecoveryChallengeEntity challenge = challengeRepository.findByIdForUpdate(challengeId)
				.orElseThrow(() -> new NoSuchElementException("Recovery challenge not found"));
		Instant now = clock.instant();
		if (challenge.getUsedAt() != null) {
			throw new IllegalStateException("Recovery challenge already used");
		}
		if (!challenge.getExpiresAt().isAfter(now)) {
			throw new IllegalStateException("Recovery challenge expired");
		}

		CoupleEntity couple = coupleRepository.findById(challenge.getCoupleId())
				.orElseThrow(() -> new NoSuchElementException("Couple not found"));
		if (couple.getUnpairedAt() != null) {
			throw new IllegalStateException("Couple has been unpaired");
		}
		enforceCoupleRecoveryLimit("complete:" + couple.getId());

		byte[] authPub = Ed25519SignatureVerifier.decodeBase64Url(
				newDeviceAuthPublicKeyB64, 32, "newDeviceAuthPublicKeyB64");
		byte[] kemPub = Ed25519SignatureVerifier.decodeBase64Url(
				newDeviceKemPublicKeyB64, 32, "newDeviceKemPublicKeyB64");
		byte[] signature = Ed25519SignatureVerifier.decodeBase64Url(
				recoverySignatureB64, 64, "recoverySignatureB64");

		String canonicalClaim = String.join(
				"|",
				"deep-sky:recovery:v1",
				couple.getId().toString(),
				challenge.getId().toString(),
				Ed25519SignatureVerifier.encodeBase64Url(challenge.getNonce()),
				Ed25519SignatureVerifier.encodeBase64Url(authPub),
				Ed25519SignatureVerifier.encodeBase64Url(kemPub));

		if (!Ed25519SignatureVerifier.verify(couple.getRecoveryAuthPublicKey(), canonicalClaim, signature)) {
			throw new SecurityException("Invalid recovery signature");
		}

		challenge.setUsedAt(now);
		challengeRepository.save(challenge);

		UUID newDeviceId = UUID.randomUUID();
		DeviceEntity newDevice = new DeviceEntity();
		newDevice.setId(newDeviceId);
		newDevice.setCoupleId(couple.getId());
		newDevice.setLabel(sanitizeLabel(deviceLabel));
		newDevice.setAuthPublicKey(authPub);
		newDevice.setKemPublicKey(kemPub);
		newDevice.setEnrolledVia("RECOVERY_KEY");
		newDevice.setCreatedAt(now);
		newDevice.setApprovedAt(now);
		deviceRepository.save(newDevice);

		return new RecoveryCompleteResult(
				couple.getId(),
				newDeviceId,
				couple.getCurrentKeyEpoch(),
				couple.getRecoveryKeyringNonce() == null
						? null
						: Ed25519SignatureVerifier.encodeBase64Url(couple.getRecoveryKeyringNonce()),
				couple.getRecoveryKeyringCiphertext() == null
						? null
						: Ed25519SignatureVerifier.encodeBase64Url(couple.getRecoveryKeyringCiphertext()));
	}

	private void enforceCoupleRecoveryLimit(String bucketKey) {
		SlidingWindowLimiter.Decision decision = coupleRecoveryLimiter.tryConsume(bucketKey);
		if (!decision.allowed()) {
			throw new RateLimitExceededException(
					"Too many recovery attempts for this couple; please wait before retrying.",
					decision.retryAfterSeconds());
		}
	}

	@Transactional(readOnly = true)
	public PairingVisibilityAudit getVisibilityAudit(DevicePrincipal principal) {
		CoupleEntity couple = coupleRepository.findById(principal.coupleId())
				.orElseThrow(() -> new NoSuchElementException("Couple not found"));
		HexFormat hex = HexFormat.of();
		List<DeviceVisibilityRow> devices = deviceRepository
				.findAllByCoupleIdOrderByCreatedAtAsc(principal.coupleId())
				.stream()
				.map(d -> new DeviceVisibilityRow(
						d.getId(),
						d.getLabel(),
						hex.formatHex(d.getAuthPublicKey()),
						hex.formatHex(d.getKemPublicKey()),
						d.getEnrolledVia(),
						d.getCreatedAt(),
						d.getRevokedAt()))
				.toList();
		List<InviteVisibilityRow> invites = inviteRepository
				.findAllByCoupleIdOrderByExpiresAtAsc(principal.coupleId())
				.stream()
				.map(i -> new InviteVisibilityRow(
						i.getId(),
						i.getCreatorDeviceId(),
						hex.formatHex(i.getTokenHash()),
						i.getInviteKind(),
						i.getExpiresAt(),
						i.getAcceptedAt(),
						i.getAcceptedDeviceId()))
				.toList();
		List<KeyDeliveryVisibilityRow> deliveries = keyDeliveryRepository
				.findAllByCoupleIdOrderByCreatedAtAsc(principal.coupleId())
				.stream()
				.map(k -> new KeyDeliveryVisibilityRow(
						k.getId(),
						k.getFromDeviceId(),
						k.getToDeviceId(),
						hex.formatHex(k.getNonce()),
						k.getCiphertext().length,
						hex.formatHex(k.getCiphertext(), 0, Math.min(24, k.getCiphertext().length)),
						k.getCreatedAt(),
						k.getDeliveredAt()))
				.toList();

		return new PairingVisibilityAudit(
				couple.getId(),
				couple.getCreatedAt(),
				couple.getUnpairedAt(),
				hex.formatHex(couple.getRecoveryAuthPublicKey()),
				devices,
				invites,
				deliveries);
	}

	private String generateToken() {
		byte[] bytes = new byte[24];
		secureRandom.nextBytes(bytes);
		return Ed25519SignatureVerifier.encodeBase64Url(bytes).replace("=", "");
	}

	private static byte[] hashToken(String rawToken) {
		if (rawToken == null || rawToken.isBlank()) {
			throw new IllegalArgumentException("Invite token must not be blank");
		}
		return Ed25519SignatureVerifier.sha256(rawToken.trim().getBytes(StandardCharsets.UTF_8));
	}

	private static String sanitizeLabel(String label) {
		if (label == null || label.isBlank()) {
			return "Android Device";
		}
		String trimmed = label.trim();
		return trimmed.length() > 64 ? trimmed.substring(0, 64) : trimmed;
	}
}
