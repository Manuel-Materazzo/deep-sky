package com.vectevo.deep_sky_server.content;

import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;
import java.nio.file.Files;
import java.util.Locale;
import java.util.Optional;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * File-by-file distribution endpoints for signed Deep Sky content packs (`AR-09`, `TC-10`, `S2-SRV-01`).
 */
@RestController
@RequestMapping("/api/v1/content/pack")
public class ContentPackController {

	private static final String FILES_PREFIX = "/api/v1/content/pack/files/";

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
	public ResponseEntity<byte[]> getPackFile(
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

		String etag = quotedEtag(fileEntry.sha256());
		if (matchesEtag(ifNoneMatch, etag)) {
			return ResponseEntity.status(HttpStatus.NOT_MODIFIED)
					.eTag(etag)
					.header(HttpHeaders.CACHE_CONTROL, "public, max-age=31536000, immutable")
					.build();
		}

		byte[] bytes = Files.readAllBytes(fileEntry.resolvedPath());
		return ResponseEntity.ok()
				.contentType(resolveMediaType(relativePath))
				.contentLength(bytes.length)
				.eTag(etag)
				.header(HttpHeaders.CACHE_CONTROL, "public, max-age=31536000, immutable")
				.body(bytes);
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
