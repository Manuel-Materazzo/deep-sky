package com.vectevo.deep_sky_server.config;

import com.vectevo.deep_sky_server.push.FcmHttpV1PushProvider;
import com.vectevo.deep_sky_server.push.NoopPushProvider;
import com.vectevo.deep_sky_server.push.PushConfig;
import com.vectevo.deep_sky_server.push.PushProvider;
import com.vectevo.deep_sky_server.push.ServiceAccountTokenProvider;
import java.io.IOException;
import java.nio.file.Path;
import java.time.Clock;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;
import tools.jackson.databind.ObjectMapper;

/**
 * Wires runtime Firebase configuration from {@link DeepSkyProperties} into {@code push} beans
 * while preserving package isolation enforced by {@code ArchitectureTest} (ADR-0004).
 */
@Configuration
public class PushConfiguration {

	@Bean
	Clock systemClock() {
		return Clock.systemUTC();
	}

	@Bean
	PushConfig pushConfig(DeepSkyProperties properties) {
		DeepSkyProperties.Firebase fb = properties.firebase();
		return new PushConfig(
				fb.enabled(),
				fb.projectId(),
				fb.apiKey(),
				fb.appId(),
				fb.senderId(),
				fb.serviceAccountFile());
	}

	@Bean
	PushProvider pushProvider(PushConfig pushConfig, ObjectMapper objectMapper, Clock clock)
			throws IOException {
		if (!pushConfig.hasServerCredentials()) {
			return new NoopPushProvider();
		}
		RestClient restClient = RestClient.create();
		ServiceAccountTokenProvider tokenProvider = new ServiceAccountTokenProvider(
				Path.of(pushConfig.serviceAccountFile()),
				restClient,
				objectMapper,
				clock);
		return new FcmHttpV1PushProvider(pushConfig.projectId(), tokenProvider, restClient, clock);
	}
}
