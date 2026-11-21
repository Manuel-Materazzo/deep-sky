package com.vectevo.deep_sky_server.config;

import com.vectevo.deep_sky_server.pairing.DeviceAuthLookup;
import com.vectevo.deep_sky_server.shared.DevicePrincipal;
import com.vectevo.deep_sky_server.shared.Ed25519SignatureVerifier;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ReadListener;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletInputStream;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Verifies Ed25519 per-device request signatures and anti-replay nonces (`AD-02`, `SP02-03`).
 */
public class DeviceAuthFilter extends OncePerRequestFilter {

	private static final long MAX_CLOCK_SKEW_SECONDS = 300;
	private static final int MAX_BODY_BYTES = 1024 * 1024;
	private static final String UNIFORM_AUTH_FAILURE = "Device unknown, revoked, or invalid signature";

	private final DeviceAuthLookup deviceAuthLookup;

	public DeviceAuthFilter(DeviceAuthLookup deviceAuthLookup) {
		this.deviceAuthLookup = deviceAuthLookup;
	}

	@Override
	protected boolean shouldNotFilter(HttpServletRequest request) {
		String path = request.getRequestURI();
		String method = request.getMethod();
		if (!path.startsWith("/api/v1/")) {
			return true;
		}
		return PublicRoutes.isPublicApiRequest(method, path);
	}

	@Override
	protected void doFilterInternal(
			HttpServletRequest request,
			HttpServletResponse response,
			FilterChain filterChain)
			throws ServletException, IOException {
		String deviceIdHeader = request.getHeader("X-Device-Id");
		String timestampHeader = request.getHeader("X-Timestamp");
		String nonceHeader = request.getHeader("X-Nonce");
		String signatureHeader = request.getHeader("X-Signature");

		if (isBlank(deviceIdHeader) || isBlank(timestampHeader) || isBlank(nonceHeader) || isBlank(signatureHeader)) {
			rejectUnauthorized(response, "AUTH_HEADERS_INVALID", "Missing device authentication headers");
			return;
		}

		final UUID deviceId;
		final long timestamp;
		try {
			deviceId = UUID.fromString(deviceIdHeader.trim());
			timestamp = Long.parseLong(timestampHeader.trim());
		} catch (IllegalArgumentException ex) {
			rejectUnauthorized(response, "AUTH_HEADERS_INVALID", "Malformed X-Device-Id or X-Timestamp");
			return;
		}

		long now = Instant.now().getEpochSecond();
		if (Math.abs(now - timestamp) > MAX_CLOCK_SKEW_SECONDS) {
			rejectUnauthorized(response, "CLOCK_SKEW", "Request timestamp outside allowed window");
			return;
		}

		String nonce = nonceHeader.trim();
		if (nonce.length() < 16 || nonce.length() > 128) {
			rejectUnauthorized(response, "AUTH_HEADERS_INVALID", "Invalid X-Nonce length");
			return;
		}

		final byte[] signatureBytes;
		try {
			signatureBytes = Ed25519SignatureVerifier.decodeBase64Url(signatureHeader, 64, "X-Signature");
		} catch (IllegalArgumentException ex) {
			rejectUnauthorized(response, "DEVICE_AUTH_FAILED", UNIFORM_AUTH_FAILURE);
			return;
		}

		DeviceAuthLookup.ActiveDeviceKey deviceKey = deviceAuthLookup.findActiveDevice(deviceId).orElse(null);
		if (deviceKey == null) {
			rejectUnauthorized(response, "DEVICE_AUTH_FAILED", UNIFORM_AUTH_FAILURE);
			return;
		}

		byte[] bodyBytes = request.getInputStream().readNBytes(MAX_BODY_BYTES + 1);
		if (bodyBytes.length > MAX_BODY_BYTES) {
			response.setStatus(HttpServletResponse.SC_REQUEST_ENTITY_TOO_LARGE);
			return;
		}

		String pathWithQuery = request.getRequestURI()
				+ (request.getQueryString() != null ? "?" + request.getQueryString() : "");
		String bodyHashHex = Ed25519SignatureVerifier.sha256Hex(bodyBytes);
		String canonical = String.join(
				"\n",
				request.getMethod().toUpperCase(),
				pathWithQuery,
				Long.toString(timestamp),
				nonce,
				bodyHashHex);

		if (!Ed25519SignatureVerifier.verify(deviceKey.authPublicKey(), canonical, signatureBytes)) {
			rejectUnauthorized(response, "DEVICE_AUTH_FAILED", UNIFORM_AUTH_FAILURE);
			return;
		}

		Instant expiresAt = Instant.ofEpochSecond(now + MAX_CLOCK_SKEW_SECONDS + 30);
		if (!deviceAuthLookup.consumeNonceIfUnused(deviceId, nonce, expiresAt)) {
			rejectUnauthorized(response, "NONCE_REPLAYED", "Replayed request nonce");
			return;
		}

		List<SimpleGrantedAuthority> authorities = deviceKey.approved()
				? List.of(
						new SimpleGrantedAuthority("ROLE_DEVICE"),
						new SimpleGrantedAuthority("ROLE_APPROVED_DEVICE"))
				: List.of(new SimpleGrantedAuthority("ROLE_DEVICE"));
		DevicePrincipal principal = new DevicePrincipal(
				deviceKey.coupleId(), deviceKey.deviceId(), deviceKey.approved());
		UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
				principal,
				null,
				authorities);
		SecurityContextHolder.getContext().setAuthentication(auth);

		filterChain.doFilter(new CachedBodyHttpServletRequest(request, bodyBytes), response);
	}

	private static boolean isBlank(String s) {
		return s == null || s.isBlank();
	}

	private static void rejectUnauthorized(HttpServletResponse response, String code, String message) throws IOException {
		SecurityContextHolder.clearContext();
		response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
		response.setContentType(MediaType.APPLICATION_JSON_VALUE);
		String escaped = message.replace("\"", "\\\"");
		response.getWriter().write("{\"code\":\"" + code + "\",\"message\":\"" + escaped + "\"}");
	}

	private static final class CachedBodyHttpServletRequest extends HttpServletRequestWrapper {
		private final byte[] body;

		private CachedBodyHttpServletRequest(HttpServletRequest request, byte[] body) {
			super(request);
			this.body = body;
		}

		@Override
		public ServletInputStream getInputStream() {
			ByteArrayInputStream bais = new ByteArrayInputStream(body);
			return new ServletInputStream() {
				@Override
				public boolean isFinished() {
					return bais.available() == 0;
				}

				@Override
				public boolean isReady() {
					return true;
				}

				@Override
				public void setReadListener(ReadListener readListener) {}

				@Override
				public int read() {
					return bais.read();
				}
			};
		}

		@Override
		public BufferedReader getReader() {
			return new BufferedReader(new InputStreamReader(getInputStream(), StandardCharsets.UTF_8));
		}
	}
}
