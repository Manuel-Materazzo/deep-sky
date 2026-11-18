package com.vectevo.deep_sky_server.shared;

/**
 * Thrown when a per-device authenticated endpoint throttle is exceeded (`CA-09`).
 */
public class RateLimitExceededException extends RuntimeException {

	private final long retryAfterSeconds;

	public RateLimitExceededException(String message, long retryAfterSeconds) {
		super(message);
		this.retryAfterSeconds = Math.max(1L, retryAfterSeconds);
	}

	public long getRetryAfterSeconds() {
		return retryAfterSeconds;
	}
}
