package com.vectevo.deep_sky_server.pairing;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.io.Serializable;
import java.time.Instant;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "request_nonces")
@Getter
@Setter
@NoArgsConstructor
public class RequestNonceEntity {

	@EmbeddedId
	private NonceId id;

	@Column(name = "expires_at", nullable = false)
	private Instant expiresAt;

	@Embeddable
	@Getter
	@Setter
	@NoArgsConstructor
	@AllArgsConstructor
	@EqualsAndHashCode
	public static class NonceId implements Serializable {
		@Column(name = "device_id", nullable = false)
		private UUID deviceId;

		@Column(name = "nonce", nullable = false, length = 128)
		private String nonce;
	}
}
