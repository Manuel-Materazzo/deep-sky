package com.vectevo.deep_sky_server.config;

import java.util.List;
import org.springframework.http.HttpMethod;

/**
 * Single source of truth for unauthenticated {@code /api/v1/**} routes shared by
 * {@link SecurityConfig} and {@link DeviceAuthFilter} ({@code AU-01}).
 */
public final class PublicRoutes {

	public static final String CONTENT_PACK_PREFIX = "/api/v1/content/pack/";
	public static final String CONTENT_PACK_PATTERN = "/api/v1/content/pack/**";

	public static final List<String> PUBLIC_GET_EXACT = List.of(
			"/api/v1/system/compatibility",
			"/api/v1/push/config");

	public static final String[] PUBLIC_GET_PATTERNS = {
			"/api/v1/system/compatibility",
			"/api/v1/push/config",
			CONTENT_PACK_PATTERN
	};

	public static final List<String> PUBLIC_POST_EXACT = List.of(
			"/api/v1/pairing/invites",
			"/api/v1/pairing/invites/accept",
			"/api/v1/recovery/challenges",
			"/api/v1/recovery/complete");

	public static final String[] PUBLIC_POST_PATTERNS = PUBLIC_POST_EXACT.toArray(String[]::new);

	private PublicRoutes() {}

	public static boolean isPublicApiRequest(String method, String path) {
		if (HttpMethod.GET.matches(method)) {
			return PUBLIC_GET_EXACT.contains(path) || path.startsWith(CONTENT_PACK_PREFIX);
		}
		if (HttpMethod.POST.matches(method)) {
			return PUBLIC_POST_EXACT.contains(path);
		}
		return false;
	}
}
