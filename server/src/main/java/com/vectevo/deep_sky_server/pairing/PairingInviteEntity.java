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
@Table(name = "pairing_invites")
@Getter
@Setter
@NoArgsConstructor
public class PairingInviteEntity {

	@Id
	private UUID id;

	@Column(name = "couple_id", nullable = false)
	private UUID coupleId;

	@Column(name = "creator_device_id", nullable = false)
	private UUID creatorDeviceId;

	@Column(name = "token_hash", nullable = false, unique = true)
	private byte[] tokenHash;

	@Column(name = "invite_kind", nullable = false, length = 32)
	private String inviteKind;

	@Column(name = "expires_at", nullable = false)
	private Instant expiresAt;

	@Column(name = "accepted_at")
	private Instant acceptedAt;

	@Column(name = "accepted_device_id")
	private UUID acceptedDeviceId;
}
