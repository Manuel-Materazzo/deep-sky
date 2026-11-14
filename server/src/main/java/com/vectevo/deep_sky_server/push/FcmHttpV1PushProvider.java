package com.vectevo.deep_sky_server.push;

import java.time.Clock;
import java.util.Map;
import java.util.Objects;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

/**
 * FCM HTTP v1 data-only wakeup sender (SP-01, S-02, TC-04).
 * Sends zero intimate content: only {@code l10nKey}, {@code event=wakeup}, and epoch seconds,
 * omitting any {@code notification} block so Android always renders its local generic text.
 */
public class FcmHttpV1PushProvider implements PushProvider {

	static final String DEFAULT_FCM_BASE_URL = "https://fcm.googleapis.com";

	private final String projectId;
	private final String fcmBaseUrl;
	private final ServiceAccountTokenProvider tokenProvider;
	private final RestClient restClient;
	private final Clock clock;

	public FcmHttpV1PushProvider(
			String projectId,
			ServiceAccountTokenProvider tokenProvider,
			RestClient restClient,
			Clock clock) {
		this(projectId, DEFAULT_FCM_BASE_URL, tokenProvider, restClient, clock);
	}

	public FcmHttpV1PushProvider(
			String projectId,
			String fcmBaseUrl,
			ServiceAccountTokenProvider tokenProvider,
			RestClient restClient,
			Clock clock) {
		if (projectId == null || projectId.isBlank()) {
			throw new IllegalArgumentException("Firebase projectId must not be blank");
		}
		this.projectId = projectId;
		this.fcmBaseUrl = Objects.requireNonNull(fcmBaseUrl, "fcmBaseUrl").replaceAll("/+$", "");
		this.tokenProvider = Objects.requireNonNull(tokenProvider, "tokenProvider");
		this.restClient = Objects.requireNonNull(restClient, "restClient");
		this.clock = Objects.requireNonNull(clock, "clock");
	}

	@Override
	public void sendWakeup(String deviceToken, String localizationKey) {
		if (deviceToken == null || deviceToken.isBlank()) {
			throw new IllegalArgumentException("deviceToken must not be blank");
		}
		String safeKey = (localizationKey == null || localizationKey.isBlank())
				? "wakeup.generic"
				: localizationKey;

		Map<String, Object> payload = Map.of(
				"message", Map.of(
						"token", deviceToken,
						"data", Map.of(
								"l10nKey", safeKey,
								"event", "wakeup",
								"ts", Long.toString(clock.instant().getEpochSecond())),
						"android", Map.of(
								"priority", "HIGH",
								"ttl", "86400s")));

		String accessToken = tokenProvider.getAccessToken();
		String endpoint = fcmBaseUrl + "/v1/projects/" + projectId + "/messages:send";

		try {
			restClient.post()
					.uri(endpoint)
					.header("Authorization", "Bearer " + accessToken)
					.contentType(MediaType.APPLICATION_JSON)
					.body(payload)
					.retrieve()
					.toBodilessEntity();
		} catch (RestClientResponseException ex) {
			String body = ex.getResponseBodyAsString();
			if (ex.getStatusCode().value() == HttpStatus.NOT_FOUND.value()
					|| body.contains("UNREGISTERED")
					|| body.contains("Requested entity was not found")) {
				throw new PushTokenUnregisteredException(
						deviceToken, "FCM token is unregistered (HTTP " + ex.getStatusCode().value() + ")");
			}
			throw new IllegalStateException(
					"FCM send failed with HTTP " + ex.getStatusCode().value() + ": " + body, ex);
		}
	}
}
