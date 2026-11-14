package com.vectevo.deep_sky_server.pairing;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

interface CoupleRepository extends JpaRepository<CoupleEntity, UUID> {
	Optional<CoupleEntity> findByRecoveryAuthPublicKey(byte[] recoveryAuthPublicKey);
}
