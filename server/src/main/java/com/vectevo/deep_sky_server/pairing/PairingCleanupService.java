package com.vectevo.deep_sky_server.pairing;

import java.time.Duration;
import java.time.Instant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Periodic cleanup for expired request anti-replay nonces and recovery challenges (`PR-M2-02`, `G5-03`, `G5-04`).
 */
@Service
public class PairingCleanupService {

	private static final Logger log = LoggerFactory.getLogger(PairingCleanupService.class);
	private static final Duration CHALLENGE_RETENTION_GRACE = Duration.ofHours(1);

	private final RequestNonceRepository requestNonceRepository;
	private final RecoveryChallengeRepository recoveryChallengeRepository;

	public PairingCleanupService(
			RequestNonceRepository requestNonceRepository,
			RecoveryChallengeRepository recoveryChallengeRepository) {
		this.requestNonceRepository = requestNonceRepository;
		this.recoveryChallengeRepository = recoveryChallengeRepository;
	}

	@Scheduled(fixedDelayString = "${deepsky.cleanup.interval:PT5M}")
	@Transactional
	public void purgeExpiredPeriodically() {
		Instant now = Instant.now();
		int deletedNonces = purgeExpiredNonces(now);
		int deletedChallenges = purgeExpiredChallenges(now.minus(CHALLENGE_RETENTION_GRACE));
		if (deletedNonces > 0 || deletedChallenges > 0) {
			log.debug("Purged {} expired request nonces and {} expired recovery challenges",
					deletedNonces, deletedChallenges);
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
}
