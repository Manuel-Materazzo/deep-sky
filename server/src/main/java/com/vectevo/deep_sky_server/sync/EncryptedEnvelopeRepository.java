package com.vectevo.deep_sky_server.sync;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

interface EncryptedEnvelopeRepository extends JpaRepository<EncryptedEnvelopeEntity, UUID> {
	List<EncryptedEnvelopeEntity> findAllByCoupleIdAndSeqGreaterThanOrderBySeqAsc(UUID coupleId, long afterSeq);

	List<EncryptedEnvelopeEntity> findAllByCoupleIdOrderBySeqAsc(UUID coupleId);
}
