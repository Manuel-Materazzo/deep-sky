package com.vectevo.deep_sky_server.sync;

import com.vectevo.deep_sky_server.shared.DevicePrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * REST endpoints for uploading and syncing opaque encrypted envelopes (`SP02-03`, `S-01`).
 */
@RestController
@RequestMapping("/api/v1/sync")
public class SyncController {

	private final SyncService syncService;

	public SyncController(SyncService syncService) {
		this.syncService = syncService;
	}

	public record UploadEnvelopeRequest(
			@NotNull UUID envelopeId,
			@NotBlank String channel,
			@Min(1) int keyEpoch,
			@NotBlank String nonceB64,
			@NotBlank String ciphertextB64) {}

	@PostMapping("/envelopes")
	@ResponseStatus(HttpStatus.CREATED)
	public SyncService.EnvelopeView uploadEnvelope(
			@AuthenticationPrincipal DevicePrincipal principal,
			@Valid @RequestBody UploadEnvelopeRequest req) {
		return syncService.storeEnvelope(
				principal,
				req.envelopeId(),
				req.channel(),
				req.keyEpoch(),
				req.nonceB64(),
				req.ciphertextB64());
	}

	@GetMapping("/envelopes")
	public SyncService.EnvelopePageView listEnvelopes(
			@AuthenticationPrincipal DevicePrincipal principal,
			@RequestParam(defaultValue = "0") long afterSeq,
			@RequestParam(defaultValue = "100") int limit) {
		return syncService.listEnvelopes(principal, afterSeq, limit);
	}
}
