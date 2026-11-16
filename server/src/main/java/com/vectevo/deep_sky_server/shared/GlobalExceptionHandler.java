package com.vectevo.deep_sky_server.shared;

import java.time.Instant;
import java.util.NoSuchElementException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

/**
 * Uniform JSON error mapping across backend modules (`SRV-01`, `CA-13`).
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

	private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

	@ExceptionHandler(IllegalArgumentException.class)
	public ResponseEntity<ApiError> handleBadRequest(IllegalArgumentException ex) {
		log.debug("Rejected bad request: {}", ex.getMessage());
		return ResponseEntity.badRequest()
				.body(new ApiError("BAD_REQUEST", "Invalid request", Instant.now()));
	}

	@ExceptionHandler(HttpMessageNotReadableException.class)
	public ResponseEntity<ApiError> handleUnreadable(HttpMessageNotReadableException ex) {
		log.debug("Rejected malformed JSON body: {}", ex.getMessage());
		return ResponseEntity.badRequest()
				.body(new ApiError("BAD_REQUEST", "Invalid request payload", Instant.now()));
	}

	@ExceptionHandler(MethodArgumentNotValidException.class)
	public ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException ex) {
		String field = ex.getBindingResult().getFieldErrors().stream()
				.findFirst()
				.map(fe -> fe.getField() + ": validation failed")
				.orElse("Validation failed");
		return ResponseEntity.badRequest()
				.body(new ApiError("VALIDATION_ERROR", field, Instant.now()));
	}

	@ExceptionHandler(SecurityException.class)
	public ResponseEntity<ApiError> handleUnauthorized(SecurityException ex) {
		log.debug("Unauthorized request: {}", ex.getMessage());
		return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
				.body(new ApiError("UNAUTHORIZED", "Authentication failed", Instant.now()));
	}

	@ExceptionHandler(NoSuchElementException.class)
	public ResponseEntity<ApiError> handleNotFound(NoSuchElementException ex) {
		log.debug("Resource not found: {}", ex.getMessage());
		return ResponseEntity.status(HttpStatus.NOT_FOUND)
				.body(new ApiError("NOT_FOUND", "Resource not found", Instant.now()));
	}

	@ExceptionHandler(NoResourceFoundException.class)
	public ResponseEntity<ApiError> handleNoResource(NoResourceFoundException ex) {
		return ResponseEntity.status(HttpStatus.NOT_FOUND)
				.body(new ApiError("NOT_FOUND", "Resource not found", Instant.now()));
	}

	@ExceptionHandler(HttpRequestMethodNotSupportedException.class)
	public ResponseEntity<ApiError> handleMethodNotAllowed(HttpRequestMethodNotSupportedException ex) {
		return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED)
				.body(new ApiError("METHOD_NOT_ALLOWED", "Method not allowed", Instant.now()));
	}

	@ExceptionHandler(IllegalStateException.class)
	public ResponseEntity<ApiError> handleConflict(IllegalStateException ex) {
		log.debug("Request conflict: {}", ex.getMessage());
		return ResponseEntity.status(HttpStatus.CONFLICT)
				.body(new ApiError("CONFLICT", "Request could not be completed", Instant.now()));
	}

	@ExceptionHandler(ResponseStatusException.class)
	public ResponseEntity<ApiError> handleStatus(ResponseStatusException ex) {
		return ResponseEntity.status(ex.getStatusCode())
				.body(new ApiError("ERROR", "Request failed", Instant.now()));
	}

	@ExceptionHandler(StorageQuotaExceededException.class)
	public ResponseEntity<ApiError> handleQuotaExceeded(StorageQuotaExceededException ex) {
		return ResponseEntity.status(413)
				.body(new ApiError(ex.getErrorCode(), ex.getMessage(), Instant.now()));
	}

	@ExceptionHandler(RateLimitExceededException.class)
	public ResponseEntity<ApiError> handleRateLimited(RateLimitExceededException ex) {
		return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
				.header("Retry-After", Long.toString(ex.getRetryAfterSeconds()))
				.body(new ApiError("RATE_LIMITED", ex.getMessage(), Instant.now()));
	}

	@ExceptionHandler(Exception.class)
	public ResponseEntity<ApiError> handleUnexpected(Exception ex) {
		log.error("Unhandled server exception", ex);
		return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
				.body(new ApiError("INTERNAL_ERROR", "An unexpected error occurred", Instant.now()));
	}
}
