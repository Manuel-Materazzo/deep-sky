package com.vectevo.deep_sky_server.content;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.MessageDigest;
import java.security.Signature;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import tools.jackson.databind.ObjectMapper;

/**
 * Verifies file-by-file content pack serving, conditional ETag caching, Ed25519
 * defense-in-depth verification, and path traversal protection (`S2-SRV-01`, `G5-07`).
 */
class ContentPackStoreAndControllerTest {

	private final ObjectMapper objectMapper = new ObjectMapper();

	@TempDir
	Path tempDir;

	@Test
	void servesSignedPackFileByFileWithEtagNoCachePathAndImmutableBlobs() throws Exception {
		KeyPair kp = generateEd25519();
		String pubB64 = Base64.getEncoder().encodeToString(kp.getPublic().getEncoded());

		byte[] manifestBytes = "{\"packId\":\"deep-sky-home-v1\"}".getBytes(StandardCharsets.UTF_8);
		byte[] floorBytes = new byte[] {(byte) 0x89, 'P', 'N', 'G', 1, 2, 3, 4};

		Path packDir = writeSignedPack(
				tempDir.resolve("pack_v1"),
				kp,
				"v1",
				"1.0.0",
				Map.of("manifest.json", manifestBytes, "assets/floor.png", floorBytes));

		ContentPackStore store = new ContentPackStore(
				new ContentPackConfig(packDir.toString(), "1.0.0", Map.of("v1", pubB64)),
				objectMapper);
		assertThat(store.getActivePack()).isPresent();

		MockMvc mvc = MockMvcBuilders.standaloneSetup(new ContentPackController(store)).build();

		// 1) Checksums endpoint with ETag and 304 Not Modified
		var checksumsResult = mvc.perform(get("/api/v1/content/pack/checksums"))
				.andExpect(status().isOk())
				.andExpect(content().contentType(MediaType.APPLICATION_JSON))
				.andExpect(header().exists(HttpHeaders.ETAG))
				.andExpect(header().string(HttpHeaders.CACHE_CONTROL, "no-cache"))
				.andReturn();
		String checksumsEtag = checksumsResult.getResponse().getHeader(HttpHeaders.ETAG);

		mvc.perform(get("/api/v1/content/pack/checksums").header(HttpHeaders.IF_NONE_MATCH, checksumsEtag))
				.andExpect(status().isNotModified());

		// 2) Signature endpoint
		mvc.perform(get("/api/v1/content/pack/checksums.sig"))
				.andExpect(status().isOk())
				.andExpect(content().contentTypeCompatibleWith(MediaType.TEXT_PLAIN))
				.andExpect(content().string(org.hamcrest.Matchers.startsWith("v1:")));

		// 3) Path-addressed PNG: revalidated on each use (no-cache), strict Content-Type, ETag and 304
		var floorResult = mvc.perform(get("/api/v1/content/pack/files/assets/floor.png"))
				.andExpect(status().isOk())
				.andExpect(content().contentType(MediaType.IMAGE_PNG))
				.andExpect(header().longValue(HttpHeaders.CONTENT_LENGTH, floorBytes.length))
				.andExpect(header().string(HttpHeaders.CACHE_CONTROL, "no-cache"))
				.andExpect(content().bytes(floorBytes))
				.andReturn();
		String floorEtag = floorResult.getResponse().getHeader(HttpHeaders.ETAG);
		String floorSha = sha256Hex(floorBytes);
		assertThat(floorEtag).isEqualTo("\"" + floorSha + "\"");

		mvc.perform(get("/api/v1/content/pack/files/assets/floor.png").header(HttpHeaders.IF_NONE_MATCH, floorEtag))
				.andExpect(status().isNotModified())
				.andExpect(header().string(HttpHeaders.CACHE_CONTROL, "no-cache"));

		// 4) Content-addressed blob: immutable for one year, strong ETag, 304
		mvc.perform(get("/api/v1/content/pack/blobs/" + floorSha))
				.andExpect(status().isOk())
				.andExpect(content().contentType(MediaType.IMAGE_PNG))
				.andExpect(header().longValue(HttpHeaders.CONTENT_LENGTH, floorBytes.length))
				.andExpect(header().string(HttpHeaders.CACHE_CONTROL, "public, max-age=31536000, immutable"))
				.andExpect(header().string(HttpHeaders.ETAG, floorEtag))
				.andExpect(content().bytes(floorBytes));
		mvc.perform(get("/api/v1/content/pack/blobs/" + floorSha).header(HttpHeaders.IF_NONE_MATCH, floorEtag))
				.andExpect(status().isNotModified())
				.andExpect(header().string(HttpHeaders.CACHE_CONTROL, "public, max-age=31536000, immutable"));

		// 5) Invalid / unknown hashes
		mvc.perform(get("/api/v1/content/pack/blobs/not-a-hash")).andExpect(status().isBadRequest());
		mvc.perform(get("/api/v1/content/pack/blobs/" + floorSha.toUpperCase())).andExpect(status().isBadRequest());
		mvc.perform(get("/api/v1/content/pack/blobs/" + "0".repeat(64))).andExpect(status().isNotFound());

		// 6) Unindexed or traversal paths are rejected
		mvc.perform(get("/api/v1/content/pack/files/assets/missing.png"))
				.andExpect(status().isNotFound());
		mvc.perform(get("/api/v1/content/pack/files/..%2Fsecret.txt"))
				.andExpect(status().is4xxClientError());
	}

	@Test
	void reloadIfChangedSwapsOnlyWhenChecksumsChange() throws Exception {
		KeyPair kp = generateEd25519();
		String pubB64 = Base64.getEncoder().encodeToString(kp.getPublic().getEncoded());
		Path packDir = tempDir.resolve("live");
		writeSignedPack(packDir, kp, "v1", "1.0.0", Map.of("manifest.json", "{}".getBytes(StandardCharsets.UTF_8)));
		ContentPackStore store = new ContentPackStore(
				new ContentPackConfig(packDir.toString(), "1.0.0", Map.of("v1", pubB64)), objectMapper);
		assertThat(store.getActivePack().orElseThrow().packVersion()).isEqualTo("1.0.0");

		store.reloadIfChanged();
		assertThat(store.getActivePack().orElseThrow().packVersion()).isEqualTo("1.0.0");

		writeSignedPack(packDir, kp, "v1", "1.1.0", Map.of("manifest.json", "{\"a\":1}".getBytes(StandardCharsets.UTF_8)));
		store.reloadIfChanged();
		assertThat(store.getActivePack().orElseThrow().packVersion()).isEqualTo("1.1.0");
	}

	@Test
	void blankTrustedKeyEntriesAreIgnored() {
		ContentPackConfig cfg = new ContentPackConfig("", "1.0.0", Map.of("v1", "", "v2", "  "));
		assertThat(cfg.trustedPublicKeys()).isEmpty();
	}

	@Test
	void rejectsTamperedAssetOrUnknownKeyIdAndKeepsPreviousValidPack() throws Exception {
		KeyPair validKp = generateEd25519();
		KeyPair unknownKp = generateEd25519();
		String validPubB64 = Base64.getEncoder().encodeToString(validKp.getPublic().getEncoded());

		Path packDir = writeSignedPack(
				tempDir.resolve("live_pack"),
				validKp,
				"v1",
				"1.0.0",
				Map.of("manifest.json", "{}".getBytes(StandardCharsets.UTF_8)));

		ContentPackStore store = new ContentPackStore(
				new ContentPackConfig(packDir.toString(), "1.0.0", Map.of("v1", validPubB64)),
				objectMapper);
		assertThat(store.getActivePack()).isPresent();
		assertThat(store.getActivePack().orElseThrow().packVersion()).isEqualTo("1.0.0");

		// Tamper with manifest.json on disk -> reload fails, previous valid snapshot stays active
		Files.writeString(packDir.resolve("manifest.json"), "{\"tampered\":true}", StandardCharsets.UTF_8);
		assertThat(store.reload()).isFalse();
		assertThat(store.getActivePack()).isPresent();
		assertThat(store.getActivePack().orElseThrow().packVersion()).isEqualTo("1.0.0");

		// Pack signed with unknown keyId is rejected on fresh load
		Path badKeyDir = writeSignedPack(
				tempDir.resolve("bad_key_pack"),
				unknownKp,
				"v99",
				"1.1.0",
				Map.of("manifest.json", "{}".getBytes(StandardCharsets.UTF_8)));
		ContentPackStore rejectedStore = new ContentPackStore(
				new ContentPackConfig(badKeyDir.toString(), "1.0.0", Map.of("v1", validPubB64)),
				objectMapper);
		assertThat(rejectedStore.getActivePack()).isEmpty();
	}

	@Test
	void rejectsInvalidSignatureBeforeJsonParsing() throws Exception {
		KeyPair kp = generateEd25519();
		String pubB64 = Base64.getEncoder().encodeToString(kp.getPublic().getEncoded());

		Path dir = Files.createDirectories(tempDir.resolve("malformed_json_pack"));
		Files.writeString(dir.resolve("pack-checksums.json"), "{not-valid-json", StandardCharsets.UTF_8);
		String fakeSig = Base64.getEncoder().encodeToString(new byte[64]);
		Files.writeString(dir.resolve("pack-checksums.json.sig"), "v1:" + fakeSig + "\n", StandardCharsets.UTF_8);

		ContentPackStore store = new ContentPackStore(
				new ContentPackConfig(dir.toString(), "1.0.0", Map.of("v1", pubB64)),
				objectMapper);
		assertThat(store.getActivePack()).isEmpty();
	}

	private static String sha256Hex(byte[] bytes) throws Exception {
		return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
	}

	private static KeyPair generateEd25519() throws Exception {
		return KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
	}

	private Path writeSignedPack(
			Path dir,
			KeyPair kp,
			String keyId,
			String packVersion,
			Map<String, byte[]> files) throws Exception {
		Files.createDirectories(dir);
		StringBuilder filesJson = new StringBuilder("{");
		boolean first = true;
		for (Map.Entry<String, byte[]> e : files.entrySet()) {
			Path target = dir.resolve(e.getKey());
			Files.createDirectories(target.getParent());
			Files.write(target, e.getValue());
			if (!first) filesJson.append(",");
			first = false;
			String sha = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(e.getValue()));
			filesJson.append("\"").append(e.getKey()).append("\":{\"sha256\":\"")
					.append(sha).append("\",\"sizeBytes\":").append(e.getValue().length).append("}");
		}
		filesJson.append("}");

		String checksums = "{\"schemaVersion\":1,\"keyId\":\"" + keyId
				+ "\",\"packId\":\"deep-sky-home-v1\",\"packVersion\":\"" + packVersion
				+ "\",\"minAppProtocol\":1,\"files\":" + filesJson + "}\n";
		byte[] checksumsBytes = checksums.getBytes(StandardCharsets.UTF_8);
		Files.write(dir.resolve("pack-checksums.json"), checksumsBytes);

		Signature sig = Signature.getInstance("Ed25519");
		sig.initSign(kp.getPrivate());
		sig.update(checksumsBytes);
		String sigLine = keyId + ":" + Base64.getEncoder().encodeToString(sig.sign()) + "\n";
		Files.writeString(dir.resolve("pack-checksums.json.sig"), sigLine, StandardCharsets.UTF_8);
		return dir;
	}
}
