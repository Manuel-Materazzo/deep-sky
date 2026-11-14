# Deep Sky

*Sky is the only thing that unites and divides us.*

**Deep Sky** is a private digital home for two people — a mobile-first, end-to-end encrypted, self-hosted app for couples to leave small traces of presence in each other's day without ads, streaks, coins, or pressure.

> **Project status:** Early foundations (**M0**). Not ready for real personal data yet (see [Development Plan](docs/development-plan.md), `PD-05`).

## Repository Structure

This repository is a monorepo containing:

- `lib/`, `android/`, `test/` — Flutter client application (Android-first, package ID `com.vectevo.deep_sky`)
- `server/` — Spring Boot + PostgreSQL backend
- `content/` — Scene manifest schema, base content packs, and validation tools
- `deploy/` — Docker Compose and Caddy reverse proxy configuration for self-hosting and development
- `scripts/` — Local verification, content validation, and offline release-signing scripts
- `docs/` — Project documentation and Architecture Decision Records (`docs/adr/`)

## Documentation

Start from [docs/README.md](docs/README.md) for the full documentation index, including:

- [Project Brief](docs/project-brief.md)
- [Design Brief](docs/design-brief.md)
- [Considerazioni tecniche](docs/technical-considerations.md)
- [Piano di sviluppo](docs/development-plan.md)
- [Piano operativo M0 e M1](docs/m0-m1-operative-plan.md)
- [Architecture Decision Records (ADRs)](docs/adr/README.md)

## Quick Start

### Client (Flutter)

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

### Server (Spring Boot)

```bash
cd server
./mvnw test
```

For local containerized execution, see [deploy/docker-compose.yml](deploy/docker-compose.yml) and [docs/server-configuration.md](docs/server-configuration.md).

## Contributing & Security

- Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.
- Install the repository git hooks before committing (`scripts/setup-hooks.sh` or `scripts/setup-hooks.ps1`) so secret checks run locally.
- To report a security vulnerability, follow [SECURITY.md](SECURITY.md).

## License, Assets, and Name / Logo Notice

- **Code:** Licensed under the [MIT License](LICENSE).
- **Visual assets:** Visual assets (when introduced) may carry a separate license and are governed by `D-11` / `A-08`.
- **Name and Logo:** The MIT License applies strictly to the software source code and does **not** grant permission to use the **Deep Sky** name, logos, icons, or branding in a way that suggests official endorsement or causes confusion with official releases. Forks distributing modified builds should use a distinct name and visual identity.
