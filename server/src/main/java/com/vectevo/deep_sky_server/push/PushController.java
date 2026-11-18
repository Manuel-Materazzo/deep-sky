package com.vectevo.deep_sky_server.push;

import com.vectevo.deep_sky_server.push.PushDtos.ClientConfig;
import com.vectevo.deep_sky_server.push.PushDtos.RegisterTokenRequest;
import com.vectevo.deep_sky_server.push.PushDtos.SendWakeupRequest;
import com.vectevo.deep_sky_server.push.PushDtos.TokenStatus;
import com.vectevo.deep_sky_server.push.PushDtos.WakeupOutcome;
import com.vectevo.deep_sky_server.shared.DevicePrincipal;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Endpoints for runtime Firebase config (public) and device-authenticated FCM token registration
 * and partner wakeups (`SP-01`, `PR-M2-03`).
 */
@RestController
@RequestMapping("/api/v1/push")
public class PushController {

	private final PushService pushService;

	public PushController(PushService pushService) {
		this.pushService = pushService;
	}

	@GetMapping("/config")
	public ClientConfig getConfig() {
		return pushService.clientConfig();
	}

	@PostMapping("/register")
	public TokenStatus registerToken(
			@AuthenticationPrincipal DevicePrincipal principal,
			@Valid @RequestBody RegisterTokenRequest request) {
		return pushService.register(
				principal.deviceId(),
				principal.coupleId(),
				request.fcmToken(),
				request.platform());
	}

	@GetMapping("/register")
	public ResponseEntity<TokenStatus> getTokenStatus(@AuthenticationPrincipal DevicePrincipal principal) {
		return pushService.statusFor(principal.deviceId())
				.map(ResponseEntity::ok)
				.orElseGet(() -> ResponseEntity.notFound().build());
	}

	@DeleteMapping("/register")
	public ResponseEntity<Void> deleteToken(@AuthenticationPrincipal DevicePrincipal principal) {
		return pushService.unregisterDevice(principal.deviceId())
				? ResponseEntity.noContent().build()
				: ResponseEntity.notFound().build();
	}

	@PostMapping("/wakeup")
	public WakeupOutcome sendPartnerWakeup(
			@AuthenticationPrincipal DevicePrincipal principal,
			@RequestBody(required = false) SendWakeupRequest request) {
		String key = request != null ? request.localizationKey() : "wakeup.thinking_of_you";
		return pushService.dispatchClientWakeup(principal.coupleId(), principal.deviceId(), key);
	}
}
