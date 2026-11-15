package com.vectevo.deep_sky_server.pairing;

import com.vectevo.deep_sky_server.push.PushService;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Periodic cleanup for expired anti-replay nonces, recovery challenges, pairing invites,
 * and stale unapproved enrollment/join devices (`PR-M2-02`, `S1-SRV-01`, `S1-SRV-02`, `G5-03`, `G5-04`).
 */
@Service
public class PairingCleanupService {

	private static final Logger log = LoggerFactory.getLogger(PairingCleanupService.class);
	private static final Duration CHALLENGE_RETENTION_GRACE = Duration.ofHours(1);
	private static final Duration INVITE_RETENTION_GRACE = Duration.ofMinutes(15);
	private static final Duration UNAPPROVED_DEVICE_TTL = Duration.ofMinutes(30);

	private final RequestNonceRepository requestNonceRepository;
	private final RecoveryChallengeRepository recoveryChallengeRepository;
	private final PairingInviteRepository pairingInviteRepository;
	private final DeviceRepository deviceRepository;
	private final PushService pushService;

	public PairingCleanupService(
			RequestNonceRepository requestNonceRepository,
			RecoveryChallengeRepository recoveryChallengeRepository,
			PairingInviteRepository pairingInviteRepository,
			DeviceRepository deviceRepository,
			PushService pushService) {
		this.requestNonceRepository = requestNonceRepository;
		this.recoveryChallengeRepository = recoveryChallengeRepository;
		this.pairingInviteRepository = pairingInviteRepository;
		this.deviceRepository = deviceRepository;
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
		if (deletedNonces > 0 || deletedChallenges > 0 || deletedInvites > 0 || revokedUnapproved > 0) {
			log.debug(
					"Cleanup purged {} nonces, {} recovery challenges, {} expired invites, and revoked {} unapproved devices",
					deletedNonces,
					deletedChallenges,
					deletedInvites,
					revokedUnapproved);
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
}
