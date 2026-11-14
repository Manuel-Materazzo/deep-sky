package com.vectevo.deep_sky_server.push;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.header;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.jsonPath;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.Signature;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Base64;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;
import tools.jackson.databind.json.JsonMapper;

class Sp01FcmHttpClientTest {

	private static final JsonMapper JSON = JsonMapper.builder().build();
	private static final Clock FIXED_CLOCK = Clock.fixed(Instant.parse("2026-11-14T12:00:00Z"), ZoneOffset.UTC);

	@Test
	void mintsRs256JwtCachesAccessTokenAndSendsDataOnlyWakeup() throws Exception {
		KeyPairGenerator kpg = KeyPairGenerator.getInstance("RSA");
		kpg.initialize(2048);
		KeyPair rsa = kpg.generateKeyPair();

		String pem = Base64.getMimeEncoder(64, new byte[] {'\n'})
				.encodeToString(rsa.getPrivate().getEncoded());
		String saJson = JSON.writeValueAsString(java.util.Map.of(
				"client_email", "deep-sky-test@test-proj.iam.gserviceaccount.com",
				"private_key", pem,
				"token_uri", "https://oauth2.example.test/token"));

		RestClient.Builder builder = RestClient.builder();
		MockRestServiceServer mockServer = MockRestServiceServer.bindTo(builder).build();
		RestClient restClient = builder.build();

		ServiceAccountTokenProvider tokenProvider =
				new ServiceAccountTokenProvider(saJson, restClient, JSON, FIXED_CLOCK);

		// Verify generated JWT assertion mathematically verifies against the public key.
		String jwt = tokenProvider.createJwtAssertion(FIXED_CLOCK.instant());
		String[] parts = jwt.split("\\.");
		assertThat(parts).hasSize(3);
		Signature verifier = Signature.getInstance("SHA256withRSA");
		verifier.initVerify(rsa.getPublic());
		verifier.update((parts[0] + "." + parts[1]).getBytes(StandardCharsets.US_ASCII));
		assertThat(verifier.verify(Base64.getUrlDecoder().decode(parts[2]))).isTrue();

		mockServer.expect(requestTo("https://oauth2.example.test/token"))
				.andExpect(method(HttpMethod.POST))
				.andRespond(withSuccess(
						"{\"access_token\":\"ya29.test-access-token\",\"expires_in\":3600}",
						MediaType.APPLICATION_JSON));

		mockServer.expect(requestTo("https://fcm.example.test/v1/projects/test-proj/messages:send"))
				.andExpect(method(HttpMethod.POST))
				.andExpect(header("Authorization", "Bearer ya29.test-access-token"))
				.andExpect(jsonPath("$.message.token").value("fcm-token-abc"))
				.andExpect(jsonPath("$.message.data.l10nKey").value("wakeup.new_moment"))
				.andExpect(jsonPath("$.message.data.event").value("wakeup"))
				.andExpect(jsonPath("$.message.android.priority").value("HIGH"))
				.andExpect(jsonPath("$.message.notification").doesNotExist())
				.andRespond(withSuccess("{\"name\":\"projects/test-proj/messages/1\"}", MediaType.APPLICATION_JSON));

		// Second send reuses cached OAuth token (no second call to oauth2.example.test/token) and maps 404 -> Unregistered.
		mockServer.expect(requestTo("https://fcm.example.test/v1/projects/test-proj/messages:send"))
				.andExpect(method(HttpMethod.POST))
				.andRespond(withStatus(HttpStatus.NOT_FOUND)
						.contentType(MediaType.APPLICATION_JSON)
						.body("{\"error\":{\"code\":404,\"status\":\"NOT_FOUND\",\"details\":[{\"errorCode\":\"UNREGISTERED\"}]}}"));

		FcmHttpV1PushProvider provider = new FcmHttpV1PushProvider(
				"test-proj", "https://fcm.example.test", tokenProvider, restClient, FIXED_CLOCK);

		provider.sendWakeup("fcm-token-abc", "wakeup.new_moment");

		assertThatThrownBy(() -> provider.sendWakeup("dead-token", "wakeup.generic"))
				.isInstanceOf(PushTokenUnregisteredException.class);

		mockServer.verify();
	}
}
