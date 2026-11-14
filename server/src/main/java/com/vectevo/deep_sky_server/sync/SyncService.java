package com.vectevo.deep_sky_server.sync;

import com.vectevo.deep_sky_server.shared.DevicePrincipal;
import com.vectevo.deep_sky_server.shared.Ed25519SignatureVerifier;
import java.time.Instant;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Opaque encrypted envelope storage and retrieval (`SP-02`, `S-01`).
 */
@Service
public class SyncService {

	private final EncryptedEnvelopeRepository envelopeRepository;

	public SyncService(EncryptedEnvelopeRepository envelopeRepository) {
		this.envelopeRepository = envelopeRepository;
	}

	public record EnvelopeView(
			UUID envelopeId,
			UUID coupleId,
			UUID senderDeviceId,
			long seq,
			String channel,
			int keyEpoch,
			String nonceB64,
			String ciphertextB64,
			Instant createdAtServer) {}

	public record EnvelopeVisibilityRow(
			UUID id,
			UUID coupleId,
			UUID senderDeviceId,
			long seq,
			String channel,
			int keyEpoch,
			String nonceHex,
			int ciphertextBytes,
			String ciphertextHexPreview,
			Instant createdAt) {}

	@Transactional
	public EnvelopeView storeEnvelope(
			DevicePrincipal principal,
			UUID envelopeId,
			String channel,
			int keyEpoch,
			String nonceB64,
			String ciphertextB64) {
		if (!"EVENT".equals(channel) && !"SNAPSHOT".equals(channel)) {
			throw new IllegalArgumentException("channel must be EVENT or SNAPSHOT");
		}
		if (keyEpoch < 1) {
			throw new IllegalArgumentException("keyEpoch must be >= 1");
		}
		byte[] nonce = Ed25519SignatureVerifier.decodeBase64Url(nonceB64, 24, "nonceB64");
		byte[] ciphertext = Ed25519SignatureVerifier.decodeBase64UrlVariable(ciphertextB64, "ciphertextB64");
		if (ciphertext.length <= 16) {
			throw new IllegalArgumentException("ciphertextB64 too short");
		}
		if (envelopeRepository.existsById(envelopeId)) {
			EncryptedEnvelopeEntity existing = envelopeRepository.findById(envelopeId).orElseThrow();
			if (!existing.getCoupleId().equals(principal.coupleId())) {
				throw new IllegalStateException("Envelope ID conflict");
			}
			return toView(existing);
		}

		EncryptedEnvelopeEntity entity = new EncryptedEnvelopeEntity();
		entity.setId(envelopeId);
		entity.setCoupleId(principal.coupleId());
		entity.setSenderDeviceId(principal.deviceId());
		entity.setChannel(channel);
		entity.setKeyEpoch(keyEpoch);
		entity.setNonce(nonce);
		entity.setCiphertext(ciphertext);
		entity.setCreatedAt(Instant.now());
		envelopeRepository.saveAndFlush(entity);

		// Reload to retrieve database-generated IDENTITY seq
		EncryptedEnvelopeEntity persisted = envelopeRepository.findById(envelopeId).orElseThrow();
		return toView(persisted);
	}

	@Transactional(readOnly = true)
	public List<EnvelopeView> listEnvelopes(DevicePrincipal principal, long afterSeq) {
		return envelopeRepository
				.findAllByCoupleIdAndSeqGreaterThanOrderBySeqAsc(principal.coupleId(), afterSeq)
				.stream()
				.map(SyncService::toView)
				.toList();
	}

	@Transactional(readOnly = true)
	public List<EnvelopeVisibilityRow> getVisibilityAudit(DevicePrincipal principal) {
		HexFormat hex = HexFormat.of();
		return envelopeRepository.findAllByCoupleIdOrderBySeqAsc(principal.coupleId()).stream()
				.map(e -> new EnvelopeVisibilityRow(
						e.getId(),
						e.getCoupleId(),
						e.getSenderDeviceId(),
						e.getSeq() != null ? e.getSeq() : 0L,
						e.getChannel(),
						e.getKeyEpoch(),
						hex.formatHex(e.getNonce()),
						e.getCiphertext().length,
						hex.formatHex(e.getCiphertext(), 0, Math.min(24, e.getCiphertext().length)),
						e.getCreatedAt()))
				.toList();
	}

	private static EnvelopeView toView(EncryptedEnvelopeEntity e) {
		return new EnvelopeView(
				e.getId(),
				e.getCoupleId(),
				e.getSenderDeviceId(),
				e.getSeq() != null ? e.getSeq() : 0L,
				e.getChannel(),
				e.getKeyEpoch(),
				Ed25519SignatureVerifier.encodeBase64Url(e.getNonce()),
				Ed25519SignatureVerifier.encodeBase64Url(e.getCiphertext()),
				e.getCreatedAt());
	}
}
