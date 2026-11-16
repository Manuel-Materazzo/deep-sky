package com.vectevo.deep_sky_server.shared;

/**
 * Thrown when an upload exceeds single-envelope or per-couple storage quotas (`CA-08`).
 */
public class StorageQuotaExceededException extends RuntimeException {

	private final String errorCode;

	public StorageQuotaExceededException(String errorCode, String message) {
		super(message);
		this.errorCode = errorCode;
	}

	public String getErrorCode() {
		return errorCode;
	}
}
