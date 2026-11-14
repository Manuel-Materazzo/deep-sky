package com.vectevo.deep_sky_server.shared;

import java.time.Instant;

/** Standard error payload returned by Deep Sky backend endpoints. */
public record ApiError(
		String code,
		String message,
		Instant timestamp
) {}
