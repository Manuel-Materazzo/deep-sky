package com.vectevo.deep_sky_server.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;

/**
 * Default deny-by-default security baseline for the Deep Sky server (SRV-01, AD-02).
 * Only Actuator health/info probes are exposed unauthenticated in M0.
 */
@Configuration
public class SecurityConfig {

	@Bean
	SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
		return http
				.csrf(AbstractHttpConfigurer::disable)
				.sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
				.authorizeHttpRequests(auth -> auth
						.requestMatchers("/actuator/health", "/actuator/health/**").permitAll()
						.requestMatchers("/actuator/info").permitAll()
						// Standalone SP-01 endpoints for runtime push config and two-device field verification.
						// When promoted with SP-02, token registration/wakeup bind to Ed25519 DeviceAuthFilter.
						.requestMatchers("/api/v1/push/**").permitAll()
						.anyRequest().authenticated())
				.build();
	}
}
