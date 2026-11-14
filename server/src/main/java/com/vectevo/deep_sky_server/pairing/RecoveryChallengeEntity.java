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
@Table(name = "recovery_challenges")
@Getter
@Setter
@NoArgsConstructor
public class RecoveryChallengeEntity {

	@Id
	private UUID id;

	@Column(name = "couple_id", nullable = false)
	private UUID coupleId;

	@Column(name = "nonce", nullable = false)
	private byte[] nonce;

	@Column(name = "expires_at", nullable = false)
	private Instant expiresAt;

	@Column(name = "used_at")
	private Instant usedAt;
}
