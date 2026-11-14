package com.vectevo.deep_sky_server;

import com.vectevo.deep_sky_server.config.DeepSkyProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;

/** Entry point for the Deep Sky backend server (TC-02, SRV-01). */
@SpringBootApplication
@EnableConfigurationProperties(DeepSkyProperties.class)
public class DeepSkyServerApplication {

	public static void main(String[] args) {
		SpringApplication.run(DeepSkyServerApplication.class, args);
	}

}
