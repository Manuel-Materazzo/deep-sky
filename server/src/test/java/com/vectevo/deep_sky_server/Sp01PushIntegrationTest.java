package com.vectevo.deep_sky_server;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.vectevo.deep_sky_server.push.PushProvider;
import com.vectevo.deep_sky_server.push.PushRegistrationRepository;
import com.vectevo.deep_sky_server.push.PushTokenUnregisteredException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.util.Base64;
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
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

/**
 * SP-01 backend integration tests: runtime Firebase client config delivery,
 * token registration/rotation, data-only wakeup allowlist, and dead-token eviction.
 */
@SpringBootTest
@Testcontainers
@AutoConfigureMockMvc
@ActiveProfiles("test")
class Sp01PushIntegrationTest {

	@TempDir
	static Path tempDir;

	@Container
	@ServiceConnection
	static final PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:17-alpine");

	@DynamicPropertySource
	static void firebaseProps(DynamicPropertyRegistry registry) throws Exception {
		KeyPairGenerator kpg = KeyPairGenerator.getInstance("RSA");
		kpg.initialize(2048);
		KeyPair rsa = kpg.generateKeyPair();
		String keyBase64 = Base64.getEncoder().encodeToString(rsa.getPrivate().getEncoded());
		Path saFile = tempDir.resolve("sa-test.json");
		Files.writeString(
				saFile,
				"{\"client_email\":\"test@deepsky-proto.iam.gserviceaccount.com\",\"private_key\":\"" + keyBase64 + "\"}",
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
	private PushRegistrationRepository registrationRepository;

	@MockitoBean
	private PushProvider pushProvider;

	@BeforeEach
	void cleanDb() {
		registrationRepository.deleteAll();
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
	void registersRotatesDispatchesAndEvictsUnregisteredToken() throws Exception {
		mockMvc.perform(put("/api/v1/push/token")
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "deviceId": "dev-pixel-9",
								  "coupleId": "couple-01",
								  "fcmToken": "token-v1-secret-123456",
								  "platform": "android"
								}
								"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.deviceId").value("dev-pixel-9"))
				.andExpect(jsonPath("$.tokenPrefix").value("token-v1"));

		// Rotate token on same deviceId.
		mockMvc.perform(put("/api/v1/push/token")
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "deviceId": "dev-pixel-9",
								  "coupleId": "couple-01",
								  "fcmToken": "token-v2-rotated-98765",
								  "platform": "android"
								}
								"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.tokenPrefix").value("token-v2"));

		doNothing().when(pushProvider).sendWakeup("token-v2-rotated-98765", "wakeup.new_moment");
		mockMvc.perform(post("/api/v1/push/test-wakeup")
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "deviceId": "dev-pixel-9",
								  "localizationKey": "wakeup.new_moment"
								}
								"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.attempted").value(1))
				.andExpect(jsonPath("$.delivered").value(1))
				.andExpect(jsonPath("$.unregisteredRemoved").value(0));

		verify(pushProvider).sendWakeup("token-v2-rotated-98765", "wakeup.new_moment");

		// Reject arbitrary localization keys or intimate text (S-02).
		mockMvc.perform(post("/api/v1/push/test-wakeup")
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "deviceId": "dev-pixel-9",
								  "localizationKey": "raw intimate message text"
								}
								"""))
				.andExpect(status().isBadRequest());

		// When FCM reports UNREGISTERED, stale token is removed from Postgres.
		doThrow(new PushTokenUnregisteredException("token-v2-rotated-98765", "gone"))
				.when(pushProvider).sendWakeup("token-v2-rotated-98765", "wakeup.generic");

		mockMvc.perform(post("/api/v1/push/test-wakeup")
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "coupleId": "couple-01",
								  "localizationKey": "wakeup.generic"
								}
								"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.attempted").value(1))
				.andExpect(jsonPath("$.delivered").value(0))
				.andExpect(jsonPath("$.unregisteredRemoved").value(1));

		assertThat(registrationRepository.findByDeviceId("dev-pixel-9")).isEmpty();
		mockMvc.perform(get("/api/v1/push/token/dev-pixel-9")).andExpect(status().isNotFound());
	}

	@Test
	void unregistersTokenOnDelete() throws Exception {
		mockMvc.perform(put("/api/v1/push/token")
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "deviceId": "dev-delete-me",
								  "coupleId": "couple-02",
								  "fcmToken": "token-delete-123456"
								}
								"""))
				.andExpect(status().isOk());

		mockMvc.perform(delete("/api/v1/push/token/dev-delete-me"))
				.andExpect(status().isNoContent());

		mockMvc.perform(delete("/api/v1/push/token/dev-delete-me"))
				.andExpect(status().isNotFound());
	}
}
