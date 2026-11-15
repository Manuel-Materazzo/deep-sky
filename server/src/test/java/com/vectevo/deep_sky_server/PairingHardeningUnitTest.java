package com.vectevo.deep_sky_server;

import static org.assertj.core.api.Assertions.assertThat;

import com.vectevo.deep_sky_server.config.PublicEndpointRateLimiter;
import com.vectevo.deep_sky_server.config.PublicEndpointRateLimiter.RouteGroup;
import com.vectevo.deep_sky_server.push.PushService;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

/**
 * Pure JVM unit tests for S1-SRV-01 / S1-SRV-02 rate limiting and push key allowlist.
 */
class PairingHardeningUnitTest {

	@Test
	void inviteRedeemRateLimiterIsStricterThanInviteCreation() {
		Clock fixed = Clock.fixed(Instant.parse("2026-11-15T20:00:00Z"), ZoneOffset.UTC);
		PublicEndpointRateLimiter limiter = new PublicEndpointRateLimiter(
				fixed,
				Duration.ofSeconds(60),
				20,
				5,
				10);

		for (int i = 0; i < 5; i++) {
			assertThat(limiter.tryConsume("198.51.100.44", RouteGroup.INVITE_REDEEM).allowed()).isTrue();
		}
		var blocked = limiter.tryConsume("198.51.100.44", RouteGroup.INVITE_REDEEM);
		assertThat(blocked.allowed()).isFalse();
		assertThat(blocked.retryAfterSeconds()).isPositive();

		// Invite creation bucket for the same IP remains independent
		assertThat(limiter.tryConsume("198.51.100.44", RouteGroup.INVITES).allowed()).isTrue();
	}

	@Test
	void pushServiceSupportsPairingRequestWakeupKey() {
		assertThat(PushService.SUPPORTED_KEYS).contains("wakeup.pairing_request");
	}
}
