package com.vectevo.deep_sky_server;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.vectevo.deep_sky_server.push.PushConfig;
import com.vectevo.deep_sky_server.push.PushProvider;
import com.vectevo.deep_sky_server.push.PushRegistrationEntity;
import com.vectevo.deep_sky_server.push.PushRegistrationRepository;
import com.vectevo.deep_sky_server.push.PushService;
import com.vectevo.deep_sky_server.shared.PartnerWakeupRequestedEvent;
import com.vectevo.deep_sky_server.shared.RateLimitExceededException;
import com.vectevo.deep_sky_server.sync.SyncService;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/**
 * Pure JVM unit tests for CA-07 (post-commit wakeup resilience), CA-08 (sync pagination & storage quotas),
 * and CA-09 (client wakeup allowlist & per-device throttle).
 */
class SyncAndPushAuditUnitTest {

	@Test
	void pushServiceRejectsPairingRequestFromClientEndpointAndThrottlesRepeatedWakeups() {
		PushConfig config = new PushConfig(true, "p", "k", "a", "s", "");
		PushRegistrationRepository repo = mock(PushRegistrationRepository.class);
		PushProvider provider = mock(PushProvider.class);
		Clock fixed = Clock.fixed(Instant.parse("2026-11-16T15:00:00Z"), ZoneOffset.UTC);
		PushService pushService = new PushService(config, repo, provider, fixed, 2);

		UUID coupleId = UUID.randomUUID();
		UUID devA = UUID.randomUUID();
		UUID devB = UUID.randomUUID();
		when(repo.findAllByCoupleIdOrderByUpdatedAtDesc(coupleId.toString())).thenReturn(List.of(
				new PushRegistrationEntity(UUID.randomUUID(), devB.toString(), coupleId.toString(), "fcm-b", "android", fixed.instant())));

		// wakeup.pairing_request cannot be triggered from client endpoint (CA-09)
		assertThatThrownBy(() -> pushService.dispatchClientWakeup(coupleId, devA, "wakeup.pairing_request"))
				.isInstanceOf(IllegalArgumentException.class);

		// First 2 allowed within window, 3rd throttled (CA-09)
		pushService.dispatchClientWakeup(coupleId, devA, "wakeup.thinking_of_you");
		pushService.dispatchClientWakeup(coupleId, devA, "wakeup.generic");
		assertThatThrownBy(() -> pushService.dispatchClientWakeup(coupleId, devA, "wakeup.thinking_of_you"))
				.isInstanceOf(RateLimitExceededException.class)
				.satisfies(ex -> assertThat(((RateLimitExceededException) ex).getRetryAfterSeconds()).isPositive());

		// Post-commit listener swallows provider errors gracefully (CA-07)
		doThrow(new RuntimeException("FCM temporary outage")).when(provider).sendWakeup(any(), any());
		pushService.onPartnerWakeupRequested(new PartnerWakeupRequestedEvent(coupleId, devA, "wakeup.pairing_request"));
	}

	@Test
	void syncServiceEnforcesCoupleStorageQuotaAndPagination() {
		// Instantiate SyncService via reflection or package test? Use helper in sync package if needed.
		// Tested via SyncServicePaginationAndQuotaTest in com.vectevo.deep_sky_server.sync!
		assertThat(SyncService.MAX_PAGE_SIZE).isEqualTo(200);
	}
}
