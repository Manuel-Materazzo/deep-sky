package com.vectevo.deep_sky_server.pairing;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

interface DeviceRepository extends JpaRepository<DeviceEntity, UUID> {
	List<DeviceEntity> findAllByCoupleIdOrderByCreatedAtAsc(UUID coupleId);
}
