package com.vectevo.deep_sky_server.pairing;

import com.vectevo.deep_sky_server.push.PushService;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Periodic cleanup for expired anti-replay nonces, recovery challenges, pairing invites,
 * stale unapproved enrollment/join devices, and abandoned never-paired couples
 * (`PR-M2-02`, `S1-SRV-01`, `S1-SRV-02`, `G5-03`, `G5-04`, `CA-17`).
 */
@Service
public class PairingCleanupService {

	private static final Logger log = LoggerFactory.getLogger(PairingCleanupService.class);
	private static final Duration CHALLENGE_RETENTION_GRACE = Duration.ofHours(1);
	private static final Duration INVITE_RETENTION_GRACE = Duration.ofMinutes(15);
	private static final Duration UNAPPROVED_DEVICE_TTL = Duration.ofMinutes(30);
	private static final Duration ORPHAN_COUPLE_TTL = Duration.ofHours(24);
	private static final Duration UNPAIRED_COUPLE_RETENTION = Duration.ofDays(30);

	private final RequestNonceRepository requestNonceRepository;
	private final RecoveryChallengeRepository recoveryChallengeRepository;
	private final PairingInviteRepository pairingInviteRepository;
	private final DeviceRepository deviceRepository;
	private final CoupleRepository coupleRepository;
	private final PushService pushService;

	public PairingCleanupService(
			RequestNonceRepository requestNonceRepository,
			RecoveryChallengeRepository recoveryChallengeRepository,
			PairingInviteRepository pairingInviteRepository,
			DeviceRepository deviceRepository,
			CoupleRepository coupleRepository,
			PushService pushService) {
		this.requestNonceRepository = requestNonceRepository;
		this.recoveryChallengeRepository = recoveryChallengeRepository;
		this.pairingInviteRepository = pairingInviteRepository;
		this.deviceRepository = deviceRepository;
		this.coupleRepository = coupleRepository;
		this.pushService = pushService;
	}

	@Scheduled(fixedDelayString = "${deepsky.cleanup.interval:PT5M}")
	@Transactional
	public void purgeExpiredPeriodically() {
		Instant now = Instant.now();
		int deletedNonces = purgeExpiredNonces(now);
		int deletedChallenges = purgeExpiredChallenges(now.minus(CHALLENGE_RETENTION_GRACE));
		int deletedInvites = purgeExpiredInvites(now.minus(INVITE_RETENTION_GRACE));
		int revokedUnapproved = purgeStaleUnapprovedDevices(now.minus(UNAPPROVED_DEVICE_TTL));
		int deletedOrphanCouples = purgeOrphanNeverPairedCouples(now.minus(ORPHAN_COUPLE_TTL));
		int deletedUnpairedCouples = purgeUnpairedCouples(now.minus(UNPAIRED_COUPLE_RETENTION));
		if (deletedNonces > 0
				|| deletedChallenges > 0
				|| deletedInvites > 0
				|| revokedUnapproved > 0
				|| deletedOrphanCouples > 0
				|| deletedUnpairedCouples > 0) {
			log.debug(
					"Cleanup purged {} nonces, {} recovery challenges, {} expired invites, "
							+ "revoked {} unapproved devices, removed {} never-paired orphan couples, "
							+ "and purged {} expired unpaired couples",
					deletedNonces,
					deletedChallenges,
					deletedInvites,
					revokedUnapproved,
					deletedOrphanCouples,
					deletedUnpairedCouples);
		}
	}

	@Transactional
	public int purgeExpiredNonces(Instant cutoff) {
		return requestNonceRepository.deleteExpired(cutoff);
	}

	@Transactional
	public int purgeExpiredChallenges(Instant cutoff) {
		return recoveryChallengeRepository.deleteExpiredBefore(cutoff);
	}

	@Transactional
	public int purgeExpiredInvites(Instant cutoff) {
		return pairingInviteRepository.deleteExpiredBefore(cutoff);
	}

	@Transactional
	public int purgeStaleUnapprovedDevices(Instant cutoff) {
		List<DeviceEntity> stale = deviceRepository.findStaleUnapprovedDevices(cutoff);
		if (stale.isEmpty()) {
			return 0;
		}
		Instant now = Instant.now();
		for (DeviceEntity device : stale) {
			device.setRevokedAt(now);
			pushService.unregisterDevice(device.getId());
		}
		deviceRepository.saveAll(stale);
		return stale.size();
	}

	@Transactional
	public int purgeOrphanNeverPairedCouples(Instant cutoff) {
		List<UUID> orphanIds = coupleRepository.findOrphanNeverPairedCoupleIds(cutoff);
		if (orphanIds.isEmpty()) {
			return 0;
		}
		for (UUID coupleId : orphanIds) {
			pushService.unregisterCouple(coupleId);
			deviceRepository.deleteByCoupleId(coupleId);
		}
		coupleRepository.deleteAllByIdInBatch(orphanIds);
		return orphanIds.size();
	}

	/**
	 * Permanently purges unpaired couples and all associated ciphertext, devices,
	 * invites, key deliveries, challenges, and push registrations past retention ({@code AU-20}).
	 */
	@Transactional
	public int purgeUnpairedCouples(Instant cutoff) {
		List<UUID> expiredIds = coupleRepository.findUnpairedCoupleIdsBefore(cutoff);
		if (expiredIds.isEmpty()) {
			return 0;
		}
		for (UUID coupleId : expiredIds) {
			pushService.unregisterCouple(coupleId);
			coupleRepository.deleteEnvelopesByCoupleId(coupleId);
			coupleRepository.deleteKeyDeliveriesByCoupleId(coupleId);
			coupleRepository.deleteRecoveryChallengesByCoupleId(coupleId);
			coupleRepository.deleteInvitesByCoupleId(coupleId);
			deviceRepository.deleteByCoupleId(coupleId);
		}
		coupleRepository.deleteAllByIdInBatch(expiredIds);
		return expiredIds.size();
	}
}
