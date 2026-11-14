package com.vectevo.deep_sky_server.pairing;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Public boundary exposed by `pairing` for `config.DeviceAuthFilter` (`ADR-0004`).
 */
@Service
public class DeviceAuthLookup {

	private final DeviceRepository deviceRepository;
	private final CoupleRepository coupleRepository;
	private final RequestNonceRepository requestNonceRepository;

	public DeviceAuthLookup(
			DeviceRepository deviceRepository,
			CoupleRepository coupleRepository,
			RequestNonceRepository requestNonceRepository) {
		this.deviceRepository = deviceRepository;
		this.coupleRepository = coupleRepository;
		this.requestNonceRepository = requestNonceRepository;
	}

	public record ActiveDeviceKey(UUID coupleId, UUID deviceId, byte[] authPublicKey) {}

	@Transactional(readOnly = true)
	public Optional<ActiveDeviceKey> findActiveDevice(UUID deviceId) {
		return deviceRepository.findById(deviceId)
				.filter(device -> device.getRevokedAt() == null)
				.flatMap(device -> coupleRepository.findById(device.getCoupleId())
						.filter(couple -> couple.getUnpairedAt() == null)
						.map(couple -> new ActiveDeviceKey(
								device.getCoupleId(), device.getId(), device.getAuthPublicKey())));
	}

	@Transactional
	public boolean consumeNonceIfUnused(UUID deviceId, String nonce, Instant expiresAt) {
		requestNonceRepository.deleteExpired(Instant.now());
		return requestNonceRepository.insertIfAbsent(deviceId, nonce, expiresAt) == 1;
	}
}
