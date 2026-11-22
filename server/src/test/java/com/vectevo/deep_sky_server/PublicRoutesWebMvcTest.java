package com.vectevo.deep_sky_server;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.vectevo.deep_sky_server.config.DeepSkyProperties;
import com.vectevo.deep_sky_server.config.PublicEndpointRateLimiter;
import com.vectevo.deep_sky_server.config.SecurityConfig;
import com.vectevo.deep_sky_server.config.SystemCompatibilityController;
import com.vectevo.deep_sky_server.content.ContentPackController;
import com.vectevo.deep_sky_server.content.ContentPackStore;
import com.vectevo.deep_sky_server.pairing.DeviceAuthLookup;
import com.vectevo.deep_sky_server.pairing.PairingController;
import com.vectevo.deep_sky_server.pairing.PairingService;
import com.vectevo.deep_sky_server.push.PushController;
import com.vectevo.deep_sky_server.push.PushDtos;
import com.vectevo.deep_sky_server.push.PushService;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;

/**
 * Verifies AU-01: public routes (especially {@code /api/v1/content/pack/**},
 * {@code /api/v1/system/compatibility}, and {@code /api/v1/push/config}) pass through the
 * real Spring Security filter chain and {@code DeviceAuthFilter} without device auth headers.
 */
@WebMvcTest(controllers = {
	ContentPackController.class,
	SystemCompatibilityController.class,
	PushController.class,
	PairingController.class
})
@Import({SecurityConfig.class, PublicEndpointRateLimiter.class})
@EnableConfigurationProperties(DeepSkyProperties.class)
class PublicRoutesWebMvcTest {

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private PublicEndpointRateLimiter rateLimiter;

	@MockitoBean
	private DeviceAuthLookup deviceAuthLookup;

	@MockitoBean
	private ContentPackStore contentPackStore;

	@MockitoBean
	private PushService pushService;

	@MockitoBean
	private PairingService pairingService;

	@TempDir
	Path tempDir;

	@BeforeEach
	void setUp() {
		rateLimiter.reset();
	}

	@Test
	void contentPackAndPublicGetRoutesSucceedWithoutAuthHeaders() throws Exception {
		byte[] floorBytes = new byte[] {(byte) 0x89, 'P', 'N', 'G', 1, 2, 3};
		Path floorFile = tempDir.resolve("floor.png");
		Files.write(floorFile, floorBytes);
		String floorSha = sha256Hex(floorBytes);
		byte[] checksumsBytes = "{\"packVersion\":\"1.0.0\"}".getBytes(StandardCharsets.UTF_8);
		byte[] sigBytes = "v1:AAAA\n".getBytes(StandardCharsets.UTF_8);
		String checksumsSha = sha256Hex(checksumsBytes);
		String sigSha = sha256Hex(sigBytes);

		ContentPackStore.LoadedPack pack = new ContentPackStore.LoadedPack(
				"deep-sky-home-v1",
				"1.0.0",
				"v1",
				checksumsBytes,
				checksumsSha,
				sigBytes,
				sigSha,
				Map.of(
						"assets/floor.png",
						new ContentPackStore.PackFileEntry(
								"assets/floor.png", floorFile, floorSha, floorBytes.length)));
		when(contentPackStore.getActivePack()).thenReturn(Optional.of(pack));
		when(pushService.clientConfig()).thenReturn(new PushDtos.ClientConfig(false, "", "", "", ""));

		// Content pack endpoints (200 / 304 / 404) without auth headers
		mockMvc.perform(get("/api/v1/content/pack/checksums"))
				.andExpect(status().isOk());
		mockMvc.perform(get("/api/v1/content/pack/checksums")
						.header(HttpHeaders.IF_NONE_MATCH, "\"" + checksumsSha + "\""))
				.andExpect(status().isNotModified());
		mockMvc.perform(get("/api/v1/content/pack/checksums.sig"))
				.andExpect(status().isOk());
		mockMvc.perform(get("/api/v1/content/pack/files/assets/floor.png"))
				.andExpect(status().isOk());
		mockMvc.perform(get("/api/v1/content/pack/blobs/" + floorSha))
				.andExpect(status().isOk());
		mockMvc.perform(get("/api/v1/content/pack/files/assets/missing.png"))
				.andExpect(status().isNotFound());
		mockMvc.perform(get("/api/v1/content/pack/blobs/" + "0".repeat(64)))
				.andExpect(status().isNotFound());

		// Other public GET routes
		mockMvc.perform(get("/api/v1/system/compatibility"))
				.andExpect(status().isOk());
		mockMvc.perform(get("/api/v1/push/config"))
				.andExpect(status().isOk());

		// Non-public routes and non-GET methods on content pack remain protected
		mockMvc.perform(get("/api/v1/pairing/devices"))
				.andExpect(status().isUnauthorized());
		mockMvc.perform(post("/api/v1/content/pack/checksums"))
				.andExpect(status().isUnauthorized());
	}

	@Test
	void oversizedPublicPostBodyIsRejectedWith413() throws Exception {
		String hugePayload = "{\"deviceLabel\":\"" + "a".repeat(70_000) + "\"}";
		mockMvc.perform(post("/api/v1/pairing/invites")
						.contentType(MediaType.APPLICATION_JSON)
						.content(hugePayload))
				.andExpect(status().isPayloadTooLarge())
				.andExpect(jsonPath("$.code").value("PAYLOAD_TOO_LARGE"));
	}

	private static String sha256Hex(byte[] bytes) throws Exception {
		return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
	}
}
