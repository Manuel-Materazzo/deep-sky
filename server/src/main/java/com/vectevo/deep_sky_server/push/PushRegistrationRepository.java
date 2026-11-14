package com.vectevo.deep_sky_server.push;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PushRegistrationRepository extends JpaRepository<PushRegistrationEntity, UUID> {

	Optional<PushRegistrationEntity> findByDeviceId(String deviceId);

	List<PushRegistrationEntity> findAllByCoupleIdOrderByUpdatedAtDesc(String coupleId);
}
