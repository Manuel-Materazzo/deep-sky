package com.vectevo.deep_sky_server.content;

import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Locale;
import java.util.Optional;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * File-by-file distribution endpoints for signed Deep Sky content packs (`AR-09`, `TC-10`, `S2-SRV-01`).
 */
@RestController
@RequestMapping("/api/v1/content/pack")
public class ContentPackController {

	private static final Logger log = LoggerFactory.getLogger(ContentPackController.class);
	private static final String FILES_PREFIX = "/api/v1/content/pack/files/";
	private static final String IMMUTABLE_CACHE_CONTROL = "public, max-age=31536000, immutable";
	private static final Pattern SHA256_HEX = Pattern.compile("^[0-9a-f]{64}$");

	private final ContentPackStore store;

	public ContentPackController(ContentPackStore store) {
		this.store = store;
	}

	@GetMapping("/checksums")
	public ResponseEntity<byte[]> getChecksums(
			@RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch) {
		Optional<ContentPackStore.LoadedPack> maybePack = store.getActivePack();
		if (maybePack.isEmpty()) {
			return ResponseEntity.notFound().build();
		}
		ContentPackStore.LoadedPack pack = maybePack.get();
		String etag = quotedEtag(pack.checksumsEtag());
		if (matchesEtag(ifNoneMatch, etag)) {
			return ResponseEntity.status(HttpStatus.NOT_MODIFIED)
					.eTag(etag)
					.cacheControl(CacheControl.noCache())
					.build();
		}
		return ResponseEntity.ok()
				.contentType(MediaType.APPLICATION_JSON)
				.contentLength(pack.checksumsBytes().length)
				.eTag(etag)
				.cacheControl(CacheControl.noCache())
				.body(pack.checksumsBytes());
	}

	@GetMapping("/checksums.sig")
	public ResponseEntity<byte[]> getChecksumsSignature(
			@RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch) {
		Optional<ContentPackStore.LoadedPack> maybePack = store.getActivePack();
		if (maybePack.isEmpty()) {
			return ResponseEntity.notFound().build();
		}
		ContentPackStore.LoadedPack pack = maybePack.get();
		String etag = quotedEtag(pack.signatureEtag());
		if (matchesEtag(ifNoneMatch, etag)) {
			return ResponseEntity.status(HttpStatus.NOT_MODIFIED)
					.eTag(etag)
					.cacheControl(CacheControl.noCache())
					.build();
		}
		return ResponseEntity.ok()
				.contentType(MediaType.parseMediaType("text/plain;charset=UTF-8"))
				.contentLength(pack.signatureBytes().length)
				.eTag(etag)
				.cacheControl(CacheControl.noCache())
				.body(pack.signatureBytes());
	}

	@GetMapping("/files/**")
	public ResponseEntity<Resource> getPackFile(
			HttpServletRequest request,
			@RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch)
			throws IOException {
		Optional<ContentPackStore.LoadedPack> maybePack = store.getActivePack();
		if (maybePack.isEmpty()) {
			return ResponseEntity.notFound().build();
		}
		String requestUri = request.getRequestURI();
		int idx = requestUri.indexOf(FILES_PREFIX);
		if (idx < 0) {
			return ResponseEntity.badRequest().build();
		}
		String relativePath = requestUri.substring(idx + FILES_PREFIX.length());
		if (!ContentPackStore.isSafeRelativePath(relativePath)) {
			return ResponseEntity.badRequest().build();
		}

		ContentPackStore.PackFileEntry fileEntry = maybePack.get().files().get(relativePath);
		if (fileEntry == null) {
			return ResponseEntity.notFound().build();
		}

		// Path-addressed URL: the same path is reused across pack versions, so it must be revalidated (no immutable).
		return serveEntry(fileEntry, ifNoneMatch, CacheControl.noCache().getHeaderValue());
	}

	/**
	 * Content-addressed endpoint: the URL is the SHA-256 of the bytes, so the response is truly immutable.
	 */
	@GetMapping("/blobs/{sha256}")
	public ResponseEntity<Resource> getPackBlob(
			@PathVariable("sha256") String sha256,
			@RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch)
			throws IOException {
		if (sha256 == null || !SHA256_HEX.matcher(sha256).matches()) {
			return ResponseEntity.badRequest().build();
		}
		Optional<ContentPackStore.LoadedPack> maybePack = store.getActivePack();
		if (maybePack.isEmpty()) {
			return ResponseEntity.notFound().build();
		}
		ContentPackStore.PackFileEntry entry = maybePack.get().files().values().stream()
				.filter(e -> e.sha256().equals(sha256))
				.findFirst()
				.orElse(null);
		if (entry == null) {
			return ResponseEntity.notFound().build();
		}
		return serveEntry(entry, ifNoneMatch, IMMUTABLE_CACHE_CONTROL);
	}

	private static ResponseEntity<Resource> serveEntry(
			ContentPackStore.PackFileEntry entry, String ifNoneMatch, String cacheControl) throws IOException {
		String etag = quotedEtag(entry.sha256());
		if (matchesEtag(ifNoneMatch, etag)) {
			return ResponseEntity.status(HttpStatus.NOT_MODIFIED)
					.eTag(etag)
					.header(HttpHeaders.CACHE_CONTROL, cacheControl)
					.build();
		}
		// AU-15: Stream directly from disk via FileSystemResource (no whole-file byte[] on heap)
		// and reject with 500 if the underlying file was modified in place since verification.
		Path path = entry.resolvedPath();
		if (!Files.isRegularFile(path)) {
			log.error("Verified content pack file disappeared on disk: {}", entry.relativePath());
			return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
		}
		long currentSize = Files.size(path);
		if (currentSize != entry.sizeBytes()) {
			log.error("Content pack file {} size changed on disk (expected {}, found {}); refusing to serve with stale ETag",
					entry.relativePath(), entry.sizeBytes(), currentSize);
			return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
		}
		if (entry.lastModifiedMillis() >= 0L) {
			long currentMtime = Files.getLastModifiedTime(path).toMillis();
			if (currentMtime != entry.lastModifiedMillis()) {
				String actualSha = computeFileSha256Hex(path);
				if (!entry.sha256().equals(actualSha)) {
					log.error("Content pack file {} modified in place on disk (SHA-256 mismatch); refusing to serve with stale ETag",
							entry.relativePath());
					return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
				}
			}
		}
		return ResponseEntity.ok()
				.contentType(resolveMediaType(entry.relativePath()))
				.contentLength(currentSize)
				.eTag(etag)
				.header(HttpHeaders.CACHE_CONTROL, cacheControl)
				.body(new FileSystemResource(path));
	}

	private static String computeFileSha256Hex(Path path) throws IOException {
		try {
			MessageDigest md = MessageDigest.getInstance("SHA-256");
			byte[] buf = new byte[8192];
			try (InputStream in = Files.newInputStream(path)) {
				int n;
				while ((n = in.read(buf)) != -1) {
					md.update(buf, 0, n);
				}
			}
			return HexFormat.of().formatHex(md.digest());
		} catch (NoSuchAlgorithmException ex) {
			throw new IllegalStateException("SHA-256 unavailable", ex);
		}
	}

	private static String quotedEtag(String sha256) {
		return "\"" + sha256 + "\"";
	}

	private static boolean matchesEtag(String ifNoneMatch, String etag) {
		if (ifNoneMatch == null || ifNoneMatch.isBlank()) {
			return false;
		}
		String trimmed = ifNoneMatch.trim();
		if ("*".equals(trimmed)) {
			return true;
		}
		for (String part : trimmed.split(",")) {
			String candidate = part.trim();
			if (candidate.startsWith("W/")) {
				candidate = candidate.substring(2).trim();
			}
			if (etag.equals(candidate)) {
				return true;
			}
		}
		return false;
	}

	private static MediaType resolveMediaType(String relativePath) {
		String lower = relativePath.toLowerCase(Locale.ROOT);
		if (lower.endsWith(".png")) {
			return MediaType.IMAGE_PNG;
		}
		if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) {
			return MediaType.IMAGE_JPEG;
		}
		if (lower.endsWith(".json")) {
			return MediaType.APPLICATION_JSON;
		}
		return MediaType.APPLICATION_OCTET_STREAM;
	}
}
