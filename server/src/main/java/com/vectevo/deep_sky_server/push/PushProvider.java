package com.vectevo.deep_sky_server.push;

/**
 * Push delivery abstraction allowing FCM (TC-13) or alternative providers such as UnifiedPush
 * without coupling sync logic to Firebase (SP-01, AR-10).
 */
public interface PushProvider {

	/** Sends a content-free wakeup signal with a generic localization key (S-02). */
	void sendWakeup(String deviceToken, String localizationKey);
}
