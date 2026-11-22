package com.vectevo.deep_sky_server.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.Test;

/** Unit tests for startup configuration validation rules (SRV-03). */
class DeepSkyPropertiesValidationTest {

	@Test
	void devProfileAcceptsDefaultConfiguration() {
		DeepSkyProperties props = defaultDevProps();
		List<String> errors = DeepSkyPropertiesValidator.validate(props, false);
		assertThat(errors).isEmpty();
	}

	@Test
	void prodProfileRejectsLocalhostAndDefaultAdminSecret() {
		DeepSkyProperties props = defaultDevProps();
		List<String> errors = DeepSkyPropertiesValidator.validate(props, true);
		assertThat(errors)
				.hasSize(2)
				.anyMatch(msg -> msg.contains("DEEPSKY_DOMAIN"))
				.anyMatch(msg -> msg.contains("DEEPSKY_ADMIN_SECRET"));
	}

	@Test
	void firebaseEnabledRequiresAllParametersAndReadableServiceAccountFile() {
		DeepSkyProperties props = new DeepSkyProperties(
				"deepsky.vectevo.com",
				"a-very-strong-production-secret-32chars",
				new DeepSkyProperties.Protocol(1, 1),
				new DeepSkyProperties.Quotas(10_485_760L, 1_073_741_824L),
				new DeepSkyProperties.Firebase(true, "", "", "", "", "/nonexistent/sa.json"),
				null);

		List<String> errors = DeepSkyPropertiesValidator.validate(props, true);
		assertThat(errors)
				.anyMatch(msg -> msg.contains("DEEPSKY_FIREBASE_PROJECT_ID"))
				.anyMatch(msg -> msg.contains("DEEPSKY_FIREBASE_API_KEY"))
				.anyMatch(msg -> msg.contains("DEEPSKY_FIREBASE_APP_ID"))
				.anyMatch(msg -> msg.contains("DEEPSKY_FIREBASE_SENDER_ID"))
				.anyMatch(msg -> msg.contains("DEEPSKY_FIREBASE_SERVICE_ACCOUNT_FILE"));
	}

	@Test
	void coupleQuotaSmallerThanMaxBlobIsRejected() {
		DeepSkyProperties props = new DeepSkyProperties(
				"deepsky.vectevo.com",
				"a-very-strong-production-secret-32chars",
				new DeepSkyProperties.Protocol(1, 1),
				new DeepSkyProperties.Quotas(10_000_000L, 5_000_000L),
				new DeepSkyProperties.Firebase(false, "", "", "", "", ""),
				null);

		List<String> errors = DeepSkyPropertiesValidator.validate(props, true);
		assertThat(errors).singleElement().asString().contains("max-couple-storage-bytes");
	}

	private static DeepSkyProperties defaultDevProps() {
		return new DeepSkyProperties(
				"localhost",
				DeepSkyPropertiesValidator.DEV_DEFAULT_ADMIN_SECRET,
				new DeepSkyProperties.Protocol(1, 1),
				new DeepSkyProperties.Quotas(10_485_760L, 1_073_741_824L),
				new DeepSkyProperties.Firebase(false, "", "", "", "", ""),
				null);
	}
}
