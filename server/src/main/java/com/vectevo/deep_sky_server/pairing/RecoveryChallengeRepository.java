package com.vectevo.deep_sky_server.pairing;

import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

interface RecoveryChallengeRepository extends JpaRepository<RecoveryChallengeEntity, UUID> {

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("SELECT c FROM RecoveryChallengeEntity c WHERE c.id = :id")
	Optional<RecoveryChallengeEntity> findByIdForUpdate(@Param("id") UUID id);

	@Modifying
	@Query("DELETE FROM RecoveryChallengeEntity c WHERE c.expiresAt < :cutoff")
	int deleteExpiredBefore(@Param("cutoff") Instant cutoff);
}
