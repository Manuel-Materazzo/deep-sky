package com.vectevo.deep_sky_server.pairing;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

interface PairingInviteRepository extends JpaRepository<PairingInviteEntity, UUID> {
	Optional<PairingInviteEntity> findByTokenHash(byte[] tokenHash);

	List<PairingInviteEntity> findAllByCoupleIdOrderByExpiresAtAsc(UUID coupleId);
}
