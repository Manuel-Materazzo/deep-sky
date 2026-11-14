package com.vectevo.deep_sky_server.pairing;

import com.vectevo.deep_sky_server.shared.DevicePrincipal;
import com.vectevo.deep_sky_server.shared.Ed25519SignatureVerifier;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import java.util.List;
import java.util.NoSuchElementException;
import java.util.UUID;
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
	private final SecureRandom secureRandom = new SecureRandom();

	public PairingService(
			CoupleRepository coupleRepository,
			DeviceRepository deviceRepository,
			PairingInviteRepository inviteRepository,
			KeyDeliveryRepository keyDeliveryRepository,
			RecoveryChallengeRepository challengeRepository) {
		this.coupleRepository = coupleRepository;
		this.deviceRepository = deviceRepository;
		this.inviteRepository = inviteRepository;
		this.keyDeliveryRepository = keyDeliveryRepository;
		this.challengeRepository = challengeRepository;
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
			Instant createdAt) {}

	public record DeviceView(
			UUID deviceId,
			String label,
			String enrolledVia,
			Instant createdAt,
			Instant revokedAt) {}

	public record RecoveryChallengeResult(UUID challengeId, UUID coupleId, String nonceB64, Instant expiresAt) {}

	public record RecoveryCompleteResult(UUID coupleId, UUID deviceId) {}

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

		PairingInviteEntity invite = inviteRepository.findByTokenHash(hashToken(rawToken))
				.orElseThrow(() -> new NoSuchElementException("Invite not found"));

		Instant now = Instant.now();
		if (invite.getExpiresAt().isBefore(now)) {
			throw new IllegalStateException("Invite has expired");
		}
		if (invite.getAcceptedAt() != null) {
			throw new IllegalStateException("Invite has already been accepted");
		}
		CoupleEntity couple = coupleRepository.findById(invite.getCoupleId())
				.orElseThrow(() -> new NoSuchElementException("Couple not found"));
		if (couple.getUnpairedAt() != null) {
			throw new IllegalStateException("Couple is unpaired");
		}

		DeviceEntity creatorDevice = deviceRepository.findById(invite.getCreatorDeviceId())
				.orElseThrow(() -> new NoSuchElementException("Creator device not found"));
		if (creatorDevice.getRevokedAt() != null) {
			throw new IllegalStateException("Creator device has been revoked");
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
		deviceRepository.save(newDevice);

		invite.setAcceptedAt(now);
		invite.setAcceptedDeviceId(newDeviceId);
		inviteRepository.save(invite);

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

		KeyDeliveryEntity entity = new KeyDeliveryEntity();
		entity.setId(UUID.randomUUID());
		entity.setCoupleId(principal.coupleId());
		entity.setFromDeviceId(principal.deviceId());
		entity.setToDeviceId(toDeviceId);
		entity.setNonce(nonce);
		entity.setCiphertext(ciphertext);
		entity.setCreatedAt(Instant.now());
		keyDeliveryRepository.save(entity);
	}

	@Transactional
	public KeyDeliveryView fetchPendingKeyDelivery(DevicePrincipal principal) {
		KeyDeliveryEntity entity = keyDeliveryRepository
				.findFirstByToDeviceIdOrderByCreatedAtDesc(principal.deviceId())
				.orElseThrow(() -> new NoSuchElementException("No key delivery ready for this device"));
		if (entity.getDeliveredAt() == null) {
			entity.setDeliveredAt(Instant.now());
			keyDeliveryRepository.save(entity);
		}
		return new KeyDeliveryView(
				entity.getCoupleId(),
				entity.getFromDeviceId(),
				entity.getToDeviceId(),
				Ed25519SignatureVerifier.encodeBase64Url(entity.getNonce()),
				Ed25519SignatureVerifier.encodeBase64Url(entity.getCiphertext()),
				entity.getCreatedAt());
	}

	@Transactional(readOnly = true)
	public List<DeviceView> listDevices(DevicePrincipal principal) {
		return deviceRepository.findAllByCoupleIdOrderByCreatedAtAsc(principal.coupleId()).stream()
				.map(d -> new DeviceView(d.getId(), d.getLabel(), d.getEnrolledVia(), d.getCreatedAt(), d.getRevokedAt()))
				.toList();
	}

	@Transactional
	public void revokeDevice(DevicePrincipal principal, UUID targetDeviceId) {
		DeviceEntity target = deviceRepository.findById(targetDeviceId)
				.orElseThrow(() -> new NoSuchElementException("Device not found"));
		if (!target.getCoupleId().equals(principal.coupleId())) {
			throw new NoSuchElementException("Device not found");
		}
		if (target.getRevokedAt() == null) {
			target.setRevokedAt(Instant.now());
			deviceRepository.save(target);
		}
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
	}

	@Transactional
	public RecoveryChallengeResult createRecoveryChallenge(String recoveryAuthPublicKeyB64) {
		byte[] recoveryAuthPub = Ed25519SignatureVerifier.decodeBase64Url(
				recoveryAuthPublicKeyB64, 32, "recoveryAuthPublicKeyB64");
		CoupleEntity couple = coupleRepository.findByRecoveryAuthPublicKey(recoveryAuthPub)
				.orElseThrow(() -> new NoSuchElementException("Couple not found for recovery key"));
		if (couple.getUnpairedAt() != null) {
			throw new IllegalStateException("Couple has been unpaired");
		}

		byte[] nonce = new byte[32];
		secureRandom.nextBytes(nonce);
		Instant expiresAt = Instant.now().plus(CHALLENGE_TTL);
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
		RecoveryChallengeEntity challenge = challengeRepository.findById(challengeId)
				.orElseThrow(() -> new NoSuchElementException("Recovery challenge not found"));
		Instant now = Instant.now();
		if (challenge.getUsedAt() != null) {
			throw new IllegalStateException("Recovery challenge already used");
		}
		if (challenge.getExpiresAt().isBefore(now)) {
			throw new IllegalStateException("Recovery challenge expired");
		}

		CoupleEntity couple = coupleRepository.findById(challenge.getCoupleId())
				.orElseThrow(() -> new NoSuchElementException("Couple not found"));
		if (couple.getUnpairedAt() != null) {
			throw new IllegalStateException("Couple has been unpaired");
		}

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
		deviceRepository.save(newDevice);

		return new RecoveryCompleteResult(couple.getId(), newDeviceId);
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
