package com.vectevo.deep_sky_server.sync;

import com.vectevo.deep_sky_server.shared.DevicePrincipal;
import java.util.List;
import org.springframework.context.annotation.Profile;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Non-production visibility audit endpoint for encrypted envelopes (`SP02-07`, `CA-08`).
 */
@RestController
@RequestMapping("/api/v1/sync")
@Profile({"dev", "audit", "test"})
public class SyncVisibilityController {

	private final SyncService syncService;

	public SyncVisibilityController(SyncService syncService) {
		this.syncService = syncService;
	}

	@GetMapping("/visibility")
	public List<SyncService.EnvelopeVisibilityRow> getVisibilityAudit(
			@AuthenticationPrincipal DevicePrincipal principal) {
		return syncService.getVisibilityAudit(principal);
	}
}
