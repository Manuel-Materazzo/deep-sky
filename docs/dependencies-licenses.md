# Dependency Licenses Inventory

Reference IDs: `SEC-02`, `PD-13`, [Piano di sviluppo](development-plan.md) section 3.1.

Generated via `python scripts/check-licenses.py --write-doc docs/dependencies-licenses.md`.

## Flutter / Dart Packages (32)

| Package | Detected License | Status |
| :-- | :-- | :-- |
| `async` | BSD | compatible |
| `boolean_selector` | BSD | compatible |
| `characters` | BSD | compatible |
| `clock` | Apache-2.0 | compatible |
| `collection` | BSD | compatible |
| `cupertino_icons` | MIT | compatible |
| `cupertino_ui` | BSD | compatible |
| `fake_async` | Apache-2.0 | compatible |
| `flutter` | BSD | compatible |
| `flutter_lints` | BSD | compatible |
| `flutter_localizations` | Unknown | compatible |
| `flutter_test` | Unknown | compatible |
| `intl` | BSD | compatible |
| `leak_tracker` | BSD | compatible |
| `leak_tracker_flutter_testing` | BSD | compatible |
| `leak_tracker_testing` | BSD | compatible |
| `lints` | BSD | compatible |
| `listen` | BSD | compatible |
| `matcher` | BSD | compatible |
| `material_color_utilities` | Apache-2.0 | compatible |
| `material_ui` | BSD | compatible |
| `meta` | BSD | compatible |
| `path` | BSD | compatible |
| `sky_engine` | MIT | compatible |
| `source_span` | BSD | compatible |
| `stack_trace` | BSD | compatible |
| `stream_channel` | BSD | compatible |
| `string_scanner` | BSD | compatible |
| `term_glyph` | BSD | compatible |
| `test_api` | BSD | compatible |
| `vector_math` | BSD | compatible |
| `vm_service` | BSD | compatible |

## Backend Maven Artifacts (172)

| Coordinate | Scope | POM License(s) | Status |
| :-- | :-- | :-- | :-- |
| `ch.qos.logback:logback-classic:1.5.38` | `compile` | EPL-2.0; LGPL-2.1-only | compatible |
| `ch.qos.logback:logback-core:1.5.38` | `compile` | EPL-2.0; LGPL-2.1-only | compatible |
| `com.fasterxml:classmate:1.7.3` | `compile` | Apache License, Version 2.0 | compatible |
| `com.fasterxml.jackson.core:jackson-annotations:2.21` | `compile` | The Apache Software License, Version 2.0 | compatible |
| `com.fasterxml.jackson.core:jackson-core:2.21.7` | `compile` | The Apache Software License, Version 2.0 | compatible |
| `com.fasterxml.jackson.core:jackson-databind:2.21.7` | `compile` | The Apache Software License, Version 2.0 | compatible |
| `com.fasterxml.jackson.dataformat:jackson-dataformat-yaml:2.21.7` | `compile` | The Apache Software License, Version 2.0 | compatible |
| `com.fasterxml.jackson.datatype:jackson-datatype-jsr310:2.21.7` | `compile` | The Apache Software License, Version 2.0 | compatible |
| `com.github.docker-java:docker-java-api:3.7.1` | `test` | The Apache Software License, Version 2.0 | compatible |
| `com.github.docker-java:docker-java-transport:3.7.1` | `test` | The Apache Software License, Version 2.0 | compatible |
| `com.github.docker-java:docker-java-transport-zerodep:3.7.1` | `test` | The Apache Software License, Version 2.0 | compatible |
| `com.jayway.jsonpath:json-path:2.10.0` | `test` | The Apache Software License, Version 2.0 | compatible |
| `com.sun.istack:istack-commons-runtime:4.1.2` | `runtime` | Eclipse Distribution License - v 1.0 | compatible |
| `com.tngtech.archunit:archunit:1.5.1` | `test` | The Apache Software License, Version 2.0; BSD | compatible |
| `com.tngtech.archunit:archunit-junit5:1.5.1` | `test` | The Apache Software License, Version 2.0 | compatible |
| `com.tngtech.archunit:archunit-junit5-api:1.5.1` | `test` | The Apache Software License, Version 2.0 | compatible |
| `com.tngtech.archunit:archunit-junit5-engine:1.5.1` | `test` | The Apache Software License, Version 2.0 | compatible |
| `com.tngtech.archunit:archunit-junit5-engine-api:1.5.1` | `test` | The Apache Software License, Version 2.0 | compatible |
| `com.vaadin.external.google:android-json:0.0.20131108.vaadin1` | `test` | Apache License 2.0 | compatible |
| `com.zaxxer:HikariCP:7.0.2` | `compile` | The Apache Software License, Version 2.0 | compatible |
| `commons-codec:commons-codec:1.21.0` | `test` | Apache-2.0 | compatible |
| `commons-io:commons-io:2.20.0` | `test` | Apache-2.0 | compatible |
| `commons-logging:commons-logging:1.3.6` | `compile` | Apache-2.0 | compatible |
| `io.micrometer:micrometer-commons:1.17.2` | `compile` | The Apache Software License, Version 2.0 | compatible |
| `io.micrometer:micrometer-core:1.17.2` | `compile` | The Apache Software License, Version 2.0 | compatible |
| `io.micrometer:micrometer-jakarta9:1.17.2` | `compile` | The Apache Software License, Version 2.0 | compatible |
| `io.micrometer:micrometer-observation:1.17.2` | `compile` | The Apache Software License, Version 2.0 | compatible |
| `io.swagger.core.v3:swagger-annotations-jakarta:2.2.55` | `compile` | Apache License 2.0 | compatible |
| `io.swagger.core.v3:swagger-core-jakarta:2.2.55` | `compile` | Apache License 2.0 | compatible |
| `io.swagger.core.v3:swagger-models-jakarta:2.2.55` | `compile` | Apache License 2.0 | compatible |
| `jakarta.activation:jakarta.activation-api:2.1.4` | `compile` | EDL 1.0 | compatible |
| `jakarta.annotation:jakarta.annotation-api:3.0.0` | `compile` | EPL 2.0; GPL2 w/ CPE | compatible |
| `jakarta.inject:jakarta.inject-api:2.0.1` | `runtime` | The Apache Software License, Version 2.0 | compatible |
| `jakarta.persistence:jakarta.persistence-api:3.2.0` | `compile` | Eclipse Public License v. 2.0; Eclipse Distribution License v. 1.0 | compatible |
| `jakarta.transaction:jakarta.transaction-api:2.0.1` | `compile` | EPL 2.0; GPL2 w/ CPE | compatible |
| `jakarta.validation:jakarta.validation-api:3.1.1` | `compile` | Apache License 2.0 | compatible |
| `jakarta.xml.bind:jakarta.xml.bind-api:4.0.5` | `compile` | Eclipse Distribution License - v 1.0 | compatible |
| `net.bytebuddy:byte-buddy:1.18.15` | `runtime` | Apache License, Version 2.0 | compatible |
| `net.bytebuddy:byte-buddy-agent:1.18.15` | `test` | Apache License, Version 2.0 | compatible |
| `net.java.dev.jna:jna:5.18.1` | `test` | LGPL-2.1-or-later; Apache-2.0 | compatible |
| `net.minidev:accessors-smart:2.6.0` | `test` | The Apache Software License, Version 2.0 | compatible |
| `net.minidev:json-smart:2.6.0` | `test` | The Apache Software License, Version 2.0 | compatible |
| `org.antlr:antlr4-runtime:4.13.2` | `compile` | BSD-3-Clause | compatible |
| `org.apache.commons:commons-compress:1.28.0` | `test` | Apache-2.0 | compatible |
| `org.apache.commons:commons-lang3:3.20.0` | `compile` | Apache-2.0 | compatible |
| `org.apache.logging.log4j:log4j-api:2.25.5` | `compile` | Apache-2.0 | compatible |
| `org.apache.logging.log4j:log4j-to-slf4j:2.25.5` | `compile` | Apache-2.0 | compatible |
| `org.apache.tomcat.embed:tomcat-embed-core:11.0.27` | `compile` | Apache License, Version 2.0 | compatible |
| `org.apache.tomcat.embed:tomcat-embed-el:11.0.27` | `compile` | Apache License, Version 2.0 | compatible |
| `org.apache.tomcat.embed:tomcat-embed-websocket:11.0.27` | `compile` | Apache License, Version 2.0 | compatible |
| `org.apiguardian:apiguardian-api:1.1.2` | `test` | The Apache License, Version 2.0 | compatible |
| `org.aspectj:aspectjweaver:1.9.25.1` | `compile` | Eclipse Public License - v 2.0 | compatible |
| `org.assertj:assertj-core:3.27.7` | `test` | Apache-2.0 | compatible |
| `org.awaitility:awaitility:4.3.0` | `test` | Apache 2.0 | compatible |
| `org.checkerframework:checker-qual:3.55.1` | `runtime` | The MIT License | compatible |
| `org.eclipse.angus:angus-activation:2.0.3` | `runtime` | EDL 1.0 | compatible |
| `org.flywaydb:flyway-core:12.4.0` | `compile` | Apache License, Version 2.0 | compatible |
| `org.flywaydb:flyway-database-postgresql:12.4.0` | `compile` | Apache License, Version 2.0 | compatible |
| `org.glassfish.jaxb:jaxb-core:4.0.9` | `runtime` | Eclipse Distribution License - v 1.0 | compatible |
| `org.glassfish.jaxb:jaxb-runtime:4.0.9` | `runtime` | Eclipse Distribution License - v 1.0 | compatible |
| `org.glassfish.jaxb:txw2:4.0.9` | `runtime` | Eclipse Distribution License - v 1.0 | compatible |
| `org.hamcrest:hamcrest:3.0` | `test` | BSD-3-Clause | compatible |
| `org.hdrhistogram:HdrHistogram:2.2.2` | `runtime` | Public Domain, per Creative Commons CC0; BSD-2-Clause | compatible |
| `org.hibernate.models:hibernate-models:1.1.2` | `runtime` | Apache License Version 2.0 | compatible |
| `org.hibernate.orm:hibernate-core:7.4.13.Final` | `compile` | Apache License, Version 2.0 | compatible |
| `org.hibernate.validator:hibernate-validator:9.1.5.Final` | `compile` | Apache License 2.0 | compatible |
| `org.jboss.logging:jboss-logging:3.6.3.Final` | `compile` | Apache License 2.0 | compatible |
| `org.jetbrains:annotations:17.0.0` | `test` | The Apache Software License, Version 2.0 | compatible |
| `org.jspecify:jspecify:1.0.1` | `compile` | The Apache License, Version 2.0 | compatible |
| `org.junit.jupiter:junit-jupiter:6.0.3` | `test` | Eclipse Public License v2.0 | compatible |
| `org.junit.jupiter:junit-jupiter-api:6.0.3` | `test` | Eclipse Public License v2.0 | compatible |
| `org.junit.jupiter:junit-jupiter-engine:6.0.3` | `test` | Eclipse Public License v2.0 | compatible |
| `org.junit.jupiter:junit-jupiter-params:6.0.3` | `test` | Eclipse Public License v2.0 | compatible |
| `org.junit.platform:junit-platform-commons:6.0.3` | `test` | Eclipse Public License v2.0 | compatible |
| `org.junit.platform:junit-platform-engine:6.0.3` | `test` | Eclipse Public License v2.0 | compatible |
| `org.mockito:mockito-core:5.23.0` | `test` | MIT | compatible |
| `org.mockito:mockito-junit-jupiter:5.23.0` | `test` | MIT | compatible |
| `org.objenesis:objenesis:3.3` | `test` | Apache License, Version 2.0 | compatible |
| `org.opentest4j:opentest4j:1.3.0` | `test` | The Apache License, Version 2.0 | compatible |
| `org.ow2.asm:asm:9.7.1` | `test` | BSD-3-Clause | compatible |
| `org.postgresql:postgresql:42.7.14` | `runtime` | BSD-2-Clause | compatible |
| `org.projectlombok:lombok:1.18.48` | `compile` | The MIT License | compatible |
| `org.rnorth.duct-tape:duct-tape:1.0.8` | `test` | MIT | compatible |
| `org.skyscreamer:jsonassert:1.5.3` | `test` | The Apache Software License, Version 2.0 | compatible |
| `org.slf4j:jul-to-slf4j:2.0.20` | `compile` | MIT | compatible |
| `org.slf4j:slf4j-api:2.0.20` | `compile` | MIT | compatible |
| `org.springdoc:springdoc-openapi-starter-common:3.2.0` | `compile` | The Apache License, Version 2.0 | compatible |
| `org.springdoc:springdoc-openapi-starter-webmvc-api:3.2.0` | `compile` | The Apache License, Version 2.0 | compatible |
| `org.springdoc:springdoc-openapi-starter-webmvc-ui:3.2.0` | `compile` | The Apache License, Version 2.0 | compatible |
| `org.springframework:spring-aop:7.0.10` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework:spring-aspects:7.0.10` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework:spring-beans:7.0.10` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework:spring-context:7.0.10` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework:spring-core:7.0.10` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework:spring-expression:7.0.10` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework:spring-jdbc:7.0.10` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework:spring-orm:7.0.10` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework:spring-test:7.0.10` | `test` | Apache License, Version 2.0 | compatible |
| `org.springframework:spring-tx:7.0.10` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework:spring-web:7.0.10` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework:spring-webmvc:7.0.10` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-actuator:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-actuator-autoconfigure:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-autoconfigure:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-data-commons:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-data-jpa:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-data-jpa-test:4.1.2` | `test` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-docker-compose:4.1.2` | `runtime` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-flyway:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-health:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-hibernate:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-http-converter:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-jackson:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-jdbc:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-jdbc-test:4.1.2` | `test` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-jpa:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-jpa-test:4.1.2` | `test` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-micrometer-metrics:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-micrometer-observation:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-persistence:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-resttestclient:4.1.2` | `test` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-security:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-security-test:4.1.2` | `test` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-servlet:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-sql:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-starter:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-starter-actuator:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-starter-data-jpa:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-starter-data-jpa-test:4.1.2` | `test` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-starter-flyway:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-starter-jackson:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-starter-jackson-test:4.1.2` | `test` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-starter-jdbc:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-starter-jdbc-test:4.1.2` | `test` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-starter-logging:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-starter-micrometer-metrics:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-starter-security:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-starter-security-test:4.1.2` | `test` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-starter-test:4.1.2` | `test` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-starter-tomcat:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-starter-tomcat-runtime:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-starter-validation:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-starter-webmvc:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-starter-webmvc-test:4.1.2` | `test` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-test:4.1.2` | `test` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-test-autoconfigure:4.1.2` | `test` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-testcontainers:4.1.2` | `test` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-tomcat:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-transaction:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-validation:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-web-server:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-webmvc:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.boot:spring-boot-webmvc-test:4.1.2` | `test` | Apache License, Version 2.0 | compatible |
| `org.springframework.data:spring-data-commons:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.data:spring-data-jpa:4.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.security:spring-security-config:7.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.security:spring-security-core:7.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.security:spring-security-crypto:7.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.springframework.security:spring-security-test:7.1.2` | `test` | Apache License, Version 2.0 | compatible |
| `org.springframework.security:spring-security-web:7.1.2` | `compile` | Apache License, Version 2.0 | compatible |
| `org.testcontainers:testcontainers:2.0.5` | `test` | MIT | compatible |
| `org.testcontainers:testcontainers-database-commons:2.0.5` | `test` | MIT | compatible |
| `org.testcontainers:testcontainers-jdbc:2.0.5` | `test` | MIT | compatible |
| `org.testcontainers:testcontainers-junit-jupiter:2.0.5` | `test` | MIT | compatible |
| `org.testcontainers:testcontainers-postgresql:2.0.5` | `test` | MIT | compatible |
| `org.webjars:swagger-ui:5.34.0` | `compile` | Apache-2.0 | compatible |
| `org.webjars:webjars-locator-lite:1.1.5` | `compile` | MIT | compatible |
| `org.xmlunit:xmlunit-core:2.11.0` | `test` | The Apache Software License, Version 2.0 | compatible |
| `org.yaml:snakeyaml:2.6` | `compile` | Apache License, Version 2.0 | compatible |
| `tools.jackson.core:jackson-core:3.1.7` | `compile` | The Apache Software License, Version 2.0 | compatible |
| `tools.jackson.core:jackson-databind:3.1.7` | `compile` | The Apache Software License, Version 2.0 | compatible |
