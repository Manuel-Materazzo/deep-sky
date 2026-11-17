package com.vectevo.deep_sky_server.shared;

/**
 * Thrown when an envelope upload uses a keyEpoch older than the couple's active epoch (`CA-02`, `ADR-0012`).
 */
public class StaleKeyEpochException extends RuntimeException {

	private final int currentKeyEpoch;

	public StaleKeyEpochException(int currentKeyEpoch) {
		super("Envelope keyEpoch is older than couple active epoch " + currentKeyEpoch);
		this.currentKeyEpoch = currentKeyEpoch;
	}

	public int getCurrentKeyEpoch() {
		return currentKeyEpoch;
	}
}
