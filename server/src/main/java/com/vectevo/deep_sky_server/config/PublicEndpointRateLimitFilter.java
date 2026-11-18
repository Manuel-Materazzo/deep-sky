package com.vectevo.deep_sky_server.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Applies rate limiting on unauthenticated public pairing and recovery endpoints (`PR-M2-02`, `G5-03`).
 */
public class PublicEndpointRateLimitFilter extends OncePerRequestFilter {

	private static final int HTTP_TOO_MANY_REQUESTS = 429;

	private final PublicEndpointRateLimiter rateLimiter;

	public PublicEndpointRateLimitFilter(PublicEndpointRateLimiter rateLimiter) {
		this.rateLimiter = rateLimiter;
	}

	@Override
	protected void doFilterInternal(
			HttpServletRequest request,
			HttpServletResponse response,
			FilterChain filterChain)
			throws ServletException, IOException {
		PublicEndpointRateLimiter.RouteGroup group = classifyRoute(request);
		if (group == null) {
			filterChain.doFilter(request, response);
			return;
		}

		String clientIp = extractClientIp(request);
		PublicEndpointRateLimiter.Decision decision = rateLimiter.tryConsume(clientIp, group);
		if (!decision.allowed()) {
			response.setStatus(HTTP_TOO_MANY_REQUESTS);
			response.setHeader("Retry-After", Long.toString(decision.retryAfterSeconds()));
			response.setContentType(MediaType.APPLICATION_JSON_VALUE);
			response.setCharacterEncoding(StandardCharsets.UTF_8.name());
			response.getWriter().write(
					"{\"code\":\"RATE_LIMITED\",\"message\":\"Too many requests; please wait before retrying.\","
							+ "\"timestamp\":\"" + Instant.now() + "\"}");
			return;
		}

		filterChain.doFilter(request, response);
	}

	private static PublicEndpointRateLimiter.RouteGroup classifyRoute(HttpServletRequest request) {
		if (!HttpMethod.POST.matches(request.getMethod())) {
			return null;
		}
		String path = request.getRequestURI();
		if ("/api/v1/pairing/invites/accept".equals(path)) {
			return PublicEndpointRateLimiter.RouteGroup.INVITE_REDEEM;
		}
		if ("/api/v1/pairing/invites".equals(path)) {
			return PublicEndpointRateLimiter.RouteGroup.INVITES;
		}
		if ("/api/v1/recovery/challenges".equals(path) || "/api/v1/recovery/complete".equals(path)) {
			return PublicEndpointRateLimiter.RouteGroup.RECOVERY;
		}
		return null;
	}

	private static String extractClientIp(HttpServletRequest request) {
		String remoteAddr = request.getRemoteAddr();
		return (remoteAddr == null || remoteAddr.isBlank()) ? "unknown" : remoteAddr.trim();
	}
}
