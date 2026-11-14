package com.vectevo.deep_sky_server.push;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.Signature;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;
import java.util.Objects;
import org.springframework.http.MediaType;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;

/**
 * Mint and cache OAuth2 access tokens for Google FCM HTTP v1 from a runtime service account JSON
 * using JDK RS256 signatures (SP-01, TC-04). No Firebase credentials ever live in source control.
 */
public class ServiceAccountTokenProvider {

	static final String MESSAGING_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
	static final String DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token";
	private static final Base64.Encoder BASE64_URL = Base64.getUrlEncoder().withoutPadding();

	private final String clientEmail;
	private final PrivateKey privateKey;
	private final String tokenUri;
	private final RestClient restClient;
	private final ObjectMapper objectMapper;
	private final Clock clock;

	private String cachedAccessToken;
	private Instant cachedExpiresAt = Instant.EPOCH;

	public ServiceAccountTokenProvider(
			Path serviceAccountPath,
			RestClient restClient,
			ObjectMapper objectMapper,
			Clock clock) throws IOException {
		this(Files.readString(serviceAccountPath, StandardCharsets.UTF_8), restClient, objectMapper, clock);
	}

	ServiceAccountTokenProvider(
			String serviceAccountJson,
			RestClient restClient,
			ObjectMapper objectMapper,
			Clock clock) {
		this.restClient = Objects.requireNonNull(restClient, "restClient");
		this.objectMapper = Objects.requireNonNull(objectMapper, "objectMapper");
		this.clock = Objects.requireNonNull(clock, "clock");
		try {
			JsonNode root = objectMapper.readTree(serviceAccountJson);
			this.clientEmail = requireText(root, "client_email");
			String pem = requireText(root, "private_key");
			this.tokenUri = root.hasNonNull("token_uri") && !root.get("token_uri").asText().isBlank()
					? root.get("token_uri").asText()
					: DEFAULT_TOKEN_URI;
			this.privateKey = parsePkcs8PrivateKey(pem);
		} catch (Exception ex) {
			throw new IllegalArgumentException("Invalid Firebase service account JSON", ex);
		}
	}

	public synchronized String getAccessToken() {
		Instant now = clock.instant();
		if (cachedAccessToken != null && now.isBefore(cachedExpiresAt.minusSeconds(60))) {
			return cachedAccessToken;
		}
		String assertion = createJwtAssertion(now);
		MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
		form.add("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer");
		form.add("assertion", assertion);

		String responseBody = restClient.post()
				.uri(tokenUri)
				.contentType(MediaType.APPLICATION_FORM_URLENCODED)
				.body(form)
				.retrieve()
				.body(String.class);
		try {
			JsonNode json = objectMapper.readTree(responseBody);
			String accessToken = requireText(json, "access_token");
			long expiresIn = json.has("expires_in") ? json.get("expires_in").asLong(3600L) : 3600L;
			this.cachedAccessToken = accessToken;
			this.cachedExpiresAt = now.plusSeconds(Math.max(expiresIn, 120L));
			return accessToken;
		} catch (Exception ex) {
			throw new IllegalStateException("Failed to parse OAuth2 token response", ex);
		}
	}

	String createJwtAssertion(Instant issuedAt) {
		try {
			String headerJson = objectMapper.writeValueAsString(Map.of(
					"alg", "RS256",
					"typ", "JWT"));
			String claimsJson = objectMapper.writeValueAsString(Map.of(
					"iss", clientEmail,
					"scope", MESSAGING_SCOPE,
					"aud", tokenUri,
					"iat", issuedAt.getEpochSecond(),
					"exp", issuedAt.plusSeconds(3600).getEpochSecond()));
			String signingInput = BASE64_URL.encodeToString(headerJson.getBytes(StandardCharsets.UTF_8))
					+ "."
					+ BASE64_URL.encodeToString(claimsJson.getBytes(StandardCharsets.UTF_8));

			Signature signature = Signature.getInstance("SHA256withRSA");
			signature.initSign(privateKey);
			signature.update(signingInput.getBytes(StandardCharsets.US_ASCII));
			String encodedSig = BASE64_URL.encodeToString(signature.sign());
			return signingInput + "." + encodedSig;
		} catch (Exception ex) {
			throw new IllegalStateException("Failed to sign OAuth2 JWT assertion", ex);
		}
	}

	private static String requireText(JsonNode node, String field) {
		JsonNode child = node.get(field);
		if (child == null || child.asText().isBlank()) {
			throw new IllegalArgumentException("Missing required field: " + field);
		}
		return child.asText();
	}

	private static PrivateKey parsePkcs8PrivateKey(String pem) throws Exception {
		StringBuilder base64Body = new StringBuilder();
		for (String line : pem.split("\\R")) {
			String trimmed = line.trim();
			if (!trimmed.isEmpty() && !trimmed.startsWith("-----")) {
				base64Body.append(trimmed);
			}
		}
		byte[] der = Base64.getDecoder().decode(base64Body.toString());
		return KeyFactory.getInstance("RSA").generatePrivate(new PKCS8EncodedKeySpec(der));
	}
}
