package com.vectevo.deep_sky_server.shared;

/**
 * Raised when revoking another approved device without providing an atomic epoch rotation bundle ({@code AU-10}).
 */
public class RotationRequiredException extends RuntimeException {
	public RotationRequiredException(String message) {
		super(message);
	}
}
