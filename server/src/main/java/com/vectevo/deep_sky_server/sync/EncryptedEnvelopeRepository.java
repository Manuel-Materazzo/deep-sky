package com.vectevo.deep_sky_server.sync;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

interface EncryptedEnvelopeRepository extends JpaRepository<EncryptedEnvelopeEntity, UUID> {
	List<EncryptedEnvelopeEntity> findByCoupleIdAndSeqGreaterThanOrderBySeqAsc(
			UUID coupleId, long afterSeq, Pageable pageable);

	List<EncryptedEnvelopeEntity> findTop200ByCoupleIdOrderBySeqDesc(UUID coupleId);

	@Query(
			value = "SELECT CAST(COALESCE(SUM(OCTET_LENGTH(ciphertext) + OCTET_LENGTH(nonce)), 0) AS BIGINT) "
					+ "FROM encrypted_envelopes WHERE couple_id = :coupleId",
			nativeQuery = true)
	long sumStoredBytesByCoupleId(@Param("coupleId") UUID coupleId);

	@Modifying
	@Query(
			value = "INSERT INTO encrypted_envelopes "
					+ "(id, couple_id, sender_device_id, channel, key_epoch, nonce, ciphertext, created_at) "
					+ "VALUES (:id, :coupleId, :senderDeviceId, :channel, :keyEpoch, :nonce, :ciphertext, :createdAt) "
					+ "ON CONFLICT (id) DO NOTHING",
			nativeQuery = true)
	int insertIfAbsent(
			@Param("id") UUID id,
			@Param("coupleId") UUID coupleId,
			@Param("senderDeviceId") UUID senderDeviceId,
			@Param("channel") String channel,
			@Param("keyEpoch") int keyEpoch,
			@Param("nonce") byte[] nonce,
			@Param("ciphertext") byte[] ciphertext,
			@Param("createdAt") Instant createdAt);
}
