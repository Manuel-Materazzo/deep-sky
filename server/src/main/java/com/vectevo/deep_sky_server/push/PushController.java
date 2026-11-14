package com.vectevo.deep_sky_server.push;

import com.vectevo.deep_sky_server.push.PushDtos.ClientConfig;
import com.vectevo.deep_sky_server.push.PushDtos.RegisterTokenRequest;
import com.vectevo.deep_sky_server.push.PushDtos.SendWakeupRequest;
import com.vectevo.deep_sky_server.push.PushDtos.TokenStatus;
import com.vectevo.deep_sky_server.push.PushDtos.WakeupOutcome;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Endpoints for runtime Firebase config, FCM token registration, and test wakeups (SP-01).
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

	@PutMapping("/token")
	public TokenStatus registerToken(@RequestBody RegisterTokenRequest request) {
		return pushService.register(
				request.deviceId(),
				request.coupleId(),
				request.fcmToken(),
				request.platform());
	}

	@GetMapping("/token/{deviceId}")
	public ResponseEntity<TokenStatus> getTokenStatus(@PathVariable String deviceId) {
		return pushService.statusFor(deviceId)
				.map(ResponseEntity::ok)
				.orElseGet(() -> ResponseEntity.notFound().build());
	}

	@DeleteMapping("/token/{deviceId}")
	public ResponseEntity<Void> deleteToken(@PathVariable String deviceId) {
		return pushService.unregister(deviceId)
				? ResponseEntity.noContent().build()
				: ResponseEntity.notFound().build();
	}

	@PostMapping("/test-wakeup")
	public WakeupOutcome sendTestWakeup(@RequestBody SendWakeupRequest request) {
		return pushService.dispatchWakeup(
				request.deviceId(),
				request.coupleId(),
				request.localizationKey());
	}

	@ExceptionHandler(IllegalArgumentException.class)
	public ResponseEntity<Map<String, String>> handleBadArgument(IllegalArgumentException ex) {
		return ResponseEntity.badRequest().body(Map.of("error", ex.getMessage()));
	}
}
