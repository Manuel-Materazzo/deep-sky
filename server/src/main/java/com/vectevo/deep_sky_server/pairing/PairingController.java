package com.vectevo.deep_sky_server.pairing;

import com.vectevo.deep_sky_server.shared.DevicePrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * REST endpoints for pairing invites, key delivery, enrollment, and device revocation (`SP-02`).
 */
@RestController
@RequestMapping("/api/v1/pairing")
public class PairingController {

	private final PairingService pairingService;

	public PairingController(PairingService pairingService) {
		this.pairingService = pairingService;
	}

	public record CreateInviteRequest(
			@NotBlank String deviceLabel,
			@NotBlank String deviceAuthPublicKeyB64,
			@NotBlank String deviceKemPublicKeyB64,
			@NotBlank String recoveryAuthPublicKeyB64) {}

	public record AcceptInviteRequest(
			@NotBlank String inviteToken,
			@NotBlank String deviceLabel,
			@NotBlank String deviceAuthPublicKeyB64,
			@NotBlank String deviceKemPublicKeyB64) {}

	public record InviteStatusRequest(@NotBlank String inviteToken) {}

	public record KeyDeliveryRequest(
			@NotNull UUID toDeviceId,
			@NotBlank String nonceB64,
			@NotBlank String ciphertextB64) {}

	public record UpdateDeviceLabelRequest(@NotBlank String deviceLabel) {}

	@PostMapping("/invites")
	@ResponseStatus(HttpStatus.CREATED)
	public PairingService.CreateInviteResult createInvite(@Valid @RequestBody CreateInviteRequest req) {
		return pairingService.createInitialInvite(
				req.deviceLabel(),
				req.deviceAuthPublicKeyB64(),
				req.deviceKemPublicKeyB64(),
				req.recoveryAuthPublicKeyB64());
	}

	@PostMapping("/invites/accept")
	public PairingService.AcceptInviteResult acceptInvite(
			@Valid @RequestBody AcceptInviteRequest req) {
		return pairingService.acceptInvite(
				req.inviteToken(),
				req.deviceLabel(),
				req.deviceAuthPublicKeyB64(),
				req.deviceKemPublicKeyB64());
	}

	@PostMapping("/invites/status")
	public PairingService.InviteStatusResult getInviteStatus(
			@AuthenticationPrincipal DevicePrincipal principal,
			@Valid @RequestBody InviteStatusRequest req) {
		return pairingService.getInviteStatus(principal, req.inviteToken());
	}

	@PostMapping("/enrollment-invites")
	@ResponseStatus(HttpStatus.CREATED)
	public PairingService.CreateInviteResult createEnrollmentInvite(
			@AuthenticationPrincipal DevicePrincipal principal) {
		return pairingService.createEnrollmentInvite(principal);
	}

	@PostMapping("/key-deliveries")
	@ResponseStatus(HttpStatus.CREATED)
	public void storeKeyDelivery(
			@AuthenticationPrincipal DevicePrincipal principal,
			@Valid @RequestBody KeyDeliveryRequest req) {
		pairingService.storeKeyDelivery(principal, req.toDeviceId(), req.nonceB64(), req.ciphertextB64());
	}

	@GetMapping("/key-deliveries/me")
	public PairingService.KeyDeliveryView fetchMyKeyDelivery(@AuthenticationPrincipal DevicePrincipal principal) {
		return pairingService.fetchPendingKeyDelivery(principal);
	}

	@GetMapping("/devices")
	public List<PairingService.DeviceView> listDevices(@AuthenticationPrincipal DevicePrincipal principal) {
		return pairingService.listDevices(principal);
	}

	@PatchMapping("/devices/me")
	public PairingService.DeviceView updateOwnDeviceLabel(
			@AuthenticationPrincipal DevicePrincipal principal,
			@Valid @RequestBody UpdateDeviceLabelRequest req) {
		return pairingService.updateOwnDeviceLabel(principal, req.deviceLabel());
	}

	@PostMapping("/devices/{deviceId}/revoke")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void revokeDevice(
			@AuthenticationPrincipal DevicePrincipal principal,
			@PathVariable UUID deviceId) {
		pairingService.revokeDevice(principal, deviceId);
	}

	@PostMapping("/unpair")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void unpairCouple(@AuthenticationPrincipal DevicePrincipal principal) {
		pairingService.unpairCouple(principal);
	}
}
