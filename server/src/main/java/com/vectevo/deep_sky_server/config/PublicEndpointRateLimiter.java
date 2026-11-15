package com.vectevo.deep_sky_server.config;

import java.time.Clock;
import java.time.Duration;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * In-memory per-IP sliding-window rate limiter for public pairing and recovery endpoints (`PR-M2-02`, `G5-03`).
 */
@Component
public class PublicEndpointRateLimiter {

	private static final int MAX_TRACKED_KEYS = 10_000;

	private final Map<String, Deque<Long>> windows = new ConcurrentHashMap<>();
	private final Clock clock;
	private final long windowMillis;
	private final int invitesMaxPerWindow;
	private final int inviteRedeemMaxPerWindow;
	private final int recoveryMaxPerWindow;

	@Autowired
	public PublicEndpointRateLimiter(
			@Value("${deepsky.rate-limit.window-seconds:60}") int windowSeconds,
			@Value("${deepsky.rate-limit.invites-max:20}") int invitesMaxPerWindow,
			@Value("${deepsky.rate-limit.invite-redeem-max:5}") int inviteRedeemMaxPerWindow,
			@Value("${deepsky.rate-limit.recovery-max:10}") int recoveryMaxPerWindow) {
		this(
				Clock.systemUTC(),
				Duration.ofSeconds(Math.max(1, windowSeconds)),
				invitesMaxPerWindow,
				inviteRedeemMaxPerWindow,
				recoveryMaxPerWindow);
	}

	public PublicEndpointRateLimiter(
			Clock clock,
			Duration window,
			int invitesMaxPerWindow,
			int recoveryMaxPerWindow) {
		this(clock, window, invitesMaxPerWindow, 5, recoveryMaxPerWindow);
	}

	public PublicEndpointRateLimiter(
			Clock clock,
			Duration window,
			int invitesMaxPerWindow,
			int inviteRedeemMaxPerWindow,
			int recoveryMaxPerWindow) {
		this.clock = clock;
		this.windowMillis = Math.max(1000L, window.toMillis());
		this.invitesMaxPerWindow = Math.max(1, invitesMaxPerWindow);
		this.inviteRedeemMaxPerWindow = Math.max(1, inviteRedeemMaxPerWindow);
		this.recoveryMaxPerWindow = Math.max(1, recoveryMaxPerWindow);
	}

	public enum RouteGroup {
		INVITES,
		INVITE_REDEEM,
		RECOVERY
	}

	public record Decision(boolean allowed, long retryAfterSeconds) {}

	public Decision tryConsume(String clientKey, RouteGroup group) {
		long now = clock.millis();
		long cutoff = now - windowMillis;
		int maxAllowed = switch (group) {
			case INVITES -> invitesMaxPerWindow;
			case INVITE_REDEEM -> inviteRedeemMaxPerWindow;
			case RECOVERY -> recoveryMaxPerWindow;
		};
		String bucketKey = group.name() + ":" + (clientKey == null || clientKey.isBlank() ? "unknown" : clientKey);

		if (windows.size() > MAX_TRACKED_KEYS) {
			windows.entrySet().removeIf(entry -> {
				synchronized (entry.getValue()) {
					prune(entry.getValue(), cutoff);
					return entry.getValue().isEmpty();
				}
			});
		}

		Deque<Long> timestamps = windows.computeIfAbsent(bucketKey, k -> new ArrayDeque<>());
		synchronized (timestamps) {
			prune(timestamps, cutoff);
			if (timestamps.size() >= maxAllowed) {
				long oldest = timestamps.peekFirst() != null ? timestamps.peekFirst() : now;
				long waitMs = Math.max(1000L, (oldest + windowMillis) - now);
				long retryAfter = (waitMs + 999L) / 1000L;
				return new Decision(false, retryAfter);
			}
			timestamps.addLast(now);
			return new Decision(true, 0);
		}
	}

	public void reset() {
		windows.clear();
	}

	private static void prune(Deque<Long> timestamps, long cutoff) {
		while (!timestamps.isEmpty() && timestamps.peekFirst() <= cutoff) {
			timestamps.pollFirst();
		}
	}
}
