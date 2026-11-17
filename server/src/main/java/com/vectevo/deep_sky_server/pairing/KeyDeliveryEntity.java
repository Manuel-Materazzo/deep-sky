package com.vectevo.deep_sky_server.pairing;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "key_deliveries")
@Getter
@Setter
@NoArgsConstructor
public class KeyDeliveryEntity {

	@Id
	private UUID id;

	@Column(name = "couple_id", nullable = false)
	private UUID coupleId;

	@Column(name = "from_device_id", nullable = false)
	private UUID fromDeviceId;

	@Column(name = "to_device_id", nullable = false)
	private UUID toDeviceId;

	@Column(name = "nonce", nullable = false)
	private byte[] nonce;

	@Column(name = "ciphertext", nullable = false)
	private byte[] ciphertext;

	@Column(name = "created_at", nullable = false)
	private Instant createdAt;

	@Column(name = "delivered_at")
	private Instant deliveredAt;

	@Column(name = "delivery_kind", nullable = false)
	private String deliveryKind = "PAIRING_SEED";

	@Column(name = "key_epoch", nullable = false)
	private int keyEpoch = 1;
}
