package com.vectevo.deep_sky_server.pairing;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

interface DeviceRepository extends JpaRepository<DeviceEntity, UUID> {
	List<DeviceEntity> findAllByCoupleIdOrderByCreatedAtAsc(UUID coupleId);

	@Query("SELECT d FROM DeviceEntity d "
			+ "WHERE d.revokedAt IS NULL "
			+ "AND d.approvedAt IS NULL "
			+ "AND d.createdAt < :cutoff")
	List<DeviceEntity> findStaleUnapprovedDevices(@Param("cutoff") Instant cutoff);

	@Modifying
	@Query("DELETE FROM DeviceEntity d WHERE d.coupleId = :coupleId")
	int deleteByCoupleId(@Param("coupleId") UUID coupleId);
}
