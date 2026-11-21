package com.vectevo.deep_sky_server.content;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.MessageDigest;
import java.security.PublicKey;
import java.security.Signature;
import java.security.spec.X509EncodedKeySpec;
import java.util.Base64;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * Loads, defensively verifies, and serves signed Deep Sky content packs file-by-file
 * from the configured pack directory (`AR-09`, `TC-10`, `G5-07`, `S2-SRV-01`).
 *
 * <p>The client remains the cryptographic trust anchor (`G5-07`); server-side signature,
 * SHA-256, and path-traversal checks act as defense-in-depth against publishing mistakes.
 */
public class ContentPackStore {

	private static final Logger log = LoggerFactory.getLogger(ContentPackStore.class);
	private static final Pattern KEY_ID_PATTERN = Pattern.compile("^[a-z0-9][a-z0-9_-]{0,31}$");
	private static final Pattern SEMVER_PATTERN = Pattern.compile("^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)$");
	private static final Pattern SHA256_HEX_PATTERN = Pattern.compile("^[0-9a-f]{64}$");
	private static final byte[] ED25519_SPKI_PREFIX = new byte[] {
			0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00
	};

	private final ContentPackConfig config;
	private final ObjectMapper objectMapper;
	private final AtomicReference<LoadedPack> activePack = new AtomicReference<>();

	public record PackFileEntry(String relativePath, Path resolvedPath, String sha256, long sizeBytes) {}

	public record LoadedPack(
			String packId,
			String packVersion,
			String keyId,
			byte[] checksumsBytes,
			String checksumsEtag,
			byte[] signatureBytes,
			String signatureEtag,
			Map<String, PackFileEntry> files) {}

	public ContentPackStore(ContentPackConfig config, ObjectMapper objectMapper) {
		this.config = config;
		this.objectMapper = objectMapper;
		reload();
	}

	public Optional<LoadedPack> getActivePack() {
		return Optional.ofNullable(activePack.get());
	}

	/**
	 * Attempts to load and verify the active pack from disk. If verification fails,
	 * keeps any previously loaded valid pack intact and returns {@code false}.
	 */
	public boolean reload() {
		if (config.packsDir().isBlank()) {
			return false;
		}
		Path configuredRoot = Path.of(config.packsDir()).toAbsolutePath().normalize();
		if (!Files.isDirectory(configuredRoot)) {
			log.info("Content pack directory does not exist yet: {}", configuredRoot);
			return false;
		}

		Path packRoot = resolveActivePackRoot(configuredRoot);
		if (packRoot == null) {
			log.info("No pack-checksums.json found in {}", configuredRoot);
			return false;
		}

		try {
			LoadedPack verified = loadAndVerify(packRoot);
			activePack.set(verified);
			log.info("Loaded verified content pack {} v{} (keyId={}, {} files) from {}",
					verified.packId(), verified.packVersion(), verified.keyId(), verified.files().size(), packRoot);
			return true;
		} catch (Exception ex) {
			log.warn("Rejected content pack in {}: {}", packRoot, ex.getMessage());
			return false;
		}
	}

	private static Path resolveActivePackRoot(Path configuredRoot) {
		if (Files.isRegularFile(configuredRoot.resolve("pack-checksums.json"))) {
			return configuredRoot;
		}
		Path current = configuredRoot.resolve("current");
		if (Files.isDirectory(current) && Files.isRegularFile(current.resolve("pack-checksums.json"))) {
			return current;
		}
		return null;
	}

	private LoadedPack loadAndVerify(Path packRootDir) throws IOException, GeneralSecurityException {
		Path canonicalRoot = packRootDir.toRealPath();
		Path checksumsPath = resolveSafeChild(canonicalRoot, "pack-checksums.json");
		Path sigPath = resolveSafeChild(canonicalRoot, "pack-checksums.json.sig");

		if (!Files.isRegularFile(checksumsPath) || !Files.isRegularFile(sigPath)) {
			throw new IllegalStateException("Missing pack-checksums.json or pack-checksums.json.sig");
		}

		byte[] checksumsBytes = Files.readAllBytes(checksumsPath);
		byte[] sigBytes = Files.readAllBytes(sigPath);
		ParsedSignature parsedSig = parseSignature(sigBytes);

		// Defense-in-depth: if trusted keys are configured on server, verify signature BEFORE JSON parsing (G5-07).
		if (!config.trustedPublicKeys().isEmpty()) {
			String pubB64 = config.trustedPublicKeys().get(parsedSig.keyId());
			if (pubB64 == null || pubB64.isBlank()) {
				throw new SecurityException("Unknown content signing keyId: " + parsedSig.keyId());
			}
			verifyEd25519(checksumsBytes, parsedSig.signatureBytes(), parsePublicKey(pubB64));
		}

		JsonNode root = objectMapper.readTree(checksumsBytes);
		if (!root.isObject()) {
			throw new IllegalArgumentException("pack-checksums.json root must be an object");
		}

		String keyId = requireText(root, "keyId");
		if (!KEY_ID_PATTERN.matcher(keyId).matches() || !keyId.equals(parsedSig.keyId())) {
			throw new SecurityException("pack-checksums.json keyId does not match .sig envelope");
		}
		String packId = requireText(root, "packId");
		String packVersion = requireText(root, "packVersion");
		if (!SEMVER_PATTERN.matcher(packVersion).matches()) {
			throw new IllegalArgumentException("Invalid packVersion semver: " + packVersion);
		}
		int minAppProtocol = root.path("minAppProtocol").asInt(-1);
		if (minAppProtocol < 1) {
			throw new IllegalArgumentException("minAppProtocol must be >= 1");
		}

		JsonNode filesNode = root.get("files");
		if (filesNode == null || !filesNode.isObject() || !filesNode.has("manifest.json")) {
			throw new IllegalArgumentException("pack-checksums.json must list files including manifest.json");
		}

		Map<String, PackFileEntry> verifiedFiles = new LinkedHashMap<>();
		for (Map.Entry<String, JsonNode> entry : filesNode.properties()) {
			String relPath = entry.getKey();
			if (!isSafeRelativePath(relPath)) {
				throw new SecurityException("Unsafe relative file path in checksums: " + relPath);
			}
			JsonNode meta = entry.getValue();
			String expectedSha = requireText(meta, "sha256").toLowerCase();
			if (!SHA256_HEX_PATTERN.matcher(expectedSha).matches()) {
				throw new IllegalArgumentException("Invalid sha256 for " + relPath);
			}
			long expectedSize = meta.path("sizeBytes").asLong(-1L);
			if (expectedSize < 0) {
				throw new IllegalArgumentException("Invalid sizeBytes for " + relPath);
			}

			Path resolved = resolveSafeChild(canonicalRoot, relPath);
			if (!Files.isRegularFile(resolved)) {
				throw new IllegalStateException("Declared pack file missing: " + relPath);
			}
			long actualSize = Files.size(resolved);
			if (actualSize != expectedSize) {
				throw new SecurityException("Size mismatch for " + relPath + ": expected "
						+ expectedSize + ", actual " + actualSize);
			}
			String actualSha = sha256Hex(Files.readAllBytes(resolved));
			if (!actualSha.equals(expectedSha)) {
				throw new SecurityException("SHA-256 mismatch for " + relPath);
			}
			verifiedFiles.put(relPath, new PackFileEntry(relPath, resolved, actualSha, actualSize));
		}

		return new LoadedPack(
				packId,
				packVersion,
				keyId,
				checksumsBytes,
				sha256Hex(checksumsBytes),
				sigBytes,
				sha256Hex(sigBytes),
				Map.copyOf(verifiedFiles));
	}

	static boolean isSafeRelativePath(String raw) {
		if (raw == null || raw.isEmpty() || !raw.equals(raw.trim())) {
			return false;
		}
		if (raw.startsWith("/") || raw.contains("\\") || raw.contains(":") || raw.indexOf('\0') >= 0) {
			return false;
		}
		String[] segments = raw.split("/", -1);
		for (String seg : segments) {
			if (seg.isEmpty() || ".".equals(seg) || "..".equals(seg)) {
				return false;
			}
		}
		return true;
	}

	private static Path resolveSafeChild(Path canonicalRoot, String relativePath) throws IOException {
		if (!isSafeRelativePath(relativePath)) {
			throw new SecurityException("Unsafe path: " + relativePath);
		}
		Path candidate = canonicalRoot.resolve(relativePath).normalize();
		if (!candidate.startsWith(canonicalRoot)) {
			throw new SecurityException("Path escapes pack root: " + relativePath);
		}
		if (Files.exists(candidate)) {
			Path real = candidate.toRealPath();
			if (!real.startsWith(canonicalRoot)) {
				throw new SecurityException("Symlink escapes pack root: " + relativePath);
			}
			return real;
		}
		return candidate;
	}

	private record ParsedSignature(String keyId, byte[] signatureBytes) {}

	private static ParsedSignature parseSignature(byte[] raw) {
		String text = new String(raw, StandardCharsets.UTF_8).trim();
		int colon = text.indexOf(':');
		String keyId;
		String sigB64;
		if (colon > 0) {
			keyId = text.substring(0, colon).trim();
			sigB64 = text.substring(colon + 1).trim();
		} else {
			keyId = "v1";
			sigB64 = text;
		}
		if (!KEY_ID_PATTERN.matcher(keyId).matches()) {
			throw new IllegalArgumentException("Invalid keyId in .sig file");
		}
		byte[] decoded = Base64.getDecoder().decode(sigB64);
		if (decoded.length != 64) {
			throw new IllegalArgumentException("Ed25519 signature must be 64 bytes");
		}
		return new ParsedSignature(keyId, decoded);
	}

	private static PublicKey parsePublicKey(String encodedB64) throws GeneralSecurityException {
		byte[] raw = Base64.getDecoder().decode(encodedB64.replaceAll("\\s+", ""));
		byte[] spki;
		if (raw.length == 44) {
			spki = raw;
		} else if (raw.length == 32) {
			spki = new byte[44];
			System.arraycopy(ED25519_SPKI_PREFIX, 0, spki, 0, ED25519_SPKI_PREFIX.length);
			System.arraycopy(raw, 0, spki, ED25519_SPKI_PREFIX.length, 32);
		} else {
			throw new IllegalArgumentException("Ed25519 public key must be 32 raw bytes or 44-byte X.509 SPKI");
		}
		return KeyFactory.getInstance("Ed25519").generatePublic(new X509EncodedKeySpec(spki));
	}

	private static void verifyEd25519(byte[] payload, byte[] sigBytes, PublicKey publicKey)
			throws GeneralSecurityException {
		Signature verifier = Signature.getInstance("Ed25519");
		verifier.initVerify(publicKey);
		verifier.update(payload);
		if (!verifier.verify(sigBytes)) {
			throw new SecurityException("Ed25519 signature verification failed for pack-checksums.json");
		}
	}

	private static String requireText(JsonNode node, String field) {
		JsonNode child = node.get(field);
		if (child == null || !child.isString() || child.asString().isBlank()) {
			throw new IllegalArgumentException("Missing or blank field: " + field);
		}
		return child.asString().trim();
	}

	private static String sha256Hex(byte[] bytes) {
		try {
			return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
		} catch (GeneralSecurityException ex) {
			throw new IllegalStateException(ex);
		}
	}
}
