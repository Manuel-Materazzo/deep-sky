package com.vectevo.deep_sky_server.config;

import com.vectevo.deep_sky_server.pairing.DeviceAuthLookup;
import jakarta.servlet.http.HttpServletResponse;
import java.time.Instant;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

/**
 * Stateless Ed25519 device-authenticated security configuration (`SRV-01`, `AD-02`, `SP-02`).
 */
@Configuration
public class SecurityConfig {

	@Bean
	SecurityFilterChain securityFilterChain(
			HttpSecurity http,
			DeviceAuthLookup deviceAuthLookup,
			DeepSkyProperties deepSkyProperties,
			PublicEndpointRateLimiter rateLimiter) throws Exception {
		DeviceAuthFilter deviceAuthFilter = new DeviceAuthFilter(deviceAuthLookup);
		ClientCompatibilityFilter compatibilityFilter = new ClientCompatibilityFilter(deepSkyProperties);
		PublicEndpointRateLimitFilter rateLimitFilter = new PublicEndpointRateLimitFilter(rateLimiter);
		RequestBodySizeLimitFilter bodySizeLimitFilter = new RequestBodySizeLimitFilter();
		return http
				.csrf(AbstractHttpConfigurer::disable)
				.sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
				.authorizeHttpRequests(auth -> auth
						.requestMatchers("/actuator/health", "/actuator/health/**").permitAll()
						.requestMatchers("/actuator/info").permitAll()
						.requestMatchers(HttpMethod.GET, PublicRoutes.PUBLIC_GET_PATTERNS)
						.permitAll()
						.requestMatchers(HttpMethod.POST, PublicRoutes.PUBLIC_POST_PATTERNS)
						.permitAll()
						.requestMatchers(HttpMethod.GET, "/api/v1/pairing/key-deliveries/me")
						.hasRole("DEVICE")
						.requestMatchers(HttpMethod.PATCH, "/api/v1/pairing/devices/me")
						.hasRole("DEVICE")
						.requestMatchers(HttpMethod.POST, "/api/v1/pairing/invites/status")
						.hasRole("DEVICE")
						.anyRequest().hasRole("APPROVED_DEVICE"))
				.exceptionHandling(ex -> ex.accessDeniedHandler((request, response, accessDeniedException) -> {
					response.setStatus(HttpServletResponse.SC_FORBIDDEN);
					response.setContentType(MediaType.APPLICATION_JSON_VALUE);
					response.getWriter().write(
							"{\"code\":\"FORBIDDEN\",\"message\":\"Device approval required\",\"timestamp\":\""
									+ Instant.now() + "\"}");
				}))
				.addFilterBefore(deviceAuthFilter, UsernamePasswordAuthenticationFilter.class)
				.addFilterBefore(compatibilityFilter, DeviceAuthFilter.class)
				.addFilterBefore(rateLimitFilter, ClientCompatibilityFilter.class)
				.addFilterBefore(bodySizeLimitFilter, PublicEndpointRateLimitFilter.class)
				.build();
	}
}
