package com.vectevo.deep_sky_server.pairing;

import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

interface CoupleRepository extends JpaRepository<CoupleEntity, UUID> {
	Optional<CoupleEntity> findByRecoveryAuthPublicKey(byte[] recoveryAuthPublicKey);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("SELECT c FROM CoupleEntity c WHERE c.id = :id")
	Optional<CoupleEntity> findByIdForUpdate(@Param("id") UUID id);

	@Query(
			value = "SELECT c.id FROM couples c "
					+ "WHERE c.unpaired_at IS NULL "
					+ "AND c.created_at < :cutoff "
					+ "AND (SELECT COUNT(*) FROM devices d WHERE d.couple_id = c.id) = 1 "
					+ "AND NOT EXISTS (SELECT 1 FROM devices d WHERE d.couple_id = c.id AND d.enrolled_via <> 'INVITE_INIT') "
					+ "AND NOT EXISTS (SELECT 1 FROM pairing_invites i WHERE i.couple_id = c.id) "
					+ "AND NOT EXISTS (SELECT 1 FROM key_deliveries k WHERE k.couple_id = c.id) "
					+ "AND NOT EXISTS (SELECT 1 FROM recovery_challenges r WHERE r.couple_id = c.id) "
					+ "AND NOT EXISTS (SELECT 1 FROM encrypted_envelopes e WHERE e.couple_id = c.id)",
			nativeQuery = true)
	List<UUID> findOrphanNeverPairedCoupleIds(@Param("cutoff") Instant cutoff);
}
