package com.vectevo.deep_sky_server.pairing;

import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

interface PairingInviteRepository extends JpaRepository<PairingInviteEntity, UUID> {
	Optional<PairingInviteEntity> findByTokenHash(byte[] tokenHash);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("SELECT i FROM PairingInviteEntity i WHERE i.tokenHash = :tokenHash")
	Optional<PairingInviteEntity> findByTokenHashForUpdate(@Param("tokenHash") byte[] tokenHash);

	List<PairingInviteEntity> findAllByCoupleIdOrderByExpiresAtAsc(UUID coupleId);

	@Modifying
	@Query("DELETE FROM PairingInviteEntity i WHERE i.expiresAt < :cutoff")
	int deleteExpiredBefore(@Param("cutoff") Instant cutoff);
}
