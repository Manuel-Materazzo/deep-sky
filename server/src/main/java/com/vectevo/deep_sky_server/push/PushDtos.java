package com.vectevo.deep_sky_server.push;

import java.time.Instant;

/** Public DTOs for SP-01 push configuration, registration, and wakeup dispatch. */
public final class PushDtos {

	private PushDtos() {}

	public record ClientConfig(
			boolean enabled,
			String projectId,
			String apiKey,
			String appId,
			String senderId) {}

	public record RegisterTokenRequest(
			String deviceId,
			String coupleId,
			String fcmToken,
			String platform) {}

	public record TokenStatus(
			String deviceId,
			String coupleId,
			String platform,
			String tokenPrefix,
			int tokenLength,
			Instant updatedAt,
			Instant lastWakeupAt) {}

	public record SendWakeupRequest(
			String deviceId,
			String coupleId,
			String localizationKey) {}

	public record WakeupOutcome(
			String localizationKey,
			int attempted,
			int delivered,
			int unregisteredRemoved) {}
}
