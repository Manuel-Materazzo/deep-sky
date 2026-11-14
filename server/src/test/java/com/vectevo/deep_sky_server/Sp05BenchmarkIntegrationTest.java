package com.vectevo.deep_sky_server;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

@SpringBootTest
@Testcontainers
@AutoConfigureMockMvc
@ActiveProfiles({"test", "benchmark"})
class Sp05BenchmarkIntegrationTest {

	@Container
	@ServiceConnection
	static final PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:17-alpine");

	@Autowired
	private MockMvc mockMvc;

	@Test
	void ingestsSyntheticEventsAndBlobsAndExposesMetrics() throws Exception {
		byte[] eventBytes = "opaque-ciphertext-envelope".getBytes(StandardCharsets.UTF_8);
		mockMvc.perform(post("/internal/benchmark/event?coupleId=c-001")
						.contentType(MediaType.APPLICATION_OCTET_STREAM)
						.content(eventBytes))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.bytes").value(eventBytes.length));

		mockMvc.perform(post("/internal/benchmark/blob")
						.contentType(MediaType.APPLICATION_OCTET_STREAM)
						.content(new byte[4096]))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.bytes").value(4096));

		mockMvc.perform(get("/internal/benchmark/stats"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.eventsStored").value(1));

		mockMvc.perform(get("/actuator/metrics/jvm.memory.used"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.name").value("jvm.memory.used"));
	}
}
