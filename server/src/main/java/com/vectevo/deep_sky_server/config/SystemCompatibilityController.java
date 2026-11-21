package com.vectevo.deep_sky_server.config;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Exposes minimum client, protocol, and content pack versions enforced by the server (`F-19`, `N-10`, `S2-CTR-01`).
 */
@RestController
@RequestMapping("/api/v1/system")
public class SystemCompatibilityController {

	private final DeepSkyProperties properties;

	public SystemCompatibilityController(DeepSkyProperties properties) {
		this.properties = properties;
	}

	public record CompatibilityPolicy(
			int minClientVersionCode,
			int minProtocolVersion,
			String minPackVersion) {}

	@GetMapping("/compatibility")
	public CompatibilityPolicy getCompatibilityPolicy() {
		return new CompatibilityPolicy(
				properties.protocol().minClientVersionCode(),
				properties.protocol().minProtocolVersion(),
				properties.content().minPackVersion());
	}
}
