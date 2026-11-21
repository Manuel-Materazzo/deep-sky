package com.vectevo.deep_sky_server.sync;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.vectevo.deep_sky_server.pairing.DeviceAuthLookup;
import com.vectevo.deep_sky_server.shared.DevicePrincipal;
import com.vectevo.deep_sky_server.shared.PartnerWakeupRequestedEvent;
import com.vectevo.deep_sky_server.shared.StaleKeyEpochException;
import com.vectevo.deep_sky_server.shared.StorageQuotaExceededException;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;

/**
 * Pure JVM unit tests for SyncService pagination, storage quota enforcement (CA-08),
 * and post-commit wakeup event publishing (CA-07).
 */
class SyncServiceUnitTest {

	private EncryptedEnvelopeRepository envelopeRepository;
	private ApplicationEventPublisher eventPublisher;
	private SyncService syncService;

	@BeforeEach
	void setUp() {
		envelopeRepository = mock(EncryptedEnvelopeRepository.class);
		eventPublisher = mock(ApplicationEventPublisher.class);
		syncService = new SyncService(envelopeRepository, eventPublisher, 1024L, 128L);
	}

	@Test
	void enforcesCoupleStorageQuotaAndPublishesWakeupEvent() {
		UUID coupleId = UUID.randomUUID();
		UUID deviceId = UUID.randomUUID();
		DevicePrincipal principal = new DevicePrincipal(coupleId, deviceId, true);
		String nonceB64 = Base64.getUrlEncoder().encodeToString(new byte[24]);
		String cipherB64 = Base64.getUrlEncoder().encodeToString(new byte[40]); // 24 + 40 = 64 bytes

		UUID envId = UUID.randomUUID();
		when(envelopeRepository.findById(envId)).thenReturn(Optional.empty(), Optional.of(makeEntity(envId, coupleId, deviceId, 1L)));
		when(envelopeRepository.sumStoredBytesByCoupleId(coupleId)).thenReturn(60L);
		when(envelopeRepository.insertIfAbsent(
				eq(envId), eq(coupleId), eq(deviceId), eq("EVENT"), eq(1), any(), any(), any()))
				.thenReturn(1);

		syncService.storeEnvelope(principal, envId, "EVENT", 1, nonceB64, cipherB64);
		verify(eventPublisher).publishEvent(new PartnerWakeupRequestedEvent(
				coupleId, deviceId, "wakeup.thinking_of_you"));

		// Next upload pushes used bytes (124 + 64 = 188 > 128) over couple quota
		UUID env2 = UUID.randomUUID();
		when(envelopeRepository.findById(env2)).thenReturn(Optional.empty());
		when(envelopeRepository.sumStoredBytesByCoupleId(coupleId)).thenReturn(124L);
		assertThatThrownBy(() -> syncService.storeEnvelope(principal, env2, "EVENT", 1, nonceB64, cipherB64))
				.isInstanceOf(StorageQuotaExceededException.class)
				.satisfies(ex -> assertThat(((StorageQuotaExceededException) ex).getErrorCode())
						.isEqualTo("COUPLE_STORAGE_QUOTA_EXCEEDED"));

		// Foreign envelope ID returns uniform response without conflict oracle (CA-14)
		UUID foreignEnvId = UUID.randomUUID();
		when(envelopeRepository.findById(foreignEnvId))
				.thenReturn(Optional.of(makeEntity(foreignEnvId, UUID.randomUUID(), UUID.randomUUID(), 99L)));
		var foreignRes = syncService.storeEnvelope(principal, foreignEnvId, "EVENT", 1, nonceB64, cipherB64);
		assertThat(foreignRes.coupleId()).isEqualTo(coupleId);
		assertThat(foreignRes.envelopeId()).isEqualTo(foreignEnvId);
	}

	@Test
	void listEnvelopesPaginatesWithNextAfterSeqAndHasMore() {
		UUID coupleId = UUID.randomUUID();
		UUID deviceId = UUID.randomUUID();
		DevicePrincipal principal = new DevicePrincipal(coupleId, deviceId, true);

		EncryptedEnvelopeEntity e1 = makeEntity(UUID.randomUUID(), coupleId, deviceId, 11L);
		EncryptedEnvelopeEntity e2 = makeEntity(UUID.randomUUID(), coupleId, deviceId, 12L);
		EncryptedEnvelopeEntity e3 = makeEntity(UUID.randomUUID(), coupleId, deviceId, 13L);

		when(envelopeRepository.findByCoupleIdAndSeqGreaterThanOrderBySeqAsc(
				eq(coupleId), eq(10L), eq(PageRequest.of(0, 3))))
				.thenReturn(List.of(e1, e2, e3));

		var page1 = syncService.listEnvelopes(principal, 10L, 2);
		assertThat(page1.items()).hasSize(2);
		assertThat(page1.hasMore()).isTrue();
		assertThat(page1.nextAfterSeq()).isEqualTo(12L);

		when(envelopeRepository.findByCoupleIdAndSeqGreaterThanOrderBySeqAsc(
				eq(coupleId), eq(12L), eq(PageRequest.of(0, 3))))
				.thenReturn(List.of(e3));

		var page2 = syncService.listEnvelopes(principal, 12L, 2);
		assertThat(page2.items()).hasSize(1);
		assertThat(page2.hasMore()).isFalse();
		assertThat(page2.nextAfterSeq()).isEqualTo(13L);
	}

	@Test
	void storeEnvelopeRejectsStaleKeyEpochWithConflictException() {
		DeviceAuthLookup lookup = mock(DeviceAuthLookup.class);
		SyncService guardedSync = new SyncService(envelopeRepository, eventPublisher, lookup, 1024L, 4096L);
		UUID coupleId = UUID.randomUUID();
		UUID deviceId = UUID.randomUUID();
		DevicePrincipal principal = new DevicePrincipal(coupleId, deviceId, true);
		when(lookup.getCurrentKeyEpoch(coupleId)).thenReturn(3);

		String nonceB64 = Base64.getUrlEncoder().encodeToString(new byte[24]);
		String cipherB64 = Base64.getUrlEncoder().encodeToString(new byte[40]);

		assertThatThrownBy(() -> guardedSync.storeEnvelope(principal, UUID.randomUUID(), "EVENT", 2, nonceB64, cipherB64))
				.isInstanceOf(StaleKeyEpochException.class)
				.satisfies(ex -> assertThat(((StaleKeyEpochException) ex).getCurrentKeyEpoch()).isEqualTo(3));

		// AU-21: Future keyEpoch exceeding couple currentKeyEpoch is rejected
		assertThatThrownBy(() -> guardedSync.storeEnvelope(principal, UUID.randomUUID(), "EVENT", 4, nonceB64, cipherB64))
				.isInstanceOf(IllegalArgumentException.class);

		// AU-21: Atomic stored_bytes quota reservation failure throws StorageQuotaExceededException
		UUID envOverQuota = UUID.randomUUID();
		when(envelopeRepository.findById(envOverQuota)).thenReturn(Optional.empty());
		when(envelopeRepository.insertIfAbsent(
				eq(envOverQuota), eq(coupleId), eq(deviceId), eq("EVENT"), eq(3), any(), any(), any()))
				.thenReturn(1);
		when(lookup.tryReserveStorageBytes(coupleId, 64L, 4096L)).thenReturn(false);
		assertThatThrownBy(() -> guardedSync.storeEnvelope(principal, envOverQuota, "EVENT", 3, nonceB64, cipherB64))
				.isInstanceOf(StorageQuotaExceededException.class)
				.satisfies(ex -> assertThat(((StorageQuotaExceededException) ex).getErrorCode())
						.isEqualTo("COUPLE_STORAGE_QUOTA_EXCEEDED"));

		var page = guardedSync.listEnvelopes(principal, 0L, 10);
		assertThat(page.coupleKeyEpoch()).isEqualTo(3);
	}

	private static EncryptedEnvelopeEntity makeEntity(UUID id, UUID coupleId, UUID deviceId, long seq) {
		EncryptedEnvelopeEntity e = new EncryptedEnvelopeEntity();
		e.setId(id);
		e.setCoupleId(coupleId);
		e.setSenderDeviceId(deviceId);
		e.setSeq(seq);
		e.setChannel("EVENT");
		e.setKeyEpoch(1);
		e.setNonce(new byte[24]);
		e.setCiphertext(new byte[40]);
		e.setCreatedAt(Instant.now());
		return e;
	}
}
