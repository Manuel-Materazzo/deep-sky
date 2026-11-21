package com.vectevo.deep_sky_server.content;

import java.util.Map;

/**
 * Pure configuration holder for the content pack module, decoupled from {@code config}
 * to satisfy ArchUnit boundaries (ADR-0004, S2-SRV-01).
 */
public record ContentPackConfig(
		String packsDir,
		String minPackVersion,
		Map<String, String> trustedPublicKeys
) {
	public ContentPackConfig {
		packsDir = packsDir == null ? "" : packsDir.trim();
		minPackVersion = (minPackVersion == null || minPackVersion.isBlank()) ? "1.0.0" : minPackVersion.trim();
		trustedPublicKeys = trustedPublicKeys == null ? Map.of() : Map.copyOf(trustedPublicKeys);
	}
}
