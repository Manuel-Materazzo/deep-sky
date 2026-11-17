package com.vectevo.deep_sky_server.pairing;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

interface KeyDeliveryRepository extends JpaRepository<KeyDeliveryEntity, UUID> {
	Optional<KeyDeliveryEntity> findFirstByToDeviceIdOrderByCreatedAtDesc(UUID toDeviceId);

	Optional<KeyDeliveryEntity> findFirstByToDeviceIdAndDeliveryKindOrderByKeyEpochDescCreatedAtDesc(
			UUID toDeviceId, String deliveryKind);

	List<KeyDeliveryEntity> findAllByCoupleIdOrderByCreatedAtAsc(UUID coupleId);
}
