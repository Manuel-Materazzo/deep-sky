package com.vectevo.deep_sky_server.pairing;

import com.vectevo.deep_sky_server.shared.DevicePrincipal;
import org.springframework.context.annotation.Profile;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Non-production visibility audit endpoint for pairing state (`SP02-07`, `CA-08`).
 */
@RestController
@RequestMapping("/api/v1/pairing")
@Profile({"dev", "audit", "test"})
public class PairingVisibilityController {

	private final PairingService pairingService;

	public PairingVisibilityController(PairingService pairingService) {
		this.pairingService = pairingService;
	}

	@GetMapping("/visibility")
	public PairingService.PairingVisibilityAudit getVisibilityAudit(
			@AuthenticationPrincipal DevicePrincipal principal) {
		return pairingService.getVisibilityAudit(principal);
	}
}
