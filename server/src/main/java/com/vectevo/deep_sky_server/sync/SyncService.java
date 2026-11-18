package com.vectevo.deep_sky_server.sync;

import com.vectevo.deep_sky_server.pairing.DeviceAuthLookup;
import com.vectevo.deep_sky_server.shared.DevicePrincipal;
import com.vectevo.deep_sky_server.shared.Ed25519SignatureVerifier;
import com.vectevo.deep_sky_server.shared.PartnerWakeupRequestedEvent;
import com.vectevo.deep_sky_server.shared.StaleKeyEpochException;
import com.vectevo.deep_sky_server.shared.StorageQuotaExceededException;
import java.time.Instant;
import java.util.Collections;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Opaque encrypted envelope storage, paginated retrieval, storage quotas,
 * and post-commit partner push wakeup dispatch (`SP-02`, `PR-M2-03`, `S-01`, `CA-07`, `CA-08`).
 */
@Service
public class SyncService {

	public static final int DEFAULT_PAGE_SIZE = 100;
	public static final int MAX_PAGE_SIZE = 200;

	private final EncryptedEnvelopeRepository envelopeRepository;
	private final ApplicationEventPublisher eventPublisher;
	private final DeviceAuthLookup deviceAuthLookup;
	private final long maxBlobBytes;
	private final long maxCoupleStorageBytes;

	public SyncService(
			EncryptedEnvelopeRepository envelopeRepository,
			ApplicationEventPublisher eventPublisher,
			long maxBlobBytes,
			long maxCoupleStorageBytes) {
		this(envelopeRepository, eventPublisher, null, maxBlobBytes, maxCoupleStorageBytes);
	}

	@Autowired
	public SyncService(
			EncryptedEnvelopeRepository envelopeRepository,
			ApplicationEventPublisher eventPublisher,
			DeviceAuthLookup deviceAuthLookup,
			@Value("${deepsky.quotas.max-blob-bytes:10485760}") long maxBlobBytes,
			@Value("${deepsky.quotas.max-couple-storage-bytes:1073741824}") long maxCoupleStorageBytes) {
		this.envelopeRepository = envelopeRepository;
		this.eventPublisher = eventPublisher;
		this.deviceAuthLookup = deviceAuthLookup;
		this.maxBlobBytes = maxBlobBytes;
		this.maxCoupleStorageBytes = maxCoupleStorageBytes;
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

	public record EnvelopePageView(
			List<EnvelopeView> items,
			long nextAfterSeq,
			boolean hasMore,
			int coupleKeyEpoch) {
		public EnvelopePageView(List<EnvelopeView> items, long nextAfterSeq, boolean hasMore) {
			this(items, nextAfterSeq, hasMore, 1);
		}
	}

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
		if (deviceAuthLookup != null) {
			int currentCoupleEpoch = Math.max(1, deviceAuthLookup.getCurrentKeyEpoch(principal.coupleId()));
			if (keyEpoch < currentCoupleEpoch) {
				throw new StaleKeyEpochException(currentCoupleEpoch);
			}
		}
		byte[] nonce = Ed25519SignatureVerifier.decodeBase64Url(nonceB64, 24, "nonceB64");
		byte[] ciphertext = Ed25519SignatureVerifier.decodeBase64UrlVariable(ciphertextB64, "ciphertextB64");
		if (ciphertext.length <= 16) {
			throw new IllegalArgumentException("ciphertextB64 too short");
		}
		long payloadBytes = (long) nonce.length + ciphertext.length;
		if (payloadBytes > maxBlobBytes) {
			throw new StorageQuotaExceededException(
					"ENVELOPE_TOO_LARGE", "Encrypted envelope exceeds maximum allowed size");
		}
		var existingOpt = envelopeRepository.findById(envelopeId);
		if (existingOpt.isPresent()) {
			EncryptedEnvelopeEntity existing = existingOpt.get();
			if (existing.getCoupleId().equals(principal.coupleId())) {
				return toView(existing);
			}
			return new EnvelopeView(
					envelopeId,
					principal.coupleId(),
					principal.deviceId(),
					0L,
					channel,
					keyEpoch,
					nonceB64,
					ciphertextB64,
					Instant.now());
		}
		long usedBytes = envelopeRepository.sumStoredBytesByCoupleId(principal.coupleId());
		if (usedBytes + payloadBytes > maxCoupleStorageBytes) {
			throw new StorageQuotaExceededException(
					"COUPLE_STORAGE_QUOTA_EXCEEDED", "Couple storage quota exceeded");
		}

		Instant now = Instant.now();
		int inserted = envelopeRepository.insertIfAbsent(
				envelopeId,
				principal.coupleId(),
				principal.deviceId(),
				channel,
				keyEpoch,
				nonce,
				ciphertext,
				now);
		if (inserted == 0) {
			EncryptedEnvelopeEntity raced = envelopeRepository.findById(envelopeId).orElseThrow();
			if (raced.getCoupleId().equals(principal.coupleId())) {
				return toView(raced);
			}
			return new EnvelopeView(
					envelopeId,
					principal.coupleId(),
					principal.deviceId(),
					0L,
					channel,
					keyEpoch,
					nonceB64,
					ciphertextB64,
					now);
		}

		// Reload to retrieve database-generated IDENTITY seq
		EncryptedEnvelopeEntity persisted = envelopeRepository.findById(envelopeId).orElseThrow();
		if ("EVENT".equals(channel)) {
			eventPublisher.publishEvent(new PartnerWakeupRequestedEvent(
					principal.coupleId(),
					principal.deviceId(),
					"wakeup.thinking_of_you"));
		}
		return toView(persisted);
	}

	@Transactional(readOnly = true)
	public EnvelopePageView listEnvelopes(DevicePrincipal principal, long afterSeq, int limit) {
		int clampedLimit = Math.max(1, Math.min(limit, MAX_PAGE_SIZE));
		List<EncryptedEnvelopeEntity> rows = envelopeRepository.findByCoupleIdAndSeqGreaterThanOrderBySeqAsc(
				principal.coupleId(),
				afterSeq,
				PageRequest.of(0, clampedLimit + 1));
		boolean hasMore = rows.size() > clampedLimit;
		List<EnvelopeView> items = (hasMore ? rows.subList(0, clampedLimit) : rows)
				.stream()
				.map(SyncService::toView)
				.toList();
		long nextAfterSeq = items.isEmpty() ? afterSeq : items.getLast().seq();
		int coupleKeyEpoch = deviceAuthLookup == null
				? 1
				: Math.max(1, deviceAuthLookup.getCurrentKeyEpoch(principal.coupleId()));
		return new EnvelopePageView(items, nextAfterSeq, hasMore, coupleKeyEpoch);
	}

	@Transactional(readOnly = true)
	public List<EnvelopeVisibilityRow> getVisibilityAudit(DevicePrincipal principal) {
		HexFormat hex = HexFormat.of();
		List<EncryptedEnvelopeEntity> latest = new java.util.ArrayList<>(
				envelopeRepository.findTop200ByCoupleIdOrderBySeqDesc(principal.coupleId()));
		Collections.reverse(latest);
		return latest.stream()
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
