package com.vectevo.deep_sky_server.push;

import com.vectevo.deep_sky_server.push.PushDtos.ClientConfig;
import com.vectevo.deep_sky_server.push.PushDtos.TokenStatus;
import com.vectevo.deep_sky_server.push.PushDtos.WakeupOutcome;
import com.vectevo.deep_sky_server.shared.PartnerWakeupRequestedEvent;
import com.vectevo.deep_sky_server.shared.RateLimitExceededException;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Runtime push configuration, authenticated FCM token persistence, revocation cleanup,
 * throttled client wakeups, and post-commit partner wakeups (`SP-01`, `PR-M2-03`, `S-02`, `CA-07`, `CA-09`).
 */
@Service
public class PushService {

	private static final Logger log = LoggerFactory.getLogger(PushService.class);
	private static final long WAKEUP_WINDOW_MILLIS = 60_000L;

	public static final Set<String> CLIENT_TRIGGERABLE_KEYS = Set.of(
			"wakeup.generic",
			"wakeup.thinking_of_you",
			"wakeup.new_moment",
			"wakeup.capsule_ready",
			"wakeup.daily_prompt");

	public static final Set<String> SUPPORTED_KEYS = Set.of(
			"wakeup.generic",
			"wakeup.thinking_of_you",
			"wakeup.new_moment",
			"wakeup.capsule_ready",
			"wakeup.daily_prompt",
			"wakeup.pairing_request");

	private final PushConfig config;
	private final PushRegistrationRepository repository;
	private final PushProvider pushProvider;
	private final Clock clock;
	private final int clientWakeupMaxPerMinute;
	private final Map<UUID, Deque<Long>> clientWakeupWindows = new ConcurrentHashMap<>();

	@Autowired
	public PushService(
			PushConfig config,
			PushRegistrationRepository repository,
			PushProvider pushProvider,
			Clock clock,
			@Value("${deepsky.push.client-wakeup-max-per-minute:5}") int clientWakeupMaxPerMinute) {
		this.config = config;
		this.repository = repository;
		this.pushProvider = pushProvider;
		this.clock = clock;
		this.clientWakeupMaxPerMinute = Math.max(1, clientWakeupMaxPerMinute);
	}

	public PushService(
			PushConfig config,
			PushRegistrationRepository repository,
			PushProvider pushProvider,
			Clock clock) {
		this(config, repository, pushProvider, clock, 5);
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
	public TokenStatus register(UUID deviceId, UUID coupleId, String fcmToken, String platform) {
		if (deviceId == null || coupleId == null || fcmToken == null || fcmToken.isBlank()) {
			throw new IllegalArgumentException("deviceId, coupleId, and fcmToken are required");
		}
		Instant now = clock.instant();
		String devIdStr = deviceId.toString();
		String coupleIdStr = coupleId.toString();
		String plat = (platform == null || platform.isBlank()) ? "android" : platform.trim();
		PushRegistrationEntity entity = repository.findByDeviceId(devIdStr)
				.orElseGet(() -> new PushRegistrationEntity(
						UUID.randomUUID(), devIdStr, coupleIdStr, fcmToken.trim(), plat, now));
		entity.setCoupleId(coupleIdStr);
		entity.setFcmToken(fcmToken.trim());
		entity.setUpdatedAt(now);
		return toStatus(repository.save(entity));
	}

	@Transactional
	public boolean unregisterDevice(UUID deviceId) {
		if (deviceId == null) {
			return false;
		}
		String devIdStr = deviceId.toString();
		Optional<PushRegistrationEntity> existing = repository.findByDeviceId(devIdStr);
		if (existing.isEmpty()) {
			return false;
		}
		repository.delete(existing.get());
		return true;
	}

	@Transactional
	public void unregisterCouple(UUID coupleId) {
		if (coupleId != null) {
			repository.deleteAllByCoupleId(coupleId.toString());
		}
	}

	@Transactional(readOnly = true)
	public Optional<TokenStatus> statusFor(UUID deviceId) {
		return repository.findByDeviceId(deviceId.toString()).map(this::toStatus);
	}

	@Async
	@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
	public void onPartnerWakeupRequested(PartnerWakeupRequestedEvent event) {
		try {
			dispatchPartnerWakeup(event.coupleId(), event.senderDeviceId(), event.localizationKey());
		} catch (RuntimeException ex) {
			log.warn("Post-commit partner wakeup failed for couple {}: {}", event.coupleId(), ex.getMessage());
		}
	}

	@Transactional
	public WakeupOutcome dispatchClientWakeup(UUID coupleId, UUID senderDeviceId, String localizationKey) {
		String key = (localizationKey == null || localizationKey.isBlank())
				? "wakeup.generic"
				: localizationKey.trim();
		if (!CLIENT_TRIGGERABLE_KEYS.contains(key)) {
			throw new IllegalArgumentException("Unsupported localizationKey: " + key);
		}
		consumeClientWakeupQuota(senderDeviceId);
		return dispatchPartnerWakeup(coupleId, senderDeviceId, key);
	}

	public void resetClientWakeupRateLimit() {
		clientWakeupWindows.clear();
	}

	private void consumeClientWakeupQuota(UUID senderDeviceId) {
		long now = clock.millis();
		long cutoff = now - WAKEUP_WINDOW_MILLIS;
		Deque<Long> timestamps = clientWakeupWindows.computeIfAbsent(senderDeviceId, k -> new ArrayDeque<>());
		synchronized (timestamps) {
			while (!timestamps.isEmpty() && timestamps.peekFirst() <= cutoff) {
				timestamps.pollFirst();
			}
			if (timestamps.size() >= clientWakeupMaxPerMinute) {
				long oldest = timestamps.peekFirst() != null ? timestamps.peekFirst() : now;
				long waitMs = Math.max(1000L, (oldest + WAKEUP_WINDOW_MILLIS) - now);
				long retryAfter = (waitMs + 999L) / 1000L;
				throw new RateLimitExceededException(
						"Too many partner wakeup requests; please wait before retrying.",
						retryAfter);
			}
			timestamps.addLast(now);
		}
	}

	@Transactional
	public WakeupOutcome dispatchPartnerWakeup(UUID coupleId, UUID senderDeviceId, String localizationKey) {
		String key = (localizationKey == null || localizationKey.isBlank())
				? "wakeup.generic"
				: localizationKey.trim();
		if (!SUPPORTED_KEYS.contains(key)) {
			throw new IllegalArgumentException("Unsupported localizationKey: " + key);
		}
		String senderIdStr = senderDeviceId.toString();
		List<PushRegistrationEntity> targets = repository
				.findAllByCoupleIdOrderByUpdatedAtDesc(coupleId.toString())
				.stream()
				.filter(row -> !senderIdStr.equals(row.getDeviceId()))
				.toList();

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
			} catch (RuntimeException ex) {
				// Never fail an encrypted sync write if FCM temporarily errors.
				log.warn("FCM wakeup delivery failed for device {}: {}", target.getDeviceId(), ex.getMessage());
			}
		}
		return new WakeupOutcome(key, targets.size(), delivered, evicted);
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
