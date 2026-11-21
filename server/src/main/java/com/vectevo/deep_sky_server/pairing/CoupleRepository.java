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

interface CoupleRepository extends JpaRepository<CoupleEntity, UUID> {
	Optional<CoupleEntity> findByRecoveryAuthPublicKey(byte[] recoveryAuthPublicKey);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("SELECT c FROM CoupleEntity c WHERE c.id = :id")
	Optional<CoupleEntity> findByIdForUpdate(@Param("id") UUID id);

	/**
	 * Atomically reserves storage bytes against the couple's quota within the active transaction ({@code AU-21}).
	 */
	@Modifying
	@Query(
			value = "UPDATE couples SET stored_bytes = stored_bytes + :delta "
					+ "WHERE id = :coupleId AND stored_bytes + :delta <= :maxBytes",
			nativeQuery = true)
	int tryReserveStorageBytes(
			@Param("coupleId") UUID coupleId,
			@Param("delta") long delta,
			@Param("maxBytes") long maxBytes);

	/**
	 * Finds abandoned never-paired couples, including those whose only additional devices were
	 * never-approved joiners later revoked by cleanup ({@code CA-17}, {@code AU-20}).
	 */
	@Query(
			value = "SELECT c.id FROM couples c "
					+ "WHERE c.unpaired_at IS NULL "
					+ "AND c.created_at < :cutoff "
					+ "AND (SELECT COUNT(*) FROM devices d WHERE d.couple_id = c.id "
					+ "     AND (d.approved_at IS NOT NULL OR d.revoked_at IS NULL)) <= 1 "
					+ "AND NOT EXISTS (SELECT 1 FROM devices d WHERE d.couple_id = c.id "
					+ "     AND d.enrolled_via <> 'INVITE_INIT' "
					+ "     AND (d.approved_at IS NOT NULL OR d.revoked_at IS NULL)) "
					+ "AND NOT EXISTS (SELECT 1 FROM pairing_invites i WHERE i.couple_id = c.id) "
					+ "AND NOT EXISTS (SELECT 1 FROM key_deliveries k WHERE k.couple_id = c.id) "
					+ "AND NOT EXISTS (SELECT 1 FROM recovery_challenges r WHERE r.couple_id = c.id) "
					+ "AND NOT EXISTS (SELECT 1 FROM encrypted_envelopes e WHERE e.couple_id = c.id)",
			nativeQuery = true)
	List<UUID> findOrphanNeverPairedCoupleIds(@Param("cutoff") Instant cutoff);

	/**
	 * Finds unpaired couples whose retention window has elapsed ({@code AU-20}).
	 */
	@Query(
			value = "SELECT c.id FROM couples c WHERE c.unpaired_at IS NOT NULL AND c.unpaired_at < :cutoff",
			nativeQuery = true)
	List<UUID> findUnpairedCoupleIdsBefore(@Param("cutoff") Instant cutoff);

	@Modifying
	@Query(value = "DELETE FROM encrypted_envelopes WHERE couple_id = :coupleId", nativeQuery = true)
	void deleteEnvelopesByCoupleId(@Param("coupleId") UUID coupleId);

	@Modifying
	@Query(value = "DELETE FROM key_deliveries WHERE couple_id = :coupleId", nativeQuery = true)
	void deleteKeyDeliveriesByCoupleId(@Param("coupleId") UUID coupleId);

	@Modifying
	@Query(value = "DELETE FROM recovery_challenges WHERE couple_id = :coupleId", nativeQuery = true)
	void deleteRecoveryChallengesByCoupleId(@Param("coupleId") UUID coupleId);

	@Modifying
	@Query(value = "DELETE FROM pairing_invites WHERE couple_id = :coupleId", nativeQuery = true)
	void deleteInvitesByCoupleId(@Param("coupleId") UUID coupleId);
}
