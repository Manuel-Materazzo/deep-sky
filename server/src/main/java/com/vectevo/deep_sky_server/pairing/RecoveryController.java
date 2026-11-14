package com.vectevo.deep_sky_server.pairing;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.UUID;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * REST endpoints for zero-second-phone recovery via Ed25519 challenge-response (`SP02-05`, `S-06`).
 */
@RestController
@RequestMapping("/api/v1/recovery")
public class RecoveryController {

	private final PairingService pairingService;

	public RecoveryController(PairingService pairingService) {
		this.pairingService = pairingService;
	}

	public record ChallengeRequest(@NotBlank String recoveryAuthPublicKeyB64) {}

	public record CompleteRecoveryRequest(
			@NotNull UUID challengeId,
			@NotBlank String deviceLabel,
			@NotBlank String newDeviceAuthPublicKeyB64,
			@NotBlank String newDeviceKemPublicKeyB64,
			@NotBlank String recoverySignatureB64) {}

	@PostMapping("/challenges")
	public PairingService.RecoveryChallengeResult createChallenge(@Valid @RequestBody ChallengeRequest req) {
		return pairingService.createRecoveryChallenge(req.recoveryAuthPublicKeyB64());
	}

	@PostMapping("/complete")
	public PairingService.RecoveryCompleteResult completeRecovery(
			@Valid @RequestBody CompleteRecoveryRequest req) {
		return pairingService.completeRecovery(
				req.challengeId(),
				req.deviceLabel(),
				req.newDeviceAuthPublicKeyB64(),
				req.newDeviceKemPublicKeyB64(),
				req.recoverySignatureB64());
	}
}
