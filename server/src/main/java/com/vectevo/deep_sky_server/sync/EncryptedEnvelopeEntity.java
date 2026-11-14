package com.vectevo.deep_sky_server.sync;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "encrypted_envelopes")
@Getter
@Setter
@NoArgsConstructor
public class EncryptedEnvelopeEntity {

	@Id
	private UUID id;

	@Column(name = "couple_id", nullable = false)
	private UUID coupleId;

	@Column(name = "sender_device_id", nullable = false)
	private UUID senderDeviceId;

	@Column(name = "seq", insertable = false, updatable = false)
	private Long seq;

	@Column(name = "channel", nullable = false, length = 16)
	private String channel;

	@Column(name = "key_epoch", nullable = false)
	private int keyEpoch;

	@Column(name = "nonce", nullable = false)
	private byte[] nonce;

	@Column(name = "ciphertext", nullable = false)
	private byte[] ciphertext;

	@Column(name = "created_at", nullable = false)
	private Instant createdAt;
}
