package com.vectevo.deep_sky_server;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.library.dependencies.SlicesRuleDefinition.slices;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

/**
 * Verifies module isolation boundaries across the Deep Sky backend (SRV-01, ADR-0004).
 */
@AnalyzeClasses(
		packages = "com.vectevo.deep_sky_server",
		importOptions = ImportOption.DoNotIncludeTests.class
)
class ArchitectureTest {

	@ArchTest
	static final ArchRule domain_modules_must_be_free_of_cycles = slices()
			.matching("com.vectevo.deep_sky_server.(*)..")
			.should().beFreeOfCycles();

	@ArchTest
	static final ArchRule domain_modules_must_not_depend_on_config = noClasses()
			.that().resideInAnyPackage(
					"com.vectevo.deep_sky_server.pairing..",
					"com.vectevo.deep_sky_server.sync..",
					"com.vectevo.deep_sky_server.blob..",
					"com.vectevo.deep_sky_server.push..",
					"com.vectevo.deep_sky_server.content..",
					"com.vectevo.deep_sky_server.shared..")
			.should().dependOnClassesThat().resideInAPackage("com.vectevo.deep_sky_server.config..")
			.allowEmptyShould(true);

	@ArchTest
	static final ArchRule shared_must_not_depend_on_domain_modules = noClasses()
			.that().resideInAPackage("com.vectevo.deep_sky_server.shared..")
			.should().dependOnClassesThat().resideInAnyPackage(
					"com.vectevo.deep_sky_server.pairing..",
					"com.vectevo.deep_sky_server.sync..",
					"com.vectevo.deep_sky_server.blob..",
					"com.vectevo.deep_sky_server.push..",
					"com.vectevo.deep_sky_server.content..")
			.allowEmptyShould(true);
}
