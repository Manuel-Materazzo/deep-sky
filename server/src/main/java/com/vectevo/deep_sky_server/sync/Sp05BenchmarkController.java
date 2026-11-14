package com.vectevo.deep_sky_server.sync;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Ephemeral synthetic-load endpoints active ONLY when the {@code benchmark} Spring profile is enabled (SP-05).
 * Exercises PostgreSQL writes, connection pooling, and local blob I/O under JVM memory limits.
 */
@RestController
@Profile("benchmark")
@RequestMapping("/internal/benchmark")
public class Sp05BenchmarkController {

	private final JdbcTemplate jdbcTemplate;
	private final Path blobDir;

	public Sp05BenchmarkController(
			JdbcTemplate jdbcTemplate,
			@Value("${java.io.tmpdir}") String tmpDir) {
		this.jdbcTemplate = jdbcTemplate;
		this.blobDir = Path.of(tmpDir, "deepsky-sp05-blobs");
	}

	@PostMapping(path = "/event", consumes = MediaType.APPLICATION_OCTET_STREAM_VALUE)
	public Map<String, Object> ingestEvent(
			@RequestParam String coupleId,
			@RequestParam(defaultValue = "timeline") String channel,
			@RequestBody byte[] payload) {
		UUID id = UUID.randomUUID();
		jdbcTemplate.update(
				"INSERT INTO sp05_events (id, couple_id, channel, ciphertext_bytes, payload, created_at) VALUES (?, ?, ?, ?, ?, ?)",
				id,
				coupleId,
				channel,
				payload.length,
				payload,
				java.sql.Timestamp.from(Instant.now()));
		return Map.of("id", id.toString(), "bytes", payload.length);
	}

	@PostMapping(path = "/blob", consumes = MediaType.APPLICATION_OCTET_STREAM_VALUE)
	public Map<String, Object> ingestBlob(@RequestBody byte[] payload) throws Exception {
		Files.createDirectories(blobDir);
		UUID id = UUID.randomUUID();
		Path out = blobDir.resolve(id + ".bin");
		Files.write(out, payload);
		return Map.of("id", id.toString(), "bytes", payload.length);
	}

	@GetMapping("/stats")
	public Map<String, Object> stats() {
		Long events = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM sp05_events", Long.class);
		return Map.of("eventsStored", events == null ? 0L : events);
	}
}
