package com.vectevo.deep_sky_server.shared;

import java.time.Clock;
import java.time.Duration;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Thread-safe bounded in-memory sliding-window limiter keyed by an arbitrary string identifier.
 */
public final class SlidingWindowLimiter {

	private static final int MAX_TRACKED_KEYS = 10_000;

	public record Decision(boolean allowed, long retryAfterSeconds) {}

	private final Map<String, Deque<Long>> windows = new ConcurrentHashMap<>();
	private final Clock clock;
	private final long windowMillis;
	private final int maxAttemptsPerWindow;

	public SlidingWindowLimiter(Clock clock, Duration window, int maxAttemptsPerWindow) {
		this.clock = clock;
		this.windowMillis = Math.max(1000L, window.toMillis());
		this.maxAttemptsPerWindow = Math.max(1, maxAttemptsPerWindow);
	}

	public Decision tryConsume(String key) {
		long now = clock.millis();
		long cutoff = now - windowMillis;

		if (windows.size() > MAX_TRACKED_KEYS) {
			windows.entrySet().removeIf(entry -> {
				synchronized (entry.getValue()) {
					prune(entry.getValue(), cutoff);
					return entry.getValue().isEmpty();
				}
			});
		}

		String safeKey = (key == null || key.isBlank()) ? "unknown" : key;
		Deque<Long> timestamps = windows.computeIfAbsent(safeKey, k -> new ArrayDeque<>());
		synchronized (timestamps) {
			prune(timestamps, cutoff);
			if (timestamps.size() >= maxAttemptsPerWindow) {
				long oldest = timestamps.peekFirst() != null ? timestamps.peekFirst() : now;
				long waitMs = Math.max(1000L, (oldest + windowMillis) - now);
				long retryAfter = (waitMs + 999L) / 1000L;
				return new Decision(false, retryAfter);
			}
			timestamps.addLast(now);
			return new Decision(true, 0);
		}
	}

	private static void prune(Deque<Long> timestamps, long cutoff) {
		while (!timestamps.isEmpty() && timestamps.peekFirst() <= cutoff) {
			timestamps.removeFirst();
		}
	}
}
