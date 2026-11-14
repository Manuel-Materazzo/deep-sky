package com.vectevo.deep_sky_server.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

/** Enables scheduled maintenance tasks such as expired nonce cleanup (`PR-M2-02`). */
@Configuration
@EnableScheduling
public class SchedulingConfig {}
