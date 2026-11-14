package com.vectevo.deep_sky_server.pairing;

import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

interface RecoveryChallengeRepository extends JpaRepository<RecoveryChallengeEntity, UUID> {}
