package com.vectevo.deep_sky_server.pairing;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

interface DeviceRepository extends JpaRepository<DeviceEntity, UUID> {
	List<DeviceEntity> findAllByCoupleIdOrderByCreatedAtAsc(UUID coupleId);

	@Query("SELECT d FROM DeviceEntity d "
			+ "WHERE d.revokedAt IS NULL "
			+ "AND d.enrolledVia IN ('INVITE_JOIN', 'ENROLLMENT') "
			+ "AND d.createdAt < :cutoff "
			+ "AND NOT EXISTS (SELECT 1 FROM KeyDeliveryEntity k WHERE k.toDeviceId = d.id)")
	List<DeviceEntity> findStaleUnapprovedDevices(@Param("cutoff") Instant cutoff);
}
