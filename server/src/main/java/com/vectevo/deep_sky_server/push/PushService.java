package com.vectevo.deep_sky_server.push;

import com.vectevo.deep_sky_server.push.PushDtos.ClientConfig;
import com.vectevo.deep_sky_server.push.PushDtos.TokenStatus;
import com.vectevo.deep_sky_server.push.PushDtos.WakeupOutcome;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Service backing SP-01 runtime push config, FCM token persistence, and data-only wakeups.
 */
@Service
public class PushService {

	public static final Set<String> SUPPORTED_KEYS = Set.of(
			"wakeup.generic",
			"wakeup.new_moment",
			"wakeup.capsule_ready",
			"wakeup.daily_prompt");

	private final PushConfig config;
	private final PushRegistrationRepository repository;
	private final PushProvider pushProvider;
	private final Clock clock;

	public PushService(
			PushConfig config,
			PushRegistrationRepository repository,
			PushProvider pushProvider,
			Clock clock) {
		this.config = config;
		this.repository = repository;
		this.pushProvider = pushProvider;
		this.clock = clock;
	}

	public ClientConfig clientConfig() {
		return new ClientConfig(
				config.enabled() && config.hasClientOptions(),
				orEmpty(config.projectId()),
				orEmpty(config.apiKey()),
				orEmpty(config.appId()),
				orEmpty(config.senderId()));
	}

	@Transactional
	public TokenStatus register(String deviceId, String coupleId, String fcmToken, String platform) {
		if (deviceId == null || deviceId.isBlank() || fcmToken == null || fcmToken.isBlank()) {
			throw new IllegalArgumentException("deviceId and fcmToken are required");
		}
		Instant now = clock.instant();
		String plat = (platform == null || platform.isBlank()) ? "android" : platform.trim();
		PushRegistrationEntity entity = repository.findByDeviceId(deviceId.trim())
				.orElseGet(() -> new PushRegistrationEntity(
						UUID.randomUUID(), deviceId.trim(), coupleId, fcmToken.trim(), plat, now));
		entity.setCoupleId(coupleId == null || coupleId.isBlank() ? null : coupleId.trim());
		entity.setFcmToken(fcmToken.trim());
		entity.setUpdatedAt(now);
		return toStatus(repository.save(entity));
	}

	@Transactional
	public boolean unregister(String deviceId) {
		Optional<PushRegistrationEntity> existing = repository.findByDeviceId(deviceId);
		if (existing.isEmpty()) {
			return false;
		}
		repository.delete(existing.get());
		return true;
	}

	@Transactional(readOnly = true)
	public Optional<TokenStatus> statusFor(String deviceId) {
		return repository.findByDeviceId(deviceId).map(this::toStatus);
	}

	@Transactional
	public WakeupOutcome dispatchWakeup(String deviceId, String coupleId, String localizationKey) {
		String key = (localizationKey == null || localizationKey.isBlank())
				? "wakeup.generic"
				: localizationKey.trim();
		if (!SUPPORTED_KEYS.contains(key)) {
			throw new IllegalArgumentException("Unsupported localizationKey: " + key);
		}
		List<PushRegistrationEntity> targets = loadTargets(deviceId, coupleId);

		int delivered = 0;
		int evicted = 0;
		Instant now = clock.instant();
		for (PushRegistrationEntity target : targets) {
			try {
				pushProvider.sendWakeup(target.getFcmToken(), key);
				target.setLastWakeupAt(now);
				repository.save(target);
				delivered++;
			} catch (PushTokenUnregisteredException stale) {
				repository.delete(target);
				evicted++;
			}
		}
		return new WakeupOutcome(key, targets.size(), delivered, evicted);
	}

	private List<PushRegistrationEntity> loadTargets(String deviceId, String coupleId) {
		if (deviceId != null && !deviceId.isBlank()) {
			return repository.findByDeviceId(deviceId.trim()).map(List::of).orElse(List.of());
		}
		if (coupleId != null && !coupleId.isBlank()) {
			return repository.findAllByCoupleIdOrderByUpdatedAtDesc(coupleId.trim());
		}
		throw new IllegalArgumentException("Provide deviceId or coupleId");
	}

	private TokenStatus toStatus(PushRegistrationEntity entity) {
		String tok = entity.getFcmToken();
		return new TokenStatus(
				entity.getDeviceId(),
				entity.getCoupleId(),
				entity.getPlatform(),
				tok.substring(0, Math.min(8, tok.length())),
				tok.length(),
				entity.getUpdatedAt(),
				entity.getLastWakeupAt());
	}

	private static String orEmpty(String v) {
		return v == null ? "" : v;
	}
}
