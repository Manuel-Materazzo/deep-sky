package com.vectevo.deep_sky_server;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.vectevo.deep_sky_server.config.DeepSkyProperties;
import com.vectevo.deep_sky_server.config.PublicEndpointRateLimiter;
import com.vectevo.deep_sky_server.config.SecurityConfig;
import com.vectevo.deep_sky_server.pairing.DeviceAuthLookup;
import com.vectevo.deep_sky_server.pairing.PairingController;
import com.vectevo.deep_sky_server.pairing.PairingService;
import com.vectevo.deep_sky_server.pairing.PairingVisibilityController;
import com.vectevo.deep_sky_server.shared.Ed25519SignatureVerifier;
import com.vectevo.deep_sky_server.sync.SyncController;
import com.vectevo.deep_sky_server.sync.SyncService;
import com.vectevo.deep_sky_server.sync.SyncVisibilityController;
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.Signature;
import java.time.Instant;
import java.util.Arrays;
import java.util.Base64;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/**
 * Verifies CA-08: visibility audit endpoints are unavailable when the `prod` profile is active.
 */
@WebMvcTest(controllers = {
	PairingController.class,
	SyncController.class,
	PairingVisibilityController.class,
	SyncVisibilityController.class
})
@Import({SecurityConfig.class, PublicEndpointRateLimiter.class})
@EnableConfigurationProperties(DeepSkyProperties.class)
@ActiveProfiles("prod")
class ProdVisibilityDisabledWebMvcTest {

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private DeviceAuthLookup deviceAuthLookup;

	@MockitoBean
	private PairingService pairingService;

	@MockitoBean
	private SyncService syncService;

	@Test
	void visibilityEndpointsAreNotRegisteredInProdProfile() throws Exception {
		UUID coupleId = UUID.randomUUID();
		UUID deviceId = UUID.randomUUID();
		KeyPair kp = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
		byte[] encoded = kp.getPublic().getEncoded();
		byte[] rawPub = Arrays.copyOfRange(encoded, encoded.length - 32, encoded.length);

		when(deviceAuthLookup.findActiveDevice(deviceId))
				.thenReturn(Optional.of(new DeviceAuthLookup.ActiveDeviceKey(coupleId, deviceId, rawPub, true)));
		when(deviceAuthLookup.consumeNonceIfUnused(any(), any(), any())).thenReturn(true);

		mockMvc.perform(signed(get("/api/v1/pairing/visibility"), deviceId, kp))
				.andExpect(status().isNotFound());
		mockMvc.perform(signed(get("/api/v1/sync/visibility"), deviceId, kp))
				.andExpect(status().isNotFound());
	}

	private MockHttpServletRequestBuilder signed(
			MockHttpServletRequestBuilder builder, UUID deviceId, KeyPair kp) throws Exception {
		long ts = Instant.now().getEpochSecond();
		String nonce = UUID.randomUUID().toString();
		var req = builder.buildRequest(new org.springframework.mock.web.MockServletContext());
		String bodyHash = Ed25519SignatureVerifier.sha256Hex(new byte[0]);
		String canonical = String.join(
				"\n", req.getMethod().toUpperCase(), req.getRequestURI(), Long.toString(ts), nonce, bodyHash);
		Signature sig = Signature.getInstance("Ed25519");
		sig.initSign(kp.getPrivate());
		sig.update(canonical.getBytes(StandardCharsets.UTF_8));
		String sigB64 = Base64.getUrlEncoder().encodeToString(sig.sign());
		return builder
				.header("X-Device-Id", deviceId.toString())
				.header("X-Timestamp", Long.toString(ts))
				.header("X-Nonce", nonce)
				.header("X-Signature", sigB64);
	}
}
