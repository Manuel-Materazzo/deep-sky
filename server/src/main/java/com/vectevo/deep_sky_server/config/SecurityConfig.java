package com.vectevo.deep_sky_server.config;

import com.vectevo.deep_sky_server.pairing.DeviceAuthLookup;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
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
	SecurityFilterChain securityFilterChain(HttpSecurity http, DeviceAuthLookup deviceAuthLookup) throws Exception {
		return http
				.csrf(AbstractHttpConfigurer::disable)
				.sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
				.authorizeHttpRequests(auth -> auth
						.requestMatchers("/actuator/health", "/actuator/health/**").permitAll()
						.requestMatchers("/actuator/info").permitAll()
						.requestMatchers(HttpMethod.POST, "/api/v1/pairing/invites").permitAll()
						.requestMatchers(HttpMethod.POST, "/api/v1/pairing/invites/*/accept").permitAll()
						.requestMatchers(HttpMethod.POST, "/api/v1/recovery/challenges", "/api/v1/recovery/complete")
						.permitAll()
						.anyRequest().authenticated())
				.addFilterBefore(new DeviceAuthFilter(deviceAuthLookup), UsernamePasswordAuthenticationFilter.class)
				.build();
	}
}
