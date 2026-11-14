package com.vectevo.deep_sky_server;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.vectevo.deep_sky_server.shared.Ed25519SignatureVerifier;
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.Signature;
import java.time.Instant;
import java.util.Arrays;
import java.util.Base64;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * End-to-end backend verification for SP-02 against real PostgreSQL:
 * pairing, key delivery, opaque envelope sync, replay protection,
 * recovery without second phone, enrollment, device revocation, and visibility audit.
 */
@SpringBootTest
@Testcontainers
@AutoConfigureMockMvc
@ActiveProfiles("test")
class Sp02PairingAndSyncIntegrationTest {

	@Container
	@ServiceConnection
	static final PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:17-alpine");

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private ObjectMapper objectMapper;

	@Test
	void fullPairingRecoveryEnrollmentRevocationAndVisibilityFlow() throws Exception {
		KeyPair recoveryAuthKp = generateEd25519();
		KeyPair devAAuthKp = generateEd25519();
		KeyPair devBAuthKp = generateEd25519();
		byte[] devAKemPub = randomBytes32();
		byte[] devBKemPub = randomBytes32();

		// 1. Device A creates pairing invite
		String createInviteBody = objectMapper.writeValueAsString(new CreateInviteBody(
				"Pixel A",
				rawEd25519B64(devAAuthKp),
				b64(devAKemPub),
				rawEd25519B64(recoveryAuthKp)));
		MvcResult inviteRes = mockMvc.perform(post("/api/v1/pairing/invites")
						.contentType(MediaType.APPLICATION_JSON)
						.content(createInviteBody))
				.andExpect(status().isCreated())
				.andReturn();
		JsonNode inviteJson = objectMapper.readTree(inviteRes.getResponse().getContentAsString());
		String coupleId = inviteJson.get("coupleId").asText();
		String devAId = inviteJson.get("deviceId").asText();
		String inviteToken = inviteJson.get("inviteToken").asText();

		// 2. Device B accepts invite
		String acceptBody = objectMapper.writeValueAsString(new AcceptInviteBody(
				"Pixel B",
				rawEd25519B64(devBAuthKp),
				b64(devBKemPub)));
		MvcResult acceptRes = mockMvc.perform(post("/api/v1/pairing/invites/" + inviteToken + "/accept")
						.contentType(MediaType.APPLICATION_JSON)
						.content(acceptBody))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.coupleId").value(coupleId))
				.andReturn();
		JsonNode acceptJson = objectMapper.readTree(acceptRes.getResponse().getContentAsString());
		String devBId = acceptJson.get("deviceId").asText();

		// Re-accepting same invite must be rejected
		mockMvc.perform(post("/api/v1/pairing/invites/" + inviteToken + "/accept")
						.contentType(MediaType.APPLICATION_JSON)
						.content(acceptBody))
				.andExpect(status().isConflict());

		// 3. Device A checks invite status & uploads wrapped recovery key delivery
		mockMvc.perform(signed(get("/api/v1/pairing/invites/" + inviteToken + "/status"), devAId, devAAuthKp, ""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.accepted").value(true))
				.andExpect(jsonPath("$.acceptedDeviceId").value(devBId));

		byte[] wrapNonce = new byte[24];
		byte[] wrapCipher = new byte[48];
		Arrays.fill(wrapNonce, (byte) 0x11);
		Arrays.fill(wrapCipher, (byte) 0x22);
		String deliveryBody = objectMapper.writeValueAsString(new KeyDeliveryBody(
				devBId, b64(wrapNonce), b64(wrapCipher)));
		mockMvc.perform(signed(
						post("/api/v1/pairing/key-deliveries")
								.contentType(MediaType.APPLICATION_JSON)
								.content(deliveryBody),
						devAId,
						devAAuthKp,
						deliveryBody))
				.andExpect(status().isCreated());

		// 4. Device B fetches key delivery
		mockMvc.perform(signed(get("/api/v1/pairing/key-deliveries/me"), devBId, devBAuthKp, ""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.fromDeviceId").value(devAId))
				.andExpect(jsonPath("$.ciphertextB64").value(b64(wrapCipher)));

		// 5. Device A uploads an opaque encrypted envelope (server must not see eventType or unlock dates)
		String envId = UUID.randomUUID().toString();
		byte[] envNonce = new byte[24];
		byte[] envCipher = new byte[64];
		Arrays.fill(envNonce, (byte) 0x33);
		Arrays.fill(envCipher, (byte) 0x44);
		String uploadEnvBody = objectMapper.writeValueAsString(
				new UploadEnvBody(envId, "EVENT", 1, b64(envNonce), b64(envCipher)));
		mockMvc.perform(signed(
						post("/api/v1/sync/envelopes")
								.contentType(MediaType.APPLICATION_JSON)
								.content(uploadEnvBody),
						devAId,
						devAAuthKp,
						uploadEnvBody))
				.andExpect(status().isCreated())
				.andExpect(jsonPath("$.seq").isNumber());

		// Replay protection: reusing the same X-Nonce is rejected
		String replayNonce = "fixed-replay-nonce-123456";
		long ts = Instant.now().getEpochSecond();
		mockMvc.perform(signedWithNonce(get("/api/v1/sync/envelopes?afterSeq=0"), devBId, devBAuthKp, "", ts, replayNonce))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$[0].envelopeId").value(envId));
		mockMvc.perform(signedWithNonce(get("/api/v1/sync/envelopes?afterSeq=0"), devBId, devBAuthKp, "", ts, replayNonce))
				.andExpect(status().isUnauthorized());

		// 6. Zero-second-phone recovery (SP02-05)
		String challengeReq = objectMapper.writeValueAsString(new ChallengeBody(rawEd25519B64(recoveryAuthKp)));
		MvcResult chalRes = mockMvc.perform(post("/api/v1/recovery/challenges")
						.contentType(MediaType.APPLICATION_JSON)
						.content(challengeReq))
				.andExpect(status().isOk())
				.andReturn();
		JsonNode chalJson = objectMapper.readTree(chalRes.getResponse().getContentAsString());
		String challengeId = chalJson.get("challengeId").asText();
		String challengeNonceB64 = chalJson.get("nonceB64").asText();

		KeyPair devRAuthKp = generateEd25519();
		byte[] devRKemPub = randomBytes32();
		String claim = String.join(
				"|",
				"deep-sky:recovery:v1",
				coupleId,
				challengeId,
				challengeNonceB64,
				rawEd25519B64(devRAuthKp),
				b64(devRKemPub));
		String recoverySig = signString(recoveryAuthKp, claim);
		String completeRecoveryBody = objectMapper.writeValueAsString(new CompleteRecoveryBody(
				challengeId,
				"Recovered Pixel",
				rawEd25519B64(devRAuthKp),
				b64(devRKemPub),
				recoverySig));
		MvcResult recRes = mockMvc.perform(post("/api/v1/recovery/complete")
						.contentType(MediaType.APPLICATION_JSON)
						.content(completeRecoveryBody))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.coupleId").value(coupleId))
				.andReturn();
		String devRId = objectMapper.readTree(recRes.getResponse().getContentAsString())
				.get("deviceId").asText();

		// Recovered device fetches historical envelopes
		mockMvc.perform(signed(get("/api/v1/sync/envelopes?afterSeq=0"), devRId, devRAuthKp, ""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$[0].envelopeId").value(envId));

		// Reusing recovery challenge fails
		mockMvc.perform(post("/api/v1/recovery/complete")
						.contentType(MediaType.APPLICATION_JSON)
						.content(completeRecoveryBody))
				.andExpect(status().isConflict());

		// 7. Device revocation (SP02-06): Device A revokes Device B -> Device B gets 401
		mockMvc.perform(signed(
						post("/api/v1/pairing/devices/" + devBId + "/revoke"),
						devAId,
						devAAuthKp,
						""))
				.andExpect(status().isNoContent());

		mockMvc.perform(signed(get("/api/v1/sync/envelopes?afterSeq=0"), devBId, devBAuthKp, ""))
				.andExpect(status().isUnauthorized());

		// 8. Server visibility audit (SP02-07)
		MvcResult pairAudit = mockMvc.perform(signed(get("/api/v1/pairing/visibility"), devAId, devAAuthKp, ""))
				.andExpect(status().isOk())
				.andReturn();
		MvcResult syncAudit = mockMvc.perform(signed(get("/api/v1/sync/visibility"), devAId, devAAuthKp, ""))
				.andExpect(status().isOk())
				.andReturn();
		assertThat(pairAudit.getResponse().getContentAsString()).contains(coupleId);
		assertThat(syncAudit.getResponse().getContentAsString()).contains(envId);
		assertThat(syncAudit.getResponse().getContentAsString()).doesNotContain("time_capsule");
	}

	private MockHttpServletRequestBuilder signed(
			MockHttpServletRequestBuilder builder,
			String deviceId,
			KeyPair authKp,
			String body) throws Exception {
		return signedWithNonce(
				builder,
				deviceId,
				authKp,
				body,
				Instant.now().getEpochSecond(),
				UUID.randomUUID().toString());
	}

	private MockHttpServletRequestBuilder signedWithNonce(
			MockHttpServletRequestBuilder builder,
			String deviceId,
			KeyPair authKp,
			String body,
			long timestamp,
			String nonce) throws Exception {
		var req = builder.buildRequest(new org.springframework.mock.web.MockServletContext());
		String pathWithQuery = req.getRequestURI()
				+ (req.getQueryString() != null ? "?" + req.getQueryString() : "");
		String bodyHash = Ed25519SignatureVerifier.sha256Hex(body.getBytes(StandardCharsets.UTF_8));
		String canonical = String.join(
				"\n",
				req.getMethod().toUpperCase(),
				pathWithQuery,
				Long.toString(timestamp),
				nonce,
				bodyHash);
		String sig = signString(authKp, canonical);
		return builder
				.header("X-Device-Id", deviceId)
				.header("X-Timestamp", Long.toString(timestamp))
				.header("X-Nonce", nonce)
				.header("X-Signature", sig);
	}

	private static KeyPair generateEd25519() throws Exception {
		return KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
	}

	private static String rawEd25519B64(KeyPair kp) {
		byte[] encoded = kp.getPublic().getEncoded();
		byte[] raw = Arrays.copyOfRange(encoded, encoded.length - 32, encoded.length);
		return b64(raw);
	}

	private static String signString(KeyPair kp, String msg) throws Exception {
		Signature sig = Signature.getInstance("Ed25519");
		sig.initSign(kp.getPrivate());
		sig.update(msg.getBytes(StandardCharsets.UTF_8));
		return Base64.getUrlEncoder().encodeToString(sig.sign());
	}

	private static byte[] randomBytes32() {
		byte[] b = new byte[32];
		new java.security.SecureRandom().nextBytes(b);
		return b;
	}

	private static String b64(byte[] bytes) {
		return Base64.getUrlEncoder().encodeToString(bytes);
	}

	private record CreateInviteBody(
			String deviceLabel,
			String deviceAuthPublicKeyB64,
			String deviceKemPublicKeyB64,
			String recoveryAuthPublicKeyB64) {}

	private record AcceptInviteBody(
			String deviceLabel,
			String deviceAuthPublicKeyB64,
			String deviceKemPublicKeyB64) {}

	private record KeyDeliveryBody(String toDeviceId, String nonceB64, String ciphertextB64) {}

	private record UploadEnvBody(
			String envelopeId,
			String channel,
			int keyEpoch,
			String nonceB64,
			String ciphertextB64) {}

	private record ChallengeBody(String recoveryAuthPublicKeyB64) {}

	private record CompleteRecoveryBody(
			String challengeId,
			String deviceLabel,
			String newDeviceAuthPublicKeyB64,
			String newDeviceKemPublicKeyB64,
			String recoverySignatureB64) {}
}
