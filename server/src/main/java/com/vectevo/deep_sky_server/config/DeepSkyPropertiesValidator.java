package com.vectevo.deep_sky_server.config;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

/**
 * Enforces cross-field and production-profile invariants on {@link DeepSkyProperties}
 * at startup so misconfigured deployments fail fast with actionable messages (SRV-03).
 */
@Component
public class DeepSkyPropertiesValidator implements InitializingBean {

	static final String DEV_DEFAULT_ADMIN_SECRET = "dev-admin-secret-change-me";
	private static final int MIN_PROD_ADMIN_SECRET_LENGTH = 24;

	private final DeepSkyProperties properties;
	private final Environment environment;

	public DeepSkyPropertiesValidator(DeepSkyProperties properties, Environment environment) {
		this.properties = properties;
		this.environment = environment;
	}

	@Override
	public void afterPropertiesSet() {
		List<String> errors = validate(properties, isProdProfile());
		if (!errors.isEmpty()) {
			throw new IllegalStateException(
					"Invalid Deep Sky server configuration:\n - " + String.join("\n - ", errors));
		}
	}

	static List<String> validate(DeepSkyProperties props, boolean prodProfile) {
		List<String> errors = new ArrayList<>();

		if (props.quotas().maxCoupleStorageBytes() < props.quotas().maxBlobBytes()) {
			errors.add("deepsky.quotas.max-couple-storage-bytes ("
					+ props.quotas().maxCoupleStorageBytes()
					+ ") must be >= deepsky.quotas.max-blob-bytes ("
					+ props.quotas().maxBlobBytes() + ")");
		}

		if (prodProfile) {
			if ("localhost".equalsIgnoreCase(props.domain().trim())) {
				errors.add("DEEPSKY_DOMAIN cannot be 'localhost' when 'prod' profile is active.");
			}
			String secret = props.adminSecret().trim();
			if (DEV_DEFAULT_ADMIN_SECRET.equals(secret) || secret.length() < MIN_PROD_ADMIN_SECRET_LENGTH) {
				errors.add("DEEPSKY_ADMIN_SECRET must be changed from the dev placeholder and be at least "
						+ MIN_PROD_ADMIN_SECRET_LENGTH + " characters in 'prod' profile.");
			}
		}

		DeepSkyProperties.Firebase fb = props.firebase();
		if (fb.enabled()) {
			requireNonBlank(fb.projectId(), "DEEPSKY_FIREBASE_PROJECT_ID", errors);
			requireNonBlank(fb.apiKey(), "DEEPSKY_FIREBASE_API_KEY", errors);
			requireNonBlank(fb.appId(), "DEEPSKY_FIREBASE_APP_ID", errors);
			requireNonBlank(fb.senderId(), "DEEPSKY_FIREBASE_SENDER_ID", errors);
			if (isBlank(fb.serviceAccountFile())) {
				errors.add("DEEPSKY_FIREBASE_SERVICE_ACCOUNT_FILE is required when DEEPSKY_FIREBASE_ENABLED=true.");
			} else {
				Path path = Path.of(fb.serviceAccountFile());
				if (!Files.isRegularFile(path) || !Files.isReadable(path)) {
					errors.add("DEEPSKY_FIREBASE_SERVICE_ACCOUNT_FILE does not point to a readable file: " + path);
				}
			}
		}

		return errors;
	}

	private boolean isProdProfile() {
		return Arrays.asList(environment.getActiveProfiles()).contains("prod");
	}

	private static void requireNonBlank(String value, String envVar, List<String> errors) {
		if (isBlank(value)) {
			errors.add(envVar + " is required when DEEPSKY_FIREBASE_ENABLED=true.");
		}
	}

	private static boolean isBlank(String value) {
		return value == null || value.isBlank();
	}
}
