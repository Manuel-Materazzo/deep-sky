package com.vectevo.deep_sky_server.push;

/**
 * Push module view of runtime Firebase configuration (SP-01, TC-04, ADR-0004).
 * Kept in {@code push} so domain code stays decoupled from {@code config}.
 */
public record PushConfig(
		boolean enabled,
		String projectId,
		String apiKey,
		String appId,
		String senderId,
		String serviceAccountFile
) {
	public boolean hasClientOptions() {
		return isNonBlank(projectId)
				&& isNonBlank(apiKey)
				&& isNonBlank(appId)
				&& isNonBlank(senderId);
	}

	public boolean hasServerCredentials() {
		return enabled && isNonBlank(projectId) && isNonBlank(serviceAccountFile);
	}

	private static boolean isNonBlank(String value) {
		return value != null && !value.isBlank();
	}
}
