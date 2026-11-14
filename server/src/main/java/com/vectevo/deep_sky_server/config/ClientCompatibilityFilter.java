package com.vectevo.deep_sky_server.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Enforces minimum Android client `versionCode` and E2EE protocol version (`F-19`, `N-10`, `PR-M2-02`).
 */
public class ClientCompatibilityFilter extends OncePerRequestFilter {

	public static final String HEADER_CLIENT_VERSION = "X-Client-Version-Code";
	public static final String HEADER_PROTOCOL_VERSION = "X-Protocol-Version";
	public static final String HEADER_MIN_CLIENT_VERSION = "X-Min-Client-Version-Code";
	public static final String HEADER_MIN_PROTOCOL_VERSION = "X-Min-Protocol-Version";

	private static final int HTTP_UPGRADE_REQUIRED = 426;

	private final DeepSkyProperties properties;

	public ClientCompatibilityFilter(DeepSkyProperties properties) {
		this.properties = properties;
	}

	@Override
	protected boolean shouldNotFilter(HttpServletRequest request) {
		String path = request.getRequestURI();
		return !path.startsWith("/api/v1/")
				|| "/api/v1/system/compatibility".equals(path)
				|| "/api/v1/push/config".equals(path);
	}

	@Override
	protected void doFilterInternal(
			HttpServletRequest request,
			HttpServletResponse response,
			FilterChain filterChain)
			throws ServletException, IOException {
		int minClient = properties.protocol().minClientVersionCode();
		int minProtocol = properties.protocol().minProtocolVersion();

		response.setHeader(HEADER_MIN_CLIENT_VERSION, Integer.toString(minClient));
		response.setHeader(HEADER_MIN_PROTOCOL_VERSION, Integer.toString(minProtocol));

		Integer clientVersion = parsePositiveHeader(request.getHeader(HEADER_CLIENT_VERSION));
		if (request.getHeader(HEADER_CLIENT_VERSION) != null && clientVersion == null) {
			rejectUpgradeRequired(response, "CLIENT_UPGRADE_REQUIRED",
					"Invalid client version header; please update Deep Sky.", minClient, minProtocol);
			return;
		}
		if (clientVersion != null && clientVersion < minClient) {
			rejectUpgradeRequired(response, "CLIENT_UPGRADE_REQUIRED",
					"App update required (minimum versionCode " + minClient + ").", minClient, minProtocol);
			return;
		}
		if (clientVersion == null && minClient > 1) {
			rejectUpgradeRequired(response, "CLIENT_UPGRADE_REQUIRED",
					"App update required (minimum versionCode " + minClient + ").", minClient, minProtocol);
			return;
		}

		Integer protocolVersion = parsePositiveHeader(request.getHeader(HEADER_PROTOCOL_VERSION));
		if (request.getHeader(HEADER_PROTOCOL_VERSION) != null && protocolVersion == null) {
			rejectUpgradeRequired(response, "PROTOCOL_UPGRADE_REQUIRED",
					"Invalid protocol version header; please update Deep Sky.", minClient, minProtocol);
			return;
		}
		if (protocolVersion != null && protocolVersion < minProtocol) {
			rejectUpgradeRequired(response, "PROTOCOL_UPGRADE_REQUIRED",
					"Protocol update required (minimum protocol " + minProtocol + ").", minClient, minProtocol);
			return;
		}
		if (protocolVersion == null && minProtocol > 1) {
			rejectUpgradeRequired(response, "PROTOCOL_UPGRADE_REQUIRED",
					"Protocol update required (minimum protocol " + minProtocol + ").", minClient, minProtocol);
			return;
		}

		filterChain.doFilter(request, response);
	}

	private static Integer parsePositiveHeader(String raw) {
		if (raw == null || raw.isBlank()) {
			return null;
		}
		try {
			int value = Integer.parseInt(raw.trim());
			return value >= 1 ? value : null;
		} catch (NumberFormatException ex) {
			return null;
		}
	}

	private static void rejectUpgradeRequired(
			HttpServletResponse response,
			String code,
			String message,
			int minClient,
			int minProtocol) throws IOException {
		response.setStatus(HTTP_UPGRADE_REQUIRED);
		response.setContentType(MediaType.APPLICATION_JSON_VALUE);
		response.setCharacterEncoding(StandardCharsets.UTF_8.name());
		String safeMsg = message.replace("\"", "'");
		response.getWriter().write(
				"{\"code\":\"" + code + "\",\"message\":\"" + safeMsg
						+ "\",\"minClientVersionCode\":" + minClient
						+ ",\"minProtocolVersion\":" + minProtocol
						+ ",\"timestamp\":\"" + Instant.now() + "\"}");
	}
}
