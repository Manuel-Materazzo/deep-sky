package com.vectevo.deep_sky_server.push;

/**
 * Raised when the upstream push provider reports a device registration token is no longer valid
 * (e.g. FCM HTTP v1 {@code UNREGISTERED}), so persistence layers purge the stale token (SP-01).
 */
public class PushTokenUnregisteredException extends RuntimeException {

	private final String deviceToken;

	public PushTokenUnregisteredException(String deviceToken, String message) {
		super(message);
		this.deviceToken = deviceToken;
	}

	public String getDeviceToken() {
		return deviceToken;
	}
}
