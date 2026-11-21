package com.vectevo.deep_sky_server;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.vectevo.deep_sky_server.config.DeepSkyProperties;
import com.vectevo.deep_sky_server.config.PublicEndpointRateLimiter;
import com.vectevo.deep_sky_server.config.SecurityConfig;
import com.vectevo.deep_sky_server.pairing.DeviceAuthLookup;
import com.vectevo.deep_sky_server.pairing.PairingController;
import com.vectevo.deep_sky_server.pairing.PairingService;
import com.vectevo.deep_sky_server.push.PushController;
import com.vectevo.deep_sky_server.push.PushDtos;
import com.vectevo.deep_sky_server.push.PushService;
import com.vectevo.deep_sky_server.shared.Ed25519SignatureVerifier;
import com.vectevo.deep_sky_server.sync.SyncController;
import com.vectevo.deep_sky_server.sync.SyncService;
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.Signature;
import java.time.Instant;
import java.util.Arrays;
import java.util.Base64;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/**
 * Verifies CA-03 (unapproved device authorization restrictions) and CA-05 (POST body invite routes)
 * across SecurityConfig, DeviceAuthFilter, and controllers without requiring Docker.
 */
@WebMvcTest(controllers = {PairingController.class, SyncController.class, PushController.class})
@Import({SecurityConfig.class, PublicEndpointRateLimiter.class})
@EnableConfigurationProperties(DeepSkyProperties.class)
class SecurityApprovalWebMvcTest {

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private PublicEndpointRateLimiter rateLimiter;

	@MockitoBean
	private DeviceAuthLookup deviceAuthLookup;

	@MockitoBean
	private PairingService pairingService;

	@MockitoBean
	private SyncService syncService;

	@MockitoBean
	private PushService pushService;

	private UUID coupleId;
	private UUID unapprovedDeviceId;
	private UUID approvedDeviceId;
	private KeyPair unapprovedKp;
	private KeyPair approvedKp;

	@BeforeEach
	void setUp() throws Exception {
		rateLimiter.reset();
		coupleId = UUID.randomUUID();
		unapprovedDeviceId = UUID.randomUUID();
		approvedDeviceId = UUID.randomUUID();
		unapprovedKp = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
		approvedKp = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();

		when(deviceAuthLookup.findActiveDevice(unapprovedDeviceId))
				.thenReturn(Optional.of(new DeviceAuthLookup.ActiveDeviceKey(
						coupleId, unapprovedDeviceId, rawPub(unapprovedKp), false)));
		when(deviceAuthLookup.findActiveDevice(approvedDeviceId))
				.thenReturn(Optional.of(new DeviceAuthLookup.ActiveDeviceKey(
						coupleId, approvedDeviceId, rawPub(approvedKp), true)));
		when(deviceAuthLookup.consumeNonceIfUnused(any(), anyString(), any())).thenReturn(true);
	}

	@Test
	void unapprovedDeviceGets403OnRestrictedEndpointsAndIsAllowedOnBootstrapEndpoints() throws Exception {
		String envBody = "{\"envelopeId\":\"" + UUID.randomUUID() + "\",\"channel\":\"EVENT\","
				+ "\"keyEpoch\":1,\"nonceB64\":\"AAAA\",\"ciphertextB64\":\"BBBB\"}";
		String deliveryBody = "{\"toDeviceId\":\"" + approvedDeviceId + "\","
				+ "\"nonceB64\":\"AAAA\",\"ciphertextB64\":\"BBBB\"}";
		String pushRegBody = "{\"fcmToken\":\"tok\",\"platform\":\"android\"}";

		// Restricted endpoints -> 403 FORBIDDEN
		mockMvc.perform(signed(post("/api/v1/pairing/enrollment-invites"), unapprovedDeviceId, unapprovedKp, ""))
				.andExpect(status().isForbidden())
				.andExpect(jsonPath("$.code").value("FORBIDDEN"));
		mockMvc.perform(signed(
						post("/api/v1/pairing/key-deliveries")
								.contentType(MediaType.APPLICATION_JSON)
								.content(deliveryBody),
						unapprovedDeviceId, unapprovedKp, deliveryBody))
				.andExpect(status().isForbidden());
		mockMvc.perform(signed(get("/api/v1/pairing/devices"), unapprovedDeviceId, unapprovedKp, ""))
				.andExpect(status().isForbidden());
		mockMvc.perform(signed(
						post("/api/v1/pairing/devices/" + approvedDeviceId + "/revoke"),
						unapprovedDeviceId, unapprovedKp, ""))
				.andExpect(status().isForbidden());
		mockMvc.perform(signed(post("/api/v1/pairing/unpair"), unapprovedDeviceId, unapprovedKp, ""))
				.andExpect(status().isForbidden());
		mockMvc.perform(signed(get("/api/v1/pairing/visibility"), unapprovedDeviceId, unapprovedKp, ""))
				.andExpect(status().isForbidden());
		mockMvc.perform(signed(
						post("/api/v1/sync/envelopes")
								.contentType(MediaType.APPLICATION_JSON)
								.content(envBody),
						unapprovedDeviceId, unapprovedKp, envBody))
				.andExpect(status().isForbidden());
		mockMvc.perform(signed(get("/api/v1/sync/envelopes?afterSeq=0"), unapprovedDeviceId, unapprovedKp, ""))
				.andExpect(status().isForbidden());
		mockMvc.perform(signed(get("/api/v1/sync/visibility"), unapprovedDeviceId, unapprovedKp, ""))
				.andExpect(status().isForbidden());
		mockMvc.perform(signed(
						post("/api/v1/push/register")
								.contentType(MediaType.APPLICATION_JSON)
								.content(pushRegBody),
						unapprovedDeviceId, unapprovedKp, pushRegBody))
				.andExpect(status().isForbidden());
		mockMvc.perform(signed(post("/api/v1/push/wakeup"), unapprovedDeviceId, unapprovedKp, ""))
				.andExpect(status().isForbidden());

		// Allowed endpoints for unapproved device
		when(pairingService.fetchPendingKeyDelivery(any())).thenReturn(
				new PairingService.KeyDeliveryView(
						coupleId, approvedDeviceId, unapprovedDeviceId, "AAAA", "BBBB", Instant.now()));
		when(pairingService.updateOwnDeviceLabel(any(), anyString())).thenReturn(
				new PairingService.DeviceView(unapprovedDeviceId, "Luna", "INVITE_JOIN", Instant.now(), null));
		when(pairingService.getInviteStatus(any(), anyString())).thenReturn(
				new PairingService.InviteStatusResult(true, unapprovedDeviceId, "Luna", "AAAA", "BBBB"));

		mockMvc.perform(signed(get("/api/v1/pairing/key-deliveries/me"), unapprovedDeviceId, unapprovedKp, ""))
				.andExpect(status().isOk());
		String labelBody = "{\"deviceLabel\":\"Luna\"}";
		mockMvc.perform(signed(
						patch("/api/v1/pairing/devices/me")
								.contentType(MediaType.APPLICATION_JSON)
								.content(labelBody),
						unapprovedDeviceId, unapprovedKp, labelBody))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.label").value("Luna"));
		String statusBody = "{\"inviteToken\":\"secret-tok\"}";
		mockMvc.perform(signed(
						post("/api/v1/pairing/invites/status")
								.contentType(MediaType.APPLICATION_JSON)
								.content(statusBody),
						unapprovedDeviceId, unapprovedKp, statusBody))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.accepted").value(true));
	}

	@Test
	void approvedDeviceCanCallRestrictedEndpointsAndAcceptUsesBodyToken() throws Exception {
		when(syncService.listEnvelopes(any(), anyLong(), anyInt()))
				.thenReturn(new SyncService.EnvelopePageView(List.of(), 0L, false));
		when(pairingService.listDevices(any())).thenReturn(List.of());
		when(pushService.register(any(), any(), anyString(), anyString()))
				.thenReturn(new PushDtos.TokenStatus(
						approvedDeviceId.toString(),
						coupleId.toString(),
						"android",
						"tok12345",
						8,
						Instant.now(),
						null));

		mockMvc.perform(signed(get("/api/v1/sync/envelopes?afterSeq=0"), approvedDeviceId, approvedKp, ""))
				.andExpect(status().isOk());
		mockMvc.perform(signed(get("/api/v1/pairing/devices"), approvedDeviceId, approvedKp, ""))
				.andExpect(status().isOk());

		String pushRegBody = "{\"fcmToken\":\"tok12345\",\"platform\":\"android\"}";
		mockMvc.perform(signed(
						post("/api/v1/push/register")
								.contentType(MediaType.APPLICATION_JSON)
								.content(pushRegBody),
						approvedDeviceId, approvedKp, pushRegBody))
				.andExpect(status().isOk());

		when(pairingService.acceptInvite(anyString(), anyString(), anyString(), anyString()))
				.thenReturn(new PairingService.AcceptInviteResult(
						coupleId, unapprovedDeviceId, approvedDeviceId, "Pixel A", "AAAA", "BBBB"));
		String acceptBody = "{\"inviteToken\":\"tok-in-body\",\"deviceLabel\":\"Pixel B\","
				+ "\"deviceAuthPublicKeyB64\":\"AAAA\",\"deviceKemPublicKeyB64\":\"BBBB\"}";
		mockMvc.perform(post("/api/v1/pairing/invites/accept")
						.contentType(MediaType.APPLICATION_JSON)
						.content(acceptBody))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.coupleId").value(coupleId.toString()));

		// Legacy path-token endpoint is gone (unmatched routes require APPROVED_DEVICE -> 401 unauthenticated)
		mockMvc.perform(post("/api/v1/pairing/invites/tok-in-url/accept")
						.contentType(MediaType.APPLICATION_JSON)
						.content(acceptBody))
				.andExpect(status().isUnauthorized());
	}

	@Test
	void forgedXForwardedForCannotBypassRateLimit() throws Exception {
		when(pairingService.acceptInvite(anyString(), anyString(), anyString(), anyString()))
				.thenThrow(new IllegalStateException("Invite is invalid, expired, or already used"));
		String acceptBody = "{\"inviteToken\":\"bad-tok\",\"deviceLabel\":\"Phone\","
				+ "\"deviceAuthPublicKeyB64\":\"AAAA\",\"deviceKemPublicKeyB64\":\"BBBB\"}";
		for (int i = 0; i < 5; i++) {
			final int idx = i;
			mockMvc.perform(post("/api/v1/pairing/invites/accept")
							.with(r -> {
								r.setRemoteAddr("198.51.100.77");
								return r;
							})
							.header("X-Forwarded-For", "203.0.113." + (10 + idx))
							.contentType(MediaType.APPLICATION_JSON)
							.content(acceptBody))
					.andExpect(status().isConflict());
		}
		mockMvc.perform(post("/api/v1/pairing/invites/accept")
						.with(r -> {
							r.setRemoteAddr("198.51.100.77");
							return r;
						})
						.header("X-Forwarded-For", "203.0.113.99")
						.contentType(MediaType.APPLICATION_JSON)
						.content(acceptBody))
				.andExpect(status().isTooManyRequests())
				.andExpect(jsonPath("$.code").value("RATE_LIMITED"));
	}

	@Test
	void deviceAuthUsesUniform401AndGlobalExceptionHandlerSanitizesErrors() throws Exception {
		UUID unknownId = UUID.randomUUID();
		when(deviceAuthLookup.findActiveDevice(unknownId)).thenReturn(Optional.empty());

		MvcResult unknownRes = mockMvc.perform(signed(get("/api/v1/pairing/devices"), unknownId, approvedKp, ""))
				.andExpect(status().isUnauthorized())
				.andReturn();
		// Valid active device ID signed with wrong keypair
		MvcResult badSigRes = mockMvc.perform(signed(get("/api/v1/pairing/devices"), approvedDeviceId, unapprovedKp, ""))
				.andExpect(status().isUnauthorized())
				.andReturn();
		assertThat(unknownRes.getResponse().getContentAsString())
				.isEqualTo(badSigRes.getResponse().getContentAsString());
		assertThat(unknownRes.getResponse().getContentAsString())
				.contains("\"code\":\"DEVICE_AUTH_FAILED\"");

		// AU-16: Clock skew returns a distinct CLOCK_SKEW code instead of ambiguous revocation
		long skewedTs = Instant.now().getEpochSecond() - 600;
		mockMvc.perform(get("/api/v1/pairing/devices")
						.header("X-Device-Id", approvedDeviceId.toString())
						.header("X-Timestamp", Long.toString(skewedTs))
						.header("X-Nonce", UUID.randomUUID().toString())
						.header("X-Signature", Base64.getUrlEncoder().encodeToString(new byte[64])))
				.andExpect(status().isUnauthorized())
				.andExpect(jsonPath("$.code").value("CLOCK_SKEW"));

		// AU-22: Oversized platform field fails validation cleanly with 400 (not 500 DB constraint error)
		String oversizedPlatformBody = "{\"fcmToken\":\"tok12345\",\"platform\":\"android-way-too-long-platform-name\"}";
		mockMvc.perform(signed(
						post("/api/v1/push/register")
								.contentType(MediaType.APPLICATION_JSON)
								.content(oversizedPlatformBody),
						approvedDeviceId, approvedKp, oversizedPlatformBody))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

		// Unhandled runtime exception returns generic 500 without leaking raw message (CA-13)
		when(pairingService.listDevices(any())).thenThrow(new RuntimeException("sensitive internal DB detail"));
		MvcResult errRes = mockMvc.perform(signed(get("/api/v1/pairing/devices"), approvedDeviceId, approvedKp, ""))
				.andExpect(status().isInternalServerError())
				.andExpect(jsonPath("$.code").value("INTERNAL_ERROR"))
				.andReturn();
		assertThat(errRes.getResponse().getContentAsString()).doesNotContain("sensitive internal DB detail");
	}

	private MockHttpServletRequestBuilder signed(
			MockHttpServletRequestBuilder builder,
			UUID deviceId,
			KeyPair kp,
			String body) throws Exception {
		long ts = Instant.now().getEpochSecond();
		String nonce = UUID.randomUUID().toString();
		var req = builder.buildRequest(new org.springframework.mock.web.MockServletContext());
		String pathWithQuery = req.getRequestURI()
				+ (req.getQueryString() != null ? "?" + req.getQueryString() : "");
		String bodyHash = Ed25519SignatureVerifier.sha256Hex(body.getBytes(StandardCharsets.UTF_8));
		String canonical = String.join(
				"\n", req.getMethod().toUpperCase(), pathWithQuery, Long.toString(ts), nonce, bodyHash);
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

	private static byte[] rawPub(KeyPair kp) {
		byte[] encoded = kp.getPublic().getEncoded();
		return Arrays.copyOfRange(encoded, encoded.length - 32, encoded.length);
	}
}
