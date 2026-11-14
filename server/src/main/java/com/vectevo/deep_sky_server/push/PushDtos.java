package com.vectevo.deep_sky_server.push;

import jakarta.validation.constraints.NotBlank;
import java.time.Instant;

/** Public DTOs for runtime push configuration, registration, and wakeup dispatch (`SP-01`, `PR-M2-03`). */
public final class PushDtos {

	private PushDtos() {}

	public record ClientConfig(
			boolean enabled,
			String projectId,
			String apiKey,
			String appId,
			String senderId) {}

	public record RegisterTokenRequest(
			@NotBlank String fcmToken,
			String platform) {}

	public record TokenStatus(
			String deviceId,
			String coupleId,
			String platform,
			String tokenPrefix,
			int tokenLength,
			Instant updatedAt,
			Instant lastWakeupAt) {}

	public record SendWakeupRequest(String localizationKey) {}

	public record WakeupOutcome(
			String localizationKey,
			int attempted,
			int delivered,
			int unregisteredRemoved) {}
}
