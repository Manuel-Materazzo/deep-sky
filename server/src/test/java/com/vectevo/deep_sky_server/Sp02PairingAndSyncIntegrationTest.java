package com.vectevo.deep_sky_server;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.vectevo.deep_sky_server.config.PublicEndpointRateLimiter;
import com.vectevo.deep_sky_server.pairing.DeviceAuthLookup;
import com.vectevo.deep_sky_server.pairing.PairingCleanupService;
import com.vectevo.deep_sky_server.shared.Ed25519SignatureVerifier;
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.Signature;
import java.time.Instant;
import java.util.Arrays;
import java.util.Base64;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
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
 * recovery without second phone, enrollment, device revocation,
 * couple isolation (`AD-05`), min-version enforcement (`F-19`),
 * rate-limiting (`G5-03`), and nonce cleanup (`G5-04`).
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

	@Autowired
	private PublicEndpointRateLimiter rateLimiter;

	@Autowired
	private DeviceAuthLookup deviceAuthLookup;

	@Autowired
	private PairingCleanupService cleanupService;

	@BeforeEach
	void resetRateLimiter() {
		rateLimiter.reset();
	}

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

		// 4b. Device B updates its own visible name (`S1-D07-2`)
		String renameBody = objectMapper.writeValueAsString(new UpdateDeviceLabelBody("Luna"));
		mockMvc.perform(signed(
						patch("/api/v1/pairing/devices/me")
								.contentType(MediaType.APPLICATION_JSON)
								.content(renameBody),
						devBId,
						devBAuthKp,
						renameBody))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.deviceId").value(devBId))
				.andExpect(jsonPath("$.label").value("Luna"));

		mockMvc.perform(signed(get("/api/v1/pairing/devices"), devAId, devAAuthKp, ""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$[1].label").value("Luna"));

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

		// 8. Self-revocation only revokes the calling device while keeping the couple & other devices active
		mockMvc.perform(signed(
						post("/api/v1/pairing/devices/" + devRId + "/revoke"),
						devRId,
						devRAuthKp,
						""))
				.andExpect(status().isNoContent());

		mockMvc.perform(signed(get("/api/v1/sync/envelopes?afterSeq=0"), devRId, devRAuthKp, ""))
				.andExpect(status().isUnauthorized());
		mockMvc.perform(signed(get("/api/v1/sync/envelopes?afterSeq=0"), devAId, devAAuthKp, ""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$[0].envelopeId").value(envId));

		// 9. Server visibility audit (SP02-07)
		MvcResult pairAudit = mockMvc.perform(signed(get("/api/v1/pairing/visibility"), devAId, devAAuthKp, ""))
				.andExpect(status().isOk())
				.andReturn();
		MvcResult syncAudit = mockMvc.perform(signed(get("/api/v1/sync/visibility"), devAId, devAAuthKp, ""))
				.andExpect(status().isOk())
				.andReturn();
		assertThat(pairAudit.getResponse().getContentAsString()).contains(coupleId);
		assertThat(syncAudit.getResponse().getContentAsString()).contains(envId);
		assertThat(syncAudit.getResponse().getContentAsString()).doesNotContain("time_capsule");

		// 10. Unilateral couple unpair (S-03) revokes all remaining devices and blocks recovery
		mockMvc.perform(signed(post("/api/v1/pairing/unpair"), devAId, devAAuthKp, ""))
				.andExpect(status().isNoContent());
		mockMvc.perform(signed(get("/api/v1/sync/envelopes?afterSeq=0"), devAId, devAAuthKp, ""))
				.andExpect(status().isUnauthorized());
		mockMvc.perform(post("/api/v1/recovery/challenges")
						.contentType(MediaType.APPLICATION_JSON)
						.content(challengeReq))
				.andExpect(status().isConflict());
	}

	@Test
	void enforcesCoupleIsolationCompatibilityPolicyRateLimitingAndNonceCleanup() throws Exception {
		// 1. Create Couple A with an encrypted envelope
		KeyPair recAKp = generateEd25519();
		KeyPair devAKp = generateEd25519();
		MvcResult inviteARes = mockMvc.perform(post("/api/v1/pairing/invites")
						.contentType(MediaType.APPLICATION_JSON)
						.content(objectMapper.writeValueAsString(new CreateInviteBody(
								"Couple A Phone",
								rawEd25519B64(devAKp),
								b64(randomBytes32()),
								rawEd25519B64(recAKp)))))
				.andExpect(status().isCreated())
				.andReturn();
		JsonNode inviteAJson = objectMapper.readTree(inviteARes.getResponse().getContentAsString());
		String devAId = inviteAJson.get("deviceId").asText();
		String inviteAToken = inviteAJson.get("inviteToken").asText();

		String envAId = UUID.randomUUID().toString();
		byte[] nonceBytes = new byte[24];
		byte[] cipherBytes = new byte[40];
		Arrays.fill(nonceBytes, (byte) 0x55);
		Arrays.fill(cipherBytes, (byte) 0x66);
		String envBody = objectMapper.writeValueAsString(
				new UploadEnvBody(envAId, "EVENT", 1, b64(nonceBytes), b64(cipherBytes)));
		mockMvc.perform(signed(
						post("/api/v1/sync/envelopes").contentType(MediaType.APPLICATION_JSON).content(envBody),
						devAId, devAKp, envBody))
				.andExpect(status().isCreated());

		// 2. Create Couple B
		KeyPair recBKp = generateEd25519();
		KeyPair devBKp = generateEd25519();
		MvcResult inviteBRes = mockMvc.perform(post("/api/v1/pairing/invites")
						.contentType(MediaType.APPLICATION_JSON)
						.content(objectMapper.writeValueAsString(new CreateInviteBody(
								"Couple B Phone",
								rawEd25519B64(devBKp),
								b64(randomBytes32()),
								rawEd25519B64(recBKp)))))
				.andExpect(status().isCreated())
				.andReturn();
		String devBId = objectMapper.readTree(inviteBRes.getResponse().getContentAsString())
				.get("deviceId").asText();

		// Couple B cannot see Couple A's envelopes, devices, invite status, revoke Couple A, or deliver keys to Couple A
		mockMvc.perform(signed(get("/api/v1/sync/envelopes?afterSeq=0"), devBId, devBKp, ""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$").isEmpty());

		MvcResult devBDevices = mockMvc.perform(signed(get("/api/v1/pairing/devices"), devBId, devBKp, ""))
				.andExpect(status().isOk())
				.andReturn();
		assertThat(devBDevices.getResponse().getContentAsString()).doesNotContain(devAId);

		mockMvc.perform(signed(get("/api/v1/pairing/invites/" + inviteAToken + "/status"), devBId, devBKp, ""))
				.andExpect(status().isNotFound());

		mockMvc.perform(signed(post("/api/v1/pairing/devices/" + devAId + "/revoke"), devBId, devBKp, ""))
				.andExpect(status().isNotFound());

		String crossDelivery = objectMapper.writeValueAsString(
				new KeyDeliveryBody(devAId, b64(nonceBytes), b64(cipherBytes)));
		mockMvc.perform(signed(
						post("/api/v1/pairing/key-deliveries")
								.contentType(MediaType.APPLICATION_JSON)
								.content(crossDelivery),
						devBId, devBKp, crossDelivery))
				.andExpect(status().isBadRequest());

		// 3. Compatibility policy & 426 Upgrade Required enforcement (F-19)
		mockMvc.perform(get("/api/v1/system/compatibility"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.minClientVersionCode").value(1))
				.andExpect(jsonPath("$.minProtocolVersion").value(1));

		mockMvc.perform(signed(get("/api/v1/sync/envelopes?afterSeq=0"), devAId, devAKp, "")
						.header("X-Client-Version-Code", "0"))
				.andExpect(status().is(426))
				.andExpect(jsonPath("$.code").value("CLIENT_UPGRADE_REQUIRED"));

		mockMvc.perform(signed(get("/api/v1/sync/envelopes?afterSeq=0"), devAId, devAKp, "")
						.header("X-Protocol-Version", "0"))
				.andExpect(status().is(426))
				.andExpect(jsonPath("$.code").value("PROTOCOL_UPGRADE_REQUIRED"));

		// 4. Periodic nonce cleanup deletes expired nonces while keeping active ones
		UUID syntheticDev = UUID.fromString(devAId);
		assertThat(deviceAuthLookup.consumeNonceIfUnused(
				syntheticDev, "expired-nonce-1234567890", Instant.now().minusSeconds(30))).isTrue();
		int purged = cleanupService.purgeExpiredNonces(Instant.now());
		assertThat(purged).isGreaterThanOrEqualTo(1);

		// 5. Public recovery rate-limit returns 429 after 10 calls from the same IP
		String challengePayload = objectMapper.writeValueAsString(new ChallengeBody(rawEd25519B64(recAKp)));
		for (int i = 0; i < 10; i++) {
			mockMvc.perform(post("/api/v1/recovery/challenges")
							.header("X-Forwarded-For", "203.0.113.77")
							.contentType(MediaType.APPLICATION_JSON)
							.content(challengePayload))
					.andExpect(status().isOk());
		}
		mockMvc.perform(post("/api/v1/recovery/challenges")
						.header("X-Forwarded-For", "203.0.113.77")
						.contentType(MediaType.APPLICATION_JSON)
						.content(challengePayload))
				.andExpect(status().isTooManyRequests())
				.andExpect(jsonPath("$.code").value("RATE_LIMITED"));
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

	private record UpdateDeviceLabelBody(String deviceLabel) {}

	private record CompleteRecoveryBody(
			String challengeId,
			String deviceLabel,
			String newDeviceAuthPublicKeyB64,
			String newDeviceKemPublicKeyB64,
			String recoverySignatureB64) {}
}
