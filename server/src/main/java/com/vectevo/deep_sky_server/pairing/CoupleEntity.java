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
@Table(name = "couples")
@Getter
@Setter
@NoArgsConstructor
public class CoupleEntity {

	@Id
	private UUID id;

	@Column(name = "recovery_auth_public_key", nullable = false, unique = true)
	private byte[] recoveryAuthPublicKey;

	@Column(name = "created_at", nullable = false)
	private Instant createdAt;

	@Column(name = "unpaired_at")
	private Instant unpairedAt;
}
