package com.vectevo.deep_sky_server.config;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Typed configuration properties for the Deep Sky server (SRV-03).
 * Validated at startup together with {@link DeepSkyPropertiesValidator}.
 */
@Validated
@ConfigurationProperties(prefix = "deepsky")
public record DeepSkyProperties(
		@NotBlank(message = "DEEPSKY_DOMAIN must be set") String domain,
		@NotBlank(message = "DEEPSKY_ADMIN_SECRET must be set") String adminSecret,
		@Valid @NotNull Protocol protocol,
		@Valid @NotNull Quotas quotas,
		@Valid @NotNull Firebase firebase
) {
	public record Protocol(
			@Min(value = 1, message = "DEEPSKY_MIN_CLIENT_VERSION_CODE must be >= 1") int minClientVersionCode,
			@Min(value = 1, message = "DEEPSKY_MIN_PROTOCOL_VERSION must be >= 1") int minProtocolVersion
	) {}

	public record Quotas(
			@Min(value = 1024, message = "DEEPSKY_MAX_BLOB_BYTES must be >= 1024") long maxBlobBytes,
			@Min(value = 1024, message = "DEEPSKY_MAX_COUPLE_STORAGE_BYTES must be >= 1024") long maxCoupleStorageBytes
	) {}

	public record Firebase(
			boolean enabled,
			String projectId,
			String apiKey,
			String appId,
			String senderId,
			String serviceAccountFile
	) {}
}
