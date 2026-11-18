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
@Table(name = "devices")
@Getter
@Setter
@NoArgsConstructor
public class DeviceEntity {

	@Id
	private UUID id;

	@Column(name = "couple_id", nullable = false)
	private UUID coupleId;

	@Column(name = "label", nullable = false, length = 64)
	private String label;

	@Column(name = "auth_public_key", nullable = false)
	private byte[] authPublicKey;

	@Column(name = "kem_public_key", nullable = false)
	private byte[] kemPublicKey;

	@Column(name = "enrolled_via", nullable = false, length = 32)
	private String enrolledVia;

	@Column(name = "created_at", nullable = false)
	private Instant createdAt;

	@Column(name = "approved_at")
	private Instant approvedAt;

	@Column(name = "revoked_at")
	private Instant revokedAt;
}
