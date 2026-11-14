package com.vectevo.deep_sky_server.push;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Safe fallback {@link PushProvider} used when runtime Firebase credentials are not configured
 * (for example local dev or CI without service account JSON).
 */
public class NoopPushProvider implements PushProvider {

	private static final Logger log = LoggerFactory.getLogger(NoopPushProvider.class);

	@Override
	public void sendWakeup(String deviceToken, String localizationKey) {
		String prefix = deviceToken == null ? "null" : deviceToken.substring(0, Math.min(8, deviceToken.length()));
		log.info("Push disabled/unconfigured; skipping wakeup l10nKey={} tokenPrefix={}...", localizationKey, prefix);
	}
}
