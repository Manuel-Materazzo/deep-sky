package com.vectevo.deep_sky_server;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.timeout;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.vectevo.deep_sky_server.config.PublicEndpointRateLimiter;
import com.vectevo.deep_sky_server.push.PushProvider;
import com.vectevo.deep_sky_server.push.PushRegistrationRepository;
import com.vectevo.deep_sky_server.push.PushService;
import com.vectevo.deep_sky_server.push.PushTokenUnregisteredException;
import com.vectevo.deep_sky_server.shared.Ed25519SignatureVerifier;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.Signature;
import java.time.Instant;
import java.util.Arrays;
import java.util.Base64;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * SP-01 / PR-M2-03 backend integration tests:
 * runtime Firebase config delivery, DeviceAuthFilter-protected push registration,
 * SyncService partner wakeup (`wakeup.thinking_of_you`), stale token eviction,
 * and token deletion on device revocation.
 */
@SpringBootTest
@Testcontainers
@AutoConfigureMockMvc
@ActiveProfiles("test")
class Sp01PushIntegrationTest {

	@Container
	@ServiceConnection
	static final PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:17-alpine");

	@TempDir
	static Path tempDir;

	@DynamicPropertySource
	static void configureFirebaseProperties(DynamicPropertyRegistry registry) throws Exception {
		KeyPairGenerator kpg = KeyPairGenerator.getInstance("RSA");
		kpg.initialize(2048);
		KeyPair rsa = kpg.generateKeyPair();
		String keyBase64 = Base64.getEncoder().encodeToString(rsa.getPrivate().getEncoded());
		Path saFile = tempDir.resolve("sa-test.json");
		Files.writeString(
				saFile,
				"{\"client_email\":\"test@deepsky-proto.iam.gserviceaccount.com\",\"private_key\":\""
						+ keyBase64
						+ "\"}",
				StandardCharsets.UTF_8);

		registry.add("deepsky.firebase.enabled", () -> "true");
		registry.add("deepsky.firebase.project-id", () -> "deepsky-proto");
		registry.add("deepsky.firebase.api-key", () -> "test-runtime-api-key");
		registry.add("deepsky.firebase.app-id", () -> "1:123456:android:abcdef");
		registry.add("deepsky.firebase.sender-id", () -> "123456");
		registry.add("deepsky.firebase.service-account-file", () -> saFile.toAbsolutePath().toString());
	}

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private ObjectMapper objectMapper;

	@Autowired
	private PushRegistrationRepository registrationRepository;

	@Autowired
	private PublicEndpointRateLimiter rateLimiter;

	@Autowired
	private PushService pushService;

	@MockitoBean
	private PushProvider pushProvider;

	@BeforeEach
	void cleanDb() {
		registrationRepository.deleteAll();
		rateLimiter.reset();
		pushService.resetClientWakeupRateLimit();
	}

	@Test
	void exposesPublicRuntimeConfigWithoutLeakingServiceAccountPath() throws Exception {
		mockMvc.perform(get("/api/v1/push/config"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.enabled").value(true))
				.andExpect(jsonPath("$.projectId").value("deepsky-proto"))
				.andExpect(jsonPath("$.apiKey").value("test-runtime-api-key"))
				.andExpect(jsonPath("$.appId").value("1:123456:android:abcdef"))
				.andExpect(jsonPath("$.senderId").value("123456"))
				.andExpect(jsonPath("$.serviceAccountFile").doesNotExist());
	}

	@Test
	void rejectsUnauthenticatedPushRegistration() throws Exception {
		mockMvc.perform(post("/api/v1/push/register")
						.contentType(MediaType.APPLICATION_JSON)
						.content("{\"fcmToken\":\"unauth-token\",\"platform\":\"android\"}"))
				.andExpect(status().isUnauthorized());
	}

	@Test
	void registersRotatesWakesPartnerOnSyncEvictsUnregisteredAndDeletesOnRevoke() throws Exception {
		PairedCouple couple = createPairedCouple();

		// Register token for device A and B behind DeviceAuthFilter
		String regA = "{\"fcmToken\":\"token-a-initial-123456\",\"platform\":\"android\"}";
		mockMvc.perform(signed(
						post("/api/v1/push/register").contentType(MediaType.APPLICATION_JSON).content(regA),
						couple.devAId(), couple.devAKp(), regA))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.deviceId").value(couple.devAId()))
				.andExpect(jsonPath("$.coupleId").value(couple.coupleId()))
				.andExpect(jsonPath("$.tokenPrefix").value("token-a-"));

		String regB1 = "{\"fcmToken\":\"token-b-v1-secret-1234\",\"platform\":\"android\"}";
		mockMvc.perform(signed(
						post("/api/v1/push/register").contentType(MediaType.APPLICATION_JSON).content(regB1),
						couple.devBId(), couple.devBKp(), regB1))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.tokenPrefix").value("token-b-"));

		// Rotate token on device B
		String regB2 = "{\"fcmToken\":\"token-b-v2-rotated-9876\",\"platform\":\"android\"}";
		mockMvc.perform(signed(
						post("/api/v1/push/register").contentType(MediaType.APPLICATION_JSON).content(regB2),
						couple.devBId(), couple.devBKp(), regB2))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.tokenPrefix").value("token-b-"));

		// Device A uploads an encrypted EVENT envelope -> SyncService wakes partner B (never A)
		doNothing().when(pushProvider).sendWakeup("token-b-v2-rotated-9876", "wakeup.thinking_of_you");
		byte[] nonce = new byte[24];
		byte[] cipher = new byte[48];
		Arrays.fill(nonce, (byte) 0x11);
		Arrays.fill(cipher, (byte) 0x22);
		String envBody = objectMapper.writeValueAsString(new UploadEnvBody(
				UUID.randomUUID().toString(), "EVENT", 1, b64(nonce), b64(cipher)));
		mockMvc.perform(signed(
						post("/api/v1/sync/envelopes").contentType(MediaType.APPLICATION_JSON).content(envBody),
						couple.devAId(), couple.devAKp(), envBody))
				.andExpect(status().isCreated());

		verify(pushProvider, timeout(2000)).sendWakeup("token-b-v2-rotated-9876", "wakeup.thinking_of_you");
		verify(pushProvider, never()).sendWakeup("token-a-initial-123456", "wakeup.thinking_of_you");

		// Reject arbitrary localization keys, intimate text, or wakeup.pairing_request from client endpoint (S-02, CA-09)
		String badWakeup = "{\"localizationKey\":\"raw intimate message text\"}";
		mockMvc.perform(signed(
						post("/api/v1/push/wakeup").contentType(MediaType.APPLICATION_JSON).content(badWakeup),
						couple.devAId(), couple.devAKp(), badWakeup))
				.andExpect(status().isBadRequest());
		String pairingWakeup = "{\"localizationKey\":\"wakeup.pairing_request\"}";
		mockMvc.perform(signed(
						post("/api/v1/push/wakeup").contentType(MediaType.APPLICATION_JSON).content(pairingWakeup),
						couple.devAId(), couple.devAKp(), pairingWakeup))
				.andExpect(status().isBadRequest());

		// When FCM reports UNREGISTERED, stale token is evicted from Postgres
		doThrow(new PushTokenUnregisteredException("token-b-v2-rotated-9876", "gone"))
				.when(pushProvider).sendWakeup("token-b-v2-rotated-9876", "wakeup.generic");
		String genWakeup = "{\"localizationKey\":\"wakeup.generic\"}";
		mockMvc.perform(signed(
						post("/api/v1/push/wakeup").contentType(MediaType.APPLICATION_JSON).content(genWakeup),
						couple.devAId(), couple.devAKp(), genWakeup))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.attempted").value(1))
				.andExpect(jsonPath("$.delivered").value(0))
				.andExpect(jsonPath("$.unregisteredRemoved").value(1));

		assertThat(registrationRepository.findByDeviceId(couple.devBId())).isEmpty();
		mockMvc.perform(signed(get("/api/v1/push/register"), couple.devBId(), couple.devBKp(), ""))
				.andExpect(status().isNotFound());

		// Re-register B, then accept a new enrollment invite -> approver device A receives wakeup.pairing_request
		mockMvc.perform(signed(
						post("/api/v1/push/register").contentType(MediaType.APPLICATION_JSON).content(regB2),
						couple.devBId(), couple.devBKp(), regB2))
				.andExpect(status().isOk());
		assertThat(registrationRepository.findByDeviceId(couple.devBId())).isPresent();

		doNothing().when(pushProvider).sendWakeup("token-a-initial-123456", "wakeup.pairing_request");
		MvcResult enrollRes = mockMvc.perform(signed(
						post("/api/v1/pairing/enrollment-invites"),
						couple.devAId(), couple.devAKp(), ""))
				.andExpect(status().isCreated())
				.andReturn();
		String enrollToken = objectMapper.readTree(enrollRes.getResponse().getContentAsString())
				.get("inviteToken").asText();
		KeyPair devCKp = generateEd25519();
		String acceptEnrollBody = objectMapper.writeValueAsString(new AcceptInviteBody(
				enrollToken, "Tablet C", rawEd25519B64(devCKp), b64(randomBytes32())));
		mockMvc.perform(post("/api/v1/pairing/invites/accept")
						.contentType(MediaType.APPLICATION_JSON)
						.content(acceptEnrollBody))
				.andExpect(status().isOk());
		verify(pushProvider, timeout(2000)).sendWakeup("token-a-initial-123456", "wakeup.pairing_request");

		// Revoke B -> push token is removed cleanly
		mockMvc.perform(signed(
						post("/api/v1/pairing/devices/" + couple.devBId() + "/revoke"),
						couple.devAId(), couple.devAKp(), ""))
				.andExpect(status().isNoContent());
		assertThat(registrationRepository.findByDeviceId(couple.devBId())).isEmpty();

		// Self-unregister endpoint for device A
		mockMvc.perform(signed(delete("/api/v1/push/register"), couple.devAId(), couple.devAKp(), ""))
				.andExpect(status().isNoContent());
		mockMvc.perform(signed(delete("/api/v1/push/register"), couple.devAId(), couple.devAKp(), ""))
				.andExpect(status().isNotFound());
	}

	private PairedCouple createPairedCouple() throws Exception {
		KeyPair recKp = generateEd25519();
		KeyPair devAKp = generateEd25519();
		KeyPair devBKp = generateEd25519();
		String createBody = objectMapper.writeValueAsString(new CreateInviteBody(
				"Pixel A", rawEd25519B64(devAKp), b64(randomBytes32()), rawEd25519B64(recKp)));
		MvcResult inviteRes = mockMvc.perform(post("/api/v1/pairing/invites")
						.contentType(MediaType.APPLICATION_JSON)
						.content(createBody))
				.andExpect(status().isCreated())
				.andReturn();
		JsonNode inviteJson = objectMapper.readTree(inviteRes.getResponse().getContentAsString());
		String coupleId = inviteJson.get("coupleId").asText();
		String devAId = inviteJson.get("deviceId").asText();
		String token = inviteJson.get("inviteToken").asText();

		String acceptBody = objectMapper.writeValueAsString(new AcceptInviteBody(
				token, "Pixel B", rawEd25519B64(devBKp), b64(randomBytes32())));
		MvcResult acceptRes = mockMvc.perform(post("/api/v1/pairing/invites/accept")
						.contentType(MediaType.APPLICATION_JSON)
						.content(acceptBody))
				.andExpect(status().isOk())
				.andReturn();
		String devBId = objectMapper.readTree(acceptRes.getResponse().getContentAsString())
				.get("deviceId").asText();

		// Approve device B via key delivery from device A (CA-03)
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
						devAKp,
						deliveryBody))
				.andExpect(status().isCreated());

		return new PairedCouple(coupleId, devAId, devAKp, devBId, devBKp);
	}

	private MockHttpServletRequestBuilder signed(
			MockHttpServletRequestBuilder builder,
			String deviceId,
			KeyPair authKp,
			String body) throws Exception {
		long ts = Instant.now().getEpochSecond();
		String nonce = UUID.randomUUID().toString();
		var req = builder.buildRequest(new org.springframework.mock.web.MockServletContext());
		String pathWithQuery = req.getRequestURI()
				+ (req.getQueryString() != null ? "?" + req.getQueryString() : "");
		String bodyHash = Ed25519SignatureVerifier.sha256Hex(body.getBytes(StandardCharsets.UTF_8));
		String canonical = String.join("\n", req.getMethod().toUpperCase(), pathWithQuery,
				Long.toString(ts), nonce, bodyHash);
		Signature sig = Signature.getInstance("Ed25519");
		sig.initSign(authKp.getPrivate());
		sig.update(canonical.getBytes(StandardCharsets.UTF_8));
		String sigB64 = Base64.getUrlEncoder().encodeToString(sig.sign());
		return builder
				.header("X-Device-Id", deviceId)
				.header("X-Timestamp", Long.toString(ts))
				.header("X-Nonce", nonce)
				.header("X-Signature", sigB64);
	}

	private static KeyPair generateEd25519() throws Exception {
		return KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
	}

	private static String rawEd25519B64(KeyPair kp) {
		byte[] encoded = kp.getPublic().getEncoded();
		return b64(Arrays.copyOfRange(encoded, encoded.length - 32, encoded.length));
	}

	private static byte[] randomBytes32() {
		byte[] b = new byte[32];
		new java.security.SecureRandom().nextBytes(b);
		return b;
	}

	private static String b64(byte[] bytes) {
		return Base64.getUrlEncoder().encodeToString(bytes);
	}

	private record PairedCouple(String coupleId, String devAId, KeyPair devAKp, String devBId, KeyPair devBKp) {}

	private record CreateInviteBody(
			String deviceLabel, String deviceAuthPublicKeyB64, String deviceKemPublicKeyB64, String recoveryAuthPublicKeyB64) {}

	private record AcceptInviteBody(
			String inviteToken, String deviceLabel, String deviceAuthPublicKeyB64, String deviceKemPublicKeyB64) {}

	private record KeyDeliveryBody(String toDeviceId, String nonceB64, String ciphertextB64) {}

	private record UploadEnvBody(
			String envelopeId, String channel, int keyEpoch, String nonceB64, String ciphertextB64) {}
}
