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
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
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
				inviteToken,
				"Pixel B",
				rawEd25519B64(devBAuthKp),
				b64(devBKemPub)));
		MvcResult acceptRes = mockMvc.perform(post("/api/v1/pairing/invites/accept")
						.contentType(MediaType.APPLICATION_JSON)
						.content(acceptBody))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.coupleId").value(coupleId))
				.andReturn();
		JsonNode acceptJson = objectMapper.readTree(acceptRes.getResponse().getContentAsString());
		String devBId = acceptJson.get("deviceId").asText();

		// Re-accepting same invite must be rejected
		mockMvc.perform(post("/api/v1/pairing/invites/accept")
						.contentType(MediaType.APPLICATION_JSON)
						.content(acceptBody))
				.andExpect(status().isConflict());

		// 2b. Unapproved Device B is restricted before key delivery (CA-03)
		String unapprovedEnvBody = objectMapper.writeValueAsString(
				new UploadEnvBody(UUID.randomUUID().toString(), "EVENT", 1, b64(new byte[24]), b64(new byte[32])));
		String unapprovedDeliveryBody = objectMapper.writeValueAsString(
				new KeyDeliveryBody(devAId, b64(new byte[24]), b64(new byte[32])));
		mockMvc.perform(signed(post("/api/v1/pairing/enrollment-invites"), devBId, devBAuthKp, ""))
				.andExpect(status().isForbidden());
		mockMvc.perform(signed(
						post("/api/v1/pairing/key-deliveries")
								.contentType(MediaType.APPLICATION_JSON)
								.content(unapprovedDeliveryBody),
						devBId, devBAuthKp, unapprovedDeliveryBody))
				.andExpect(status().isForbidden());
		mockMvc.perform(signed(get("/api/v1/pairing/devices"), devBId, devBAuthKp, ""))
				.andExpect(status().isForbidden());
		mockMvc.perform(signed(post("/api/v1/pairing/devices/" + devAId + "/revoke"), devBId, devBAuthKp, ""))
				.andExpect(status().isForbidden());
		mockMvc.perform(signed(post("/api/v1/pairing/unpair"), devBId, devBAuthKp, ""))
				.andExpect(status().isForbidden());
		mockMvc.perform(signed(get("/api/v1/pairing/visibility"), devBId, devBAuthKp, ""))
				.andExpect(status().isForbidden());
		mockMvc.perform(signed(
						post("/api/v1/sync/envelopes")
								.contentType(MediaType.APPLICATION_JSON)
								.content(unapprovedEnvBody),
						devBId, devBAuthKp, unapprovedEnvBody))
				.andExpect(status().isForbidden());
		mockMvc.perform(signed(get("/api/v1/sync/envelopes?afterSeq=0"), devBId, devBAuthKp, ""))
				.andExpect(status().isForbidden());
		mockMvc.perform(signed(get("/api/v1/sync/visibility"), devBId, devBAuthKp, ""))
				.andExpect(status().isForbidden());
		mockMvc.perform(signed(
						post("/api/v1/push/register")
								.contentType(MediaType.APPLICATION_JSON)
								.content("{\"fcmToken\":\"tok\",\"platform\":\"android\"}"),
						devBId, devBAuthKp, "{\"fcmToken\":\"tok\",\"platform\":\"android\"}"))
				.andExpect(status().isForbidden());
		mockMvc.perform(signed(post("/api/v1/push/wakeup"), devBId, devBAuthKp, ""))
				.andExpect(status().isForbidden());
		// Allowed unapproved endpoints: key-deliveries/me (404 until uploaded), devices/me, invites/status
		mockMvc.perform(signed(get("/api/v1/pairing/key-deliveries/me"), devBId, devBAuthKp, ""))
				.andExpect(status().isNotFound());
		String statusReqBody = objectMapper.writeValueAsString(new InviteStatusBody(inviteToken));
		mockMvc.perform(signed(
						post("/api/v1/pairing/invites/status")
								.contentType(MediaType.APPLICATION_JSON)
								.content(statusReqBody),
						devBId, devBAuthKp, statusReqBody))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.accepted").value(true));

		// 3. Device A checks invite status & uploads wrapped recovery key delivery (approving Device B)
		mockMvc.perform(signed(
						post("/api/v1/pairing/invites/status")
								.contentType(MediaType.APPLICATION_JSON)
								.content(statusReqBody),
						devAId, devAAuthKp, statusReqBody))
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
				.andExpect(jsonPath("$.items[0].envelopeId").value(envId))
				.andExpect(jsonPath("$.hasMore").value(false));
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
				.andExpect(jsonPath("$.items[0].envelopeId").value(envId));

		// Reusing recovery challenge fails
		mockMvc.perform(post("/api/v1/recovery/complete")
						.contentType(MediaType.APPLICATION_JSON)
						.content(completeRecoveryBody))
				.andExpect(status().isConflict());

		// 7. Device revocation with atomic CA-02 epoch rotation (SP02-06, ADR-0012):
		// Device A revokes Device B, rotates epoch to 2 and delivers rotated bundle to surviving Device R
		KeyPair rotatedRecKp = generateEd25519();
		byte[] rotDeliveryCipher = new byte[48];
		Arrays.fill(rotDeliveryCipher, (byte) 0x77);
		String revokeWithRotationBody = objectMapper.writeValueAsString(new EpochRotationBody(
				2,
				rawEd25519B64(rotatedRecKp),
				b64(wrapNonce),
				b64(rotDeliveryCipher),
				List.of(new EpochRotationDeliveryBody(devRId, b64(wrapNonce), b64(rotDeliveryCipher)))));
		mockMvc.perform(signed(
						post("/api/v1/pairing/devices/" + devBId + "/revoke")
								.contentType(MediaType.APPLICATION_JSON)
								.content(revokeWithRotationBody),
						devAId,
						devAAuthKp,
						revokeWithRotationBody))
				.andExpect(status().isNoContent());

		mockMvc.perform(signed(get("/api/v1/sync/envelopes?afterSeq=0"), devBId, devBAuthKp, ""))
				.andExpect(status().isUnauthorized());

		// Surviving Device R sees epoch 2, fetches pending EPOCH_ROTATION delivery, and stale epoch-1 uploads get 409
		mockMvc.perform(signed(get("/api/v1/pairing/epoch-rotations/me"), devRId, devRAuthKp, ""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.currentKeyEpoch").value(2))
				.andExpect(jsonPath("$.pendingDelivery.keyEpoch").value(2));
		String staleEnvBody = objectMapper.writeValueAsString(
				new UploadEnvBody(UUID.randomUUID().toString(), "EVENT", 1, b64(envNonce), b64(envCipher)));
		mockMvc.perform(signed(
						post("/api/v1/sync/envelopes")
								.contentType(MediaType.APPLICATION_JSON)
								.content(staleEnvBody),
						devRId, devRAuthKp, staleEnvBody))
				.andExpect(status().isConflict())
				.andExpect(jsonPath("$.code").value("STALE_KEY_EPOCH"));

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
				.andExpect(jsonPath("$.items[0].envelopeId").value(envId));

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
		String rotatedChallengeReq = objectMapper.writeValueAsString(
				new ChallengeBody(rawEd25519B64(rotatedRecKp)));
		mockMvc.perform(post("/api/v1/recovery/challenges")
						.contentType(MediaType.APPLICATION_JSON)
						.content(rotatedChallengeReq))
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
				.andExpect(jsonPath("$.items").isEmpty());

		MvcResult devBDevices = mockMvc.perform(signed(get("/api/v1/pairing/devices"), devBId, devBKp, ""))
				.andExpect(status().isOk())
				.andReturn();
		assertThat(devBDevices.getResponse().getContentAsString()).doesNotContain(devAId);

		String crossStatusBody = objectMapper.writeValueAsString(new InviteStatusBody(inviteAToken));
		mockMvc.perform(signed(
						post("/api/v1/pairing/invites/status")
								.contentType(MediaType.APPLICATION_JSON)
								.content(crossStatusBody),
						devBId, devBKp, crossStatusBody))
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

		// 5. Public recovery rate-limit returns 429 after 10 calls from the same IP (ignores forged X-Forwarded-For)
		String challengePayload = objectMapper.writeValueAsString(new ChallengeBody(rawEd25519B64(recAKp)));
		for (int i = 0; i < 10; i++) {
			mockMvc.perform(post("/api/v1/recovery/challenges")
							.with(r -> {
								r.setRemoteAddr("203.0.113.77");
								return r;
							})
							.header("X-Forwarded-For", "192.0.2." + (10 + i))
							.contentType(MediaType.APPLICATION_JSON)
							.content(challengePayload))
					.andExpect(status().isOk());
		}
		mockMvc.perform(post("/api/v1/recovery/challenges")
						.with(r -> {
							r.setRemoteAddr("203.0.113.77");
							return r;
						})
						.header("X-Forwarded-For", "192.0.2.99")
						.contentType(MediaType.APPLICATION_JSON)
						.content(challengePayload))
				.andExpect(status().isTooManyRequests())
				.andExpect(jsonPath("$.code").value("RATE_LIMITED"));

		// 6. Invite redemption anti-enumeration, stricter redeem rate-limit, expired invite cleanup,
		// and stale unapproved enrollment cleanup (S1-SRV-01, S1-SRV-02)
		MvcResult extraEnroll = mockMvc.perform(signed(
						post("/api/v1/pairing/enrollment-invites"), devAId, devAKp, ""))
				.andExpect(status().isCreated())
				.andReturn();
		String extraEnrollToken = objectMapper.readTree(extraEnroll.getResponse().getContentAsString())
				.get("inviteToken").asText();
		KeyPair staleDevKp = generateEd25519();
		String staleAcceptBody = objectMapper.writeValueAsString(new AcceptInviteBody(
				extraEnrollToken, "Unapproved Tablet", rawEd25519B64(staleDevKp), b64(randomBytes32())));
		MvcResult staleAcceptRes = mockMvc.perform(post("/api/v1/pairing/invites/accept")
						.with(r -> {
							r.setRemoteAddr("198.51.100.44");
							return r;
						})
						.contentType(MediaType.APPLICATION_JSON)
						.content(staleAcceptBody))
				.andExpect(status().isOk())
				.andReturn();
		String staleDevId = objectMapper.readTree(staleAcceptRes.getResponse().getContentAsString())
				.get("deviceId").asText();

		// Unknown and already-accepted tokens both yield uniform 409 Conflict (no state enumeration),
		// and the 6th redeem attempt from the same IP is rate-limited (5/window).
		for (int i = 0; i < 4; i++) {
			String tok = (i % 2 == 0) ? "unknown-token-" + i : extraEnrollToken;
			String retryBody = objectMapper.writeValueAsString(new AcceptInviteBody(
					tok, "Unapproved Tablet", rawEd25519B64(staleDevKp), b64(randomBytes32())));
			mockMvc.perform(post("/api/v1/pairing/invites/accept")
							.with(r -> {
								r.setRemoteAddr("198.51.100.44");
								return r;
							})
							.contentType(MediaType.APPLICATION_JSON)
							.content(retryBody))
					.andExpect(status().isConflict());
		}
		String extraAttemptBody = objectMapper.writeValueAsString(new AcceptInviteBody(
				"extra-attempt", "Unapproved Tablet", rawEd25519B64(staleDevKp), b64(randomBytes32())));
		mockMvc.perform(post("/api/v1/pairing/invites/accept")
						.with(r -> {
							r.setRemoteAddr("198.51.100.44");
							return r;
						})
						.contentType(MediaType.APPLICATION_JSON)
						.content(extraAttemptBody))
				.andExpect(status().isTooManyRequests())
				.andExpect(jsonPath("$.code").value("RATE_LIMITED"));

		// Stale unapproved device (no key delivery) is automatically revoked by cleanup,
		// while approved Device A remains valid.
		int revokedUnapproved = cleanupService.purgeStaleUnapprovedDevices(Instant.now().plusSeconds(60));
		assertThat(revokedUnapproved).isGreaterThanOrEqualTo(1);
		mockMvc.perform(signed(get("/api/v1/sync/envelopes?afterSeq=0"), staleDevId, staleDevKp, ""))
				.andExpect(status().isUnauthorized());
		mockMvc.perform(signed(get("/api/v1/sync/envelopes?afterSeq=0"), devAId, devAKp, ""))
				.andExpect(status().isOk());

		// Expired invites purge removes past-expiry invites cleanly.
		int purgedInvites = cleanupService.purgeExpiredInvites(Instant.now().plusSeconds(3600));
		assertThat(purgedInvites).isGreaterThanOrEqualTo(1);

		// Never-paired orphan couple cleanup (CA-17):
		// Create an orphan couple, purge its expired invite, then verify orphan cleanup removes only it
		// while leaving Couple A (which has envelopes) intact.
		KeyPair orphanRecKp = generateEd25519();
		KeyPair orphanDevKp = generateEd25519();
		MvcResult orphanRes = mockMvc.perform(post("/api/v1/pairing/invites")
						.contentType(MediaType.APPLICATION_JSON)
						.content(objectMapper.writeValueAsString(new CreateInviteBody(
								"Orphan Phone",
								rawEd25519B64(orphanDevKp),
								b64(randomBytes32()),
								rawEd25519B64(orphanRecKp)))))
				.andExpect(status().isCreated())
				.andReturn();
		String orphanDevId = objectMapper.readTree(orphanRes.getResponse().getContentAsString())
				.get("deviceId").asText();
		cleanupService.purgeExpiredInvites(Instant.now().plusSeconds(3600));
		int removedOrphans = cleanupService.purgeOrphanNeverPairedCouples(Instant.now().plusSeconds(86400));
		assertThat(removedOrphans).isGreaterThanOrEqualTo(1);
		mockMvc.perform(signed(get("/api/v1/sync/envelopes?afterSeq=0"), orphanDevId, orphanDevKp, ""))
				.andExpect(status().isUnauthorized());
		mockMvc.perform(signed(get("/api/v1/sync/envelopes?afterSeq=0"), devAId, devAKp, ""))
				.andExpect(status().isOk());
	}

	@Test
	void concurrentInviteAcceptIsAtomicallySingleUse() throws Exception {
		KeyPair recKp = generateEd25519();
		KeyPair devAKp = generateEd25519();
		MvcResult inviteRes = mockMvc.perform(post("/api/v1/pairing/invites")
						.contentType(MediaType.APPLICATION_JSON)
						.content(objectMapper.writeValueAsString(new CreateInviteBody(
								"Creator",
								rawEd25519B64(devAKp),
								b64(randomBytes32()),
								rawEd25519B64(recKp)))))
				.andExpect(status().isCreated())
				.andReturn();
		JsonNode inviteJson = objectMapper.readTree(inviteRes.getResponse().getContentAsString());
		String devAId = inviteJson.get("deviceId").asText();
		String inviteToken = inviteJson.get("inviteToken").asText();

		int threads = 2;
		CountDownLatch ready = new CountDownLatch(threads);
		CountDownLatch go = new CountDownLatch(1);
		ExecutorService pool = Executors.newFixedThreadPool(threads);
		List<Future<Integer>> futures = new ArrayList<>();
		for (int i = 0; i < threads; i++) {
			final int idx = i;
			futures.add(pool.submit(() -> {
				KeyPair kp = generateEd25519();
				String body = objectMapper.writeValueAsString(new AcceptInviteBody(
						inviteToken,
						"Racer-" + idx,
						rawEd25519B64(kp),
						b64(randomBytes32())));
				ready.countDown();
				go.await();
				return mockMvc.perform(post("/api/v1/pairing/invites/accept")
								.with(r -> {
									r.setRemoteAddr("198.51.100." + (10 + idx));
									return r;
								})
								.contentType(MediaType.APPLICATION_JSON)
								.content(body))
						.andReturn()
						.getResponse()
						.getStatus();
			}));
		}
		ready.await();
		go.countDown();
		List<Integer> statuses = new ArrayList<>();
		for (Future<Integer> future : futures) {
			statuses.add(future.get());
		}
		pool.shutdown();

		assertThat(statuses).containsExactlyInAnyOrder(200, 409);

		MvcResult devListRes = mockMvc.perform(signed(get("/api/v1/pairing/devices"), devAId, devAKp, ""))
				.andExpect(status().isOk())
				.andReturn();
		JsonNode devices = objectMapper.readTree(devListRes.getResponse().getContentAsString());
		assertThat(devices.size()).isEqualTo(2);
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
			String inviteToken,
			String deviceLabel,
			String deviceAuthPublicKeyB64,
			String deviceKemPublicKeyB64) {}

	private record InviteStatusBody(String inviteToken) {}

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

	private record EpochRotationDeliveryBody(String toDeviceId, String nonceB64, String ciphertextB64) {}

	private record EpochRotationBody(
			int targetEpoch,
			String newRecoveryAuthPublicKeyB64,
			String recoveryKeyringNonceB64,
			String recoveryKeyringCiphertextB64,
			List<EpochRotationDeliveryBody> deliveries) {}
}
