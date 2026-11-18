package com.vectevo.deep_sky_server.shared;

import java.util.UUID;

/**
 * Authenticated device identity attached to Spring Security context (`AD-02`).
 */
public record DevicePrincipal(UUID coupleId, UUID deviceId, boolean approved) {
	public DevicePrincipal(UUID coupleId, UUID deviceId) {
		this(coupleId, deviceId, true);
	}
}
