package com.vectevo.deep_sky_server.shared;

import java.time.Instant;
import java.util.NoSuchElementException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

/**
 * Uniform JSON error mapping across backend modules (`SRV-01`).
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

	@ExceptionHandler(IllegalArgumentException.class)
	public ResponseEntity<ApiError> handleBadRequest(IllegalArgumentException ex) {
		return ResponseEntity.badRequest()
				.body(new ApiError("BAD_REQUEST", ex.getMessage(), Instant.now()));
	}

	@ExceptionHandler(MethodArgumentNotValidException.class)
	public ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException ex) {
		String msg = ex.getBindingResult().getFieldErrors().stream()
				.findFirst()
				.map(fe -> fe.getField() + ": " + fe.getDefaultMessage())
				.orElse("Validation failed");
		return ResponseEntity.badRequest()
				.body(new ApiError("VALIDATION_ERROR", msg, Instant.now()));
	}

	@ExceptionHandler(SecurityException.class)
	public ResponseEntity<ApiError> handleUnauthorized(SecurityException ex) {
		return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
				.body(new ApiError("UNAUTHORIZED", ex.getMessage(), Instant.now()));
	}

	@ExceptionHandler(NoSuchElementException.class)
	public ResponseEntity<ApiError> handleNotFound(NoSuchElementException ex) {
		return ResponseEntity.status(HttpStatus.NOT_FOUND)
				.body(new ApiError("NOT_FOUND", ex.getMessage(), Instant.now()));
	}

	@ExceptionHandler(IllegalStateException.class)
	public ResponseEntity<ApiError> handleConflict(IllegalStateException ex) {
		return ResponseEntity.status(HttpStatus.CONFLICT)
				.body(new ApiError("CONFLICT", ex.getMessage(), Instant.now()));
	}

	@ExceptionHandler(ResponseStatusException.class)
	public ResponseEntity<ApiError> handleStatus(ResponseStatusException ex) {
		return ResponseEntity.status(ex.getStatusCode())
				.body(new ApiError("ERROR", ex.getReason() != null ? ex.getReason() : ex.getMessage(), Instant.now()));
	}
}
