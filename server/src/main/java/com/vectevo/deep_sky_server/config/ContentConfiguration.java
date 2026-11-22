package com.vectevo.deep_sky_server.config;

import com.vectevo.deep_sky_server.content.ContentPackConfig;
import com.vectevo.deep_sky_server.content.ContentPackStore;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import tools.jackson.databind.ObjectMapper;

/**
 * Wires {@link DeepSkyProperties.Content} into {@code content} module beans while
 * preserving ArchUnit package boundaries (`ADR-0004`, `S2-SRV-01`).
 */
@Configuration
public class ContentConfiguration {

	@Bean
	ContentPackConfig contentPackConfig(DeepSkyProperties properties) {
		DeepSkyProperties.Content content = properties.content();
		return new ContentPackConfig(
				content.packsDir(),
				content.minPackVersion(),
				content.trustedPublicKeys());
	}

	@Bean
	ContentPackStore contentPackStore(ContentPackConfig config, ObjectMapper objectMapper) {
		return new ContentPackStore(config, objectMapper);
	}
}
