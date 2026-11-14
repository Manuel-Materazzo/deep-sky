package com.vectevo.deep_sky_server.pairing;

import java.time.Instant;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

interface RequestNonceRepository extends JpaRepository<RequestNonceEntity, RequestNonceEntity.NonceId> {

	@Modifying
	@Query(
			value = "INSERT INTO request_nonces (device_id, nonce, expires_at) "
					+ "VALUES (:deviceId, :nonce, :expiresAt) ON CONFLICT DO NOTHING",
			nativeQuery = true)
	int insertIfAbsent(
			@Param("deviceId") UUID deviceId,
			@Param("nonce") String nonce,
			@Param("expiresAt") Instant expiresAt);

	@Modifying
	@Query("DELETE FROM RequestNonceEntity n WHERE n.expiresAt < :cutoff")
	int deleteExpired(@Param("cutoff") Instant cutoff);
}
