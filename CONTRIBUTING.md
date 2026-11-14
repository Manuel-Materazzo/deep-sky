# Contributing to Deep Sky

Thank you for your interest in **Deep Sky**. Before contributing, please read the [Project Brief](docs/project-brief.md) — in particular the product principles (`P-01` to `P-10`) — and [docs/development-plan.md](docs/development-plan.md).

## Core Rules

1. **Product principles first.** Every feature or change must cite the relevant document IDs (`P-xx`, `F-xx`, `S-xx`, `N-xx`, `TC-xx`, `PD-xx`, `REP-xx`, etc.) and never introduce streaks, coins, ads, tracking, or implicit surveillance (`P-02`, `P-07`, `S-07`).
2. **Public repository, zero secrets.** This repository is public from day one (`PD-09`). Never commit secrets, keys, credentials, or real personal data.
3. **Promoter approval (`PD-11`).** All changes to `master` go through small, reviewable pull requests with green CI and promoter approval.
4. **Architectural changes require an ADR.** Significant technical decisions or contract changes are recorded in `docs/adr/`.

## Secrets & Forbidden Files

The following must **never** be committed to the repository (including test fixtures or documentation examples):

- Android APK signing keys (`*.jks`, `*.keystore`, `*.p12`, key passwords)
- Ed25519 manifest/content signing private keys (`*.key`, `*.pem`)
- Firebase service account credentials (`firebase-service-account*.json`)
- Server administration secrets, database passwords, or TLS private keys
- Environment files (`.env`, `.env.*`, except `.env.example` templates with placeholder values)
- Real names, screenshots, messages, or couple data from real devices

Install local pre-commit secret hooks right after cloning:

```bash
# Linux / macOS
./scripts/setup-hooks.sh

# Windows PowerShell
./scripts/setup-hooks.ps1
```

## Branch Naming

Keep branches short-lived and scoped to a single task or vertical slice:

- `feat/<id-or-topic>` — new feature or capability (e.g. `feat/srv-01-spring-skeleton`)
- `fix/<topic>` — bug fix
- `docs/<topic>` — documentation or ADR updates
- `ci/<topic>` — CI/CD workflow or tooling changes
- `chore/<topic>` — maintenance, dependencies, refactoring
- `proto/sp-xx` — disposable M1 verification prototypes (never merged directly to `master`)

## Commit Messages

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```text
<type>(<optional-scope>): <short imperative summary>

[optional body citing doc IDs, e.g. Refs: SRV-01, TC-02]
```

Allowed types: `Feat`, `Fix`, `Docs`, `Chore`, `CI`, `Test`, `Refactor`, `Build`.

## Pull Request Guidelines

- Keep PRs small and focused (target review time: 20–40 minutes per `PD-12`).
- Fill in every section of `.github/pull_request_template.md`, including test evidence (commands run and outputs).
- Run all local checks before requesting review:
  - Client: `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`
  - Server: `cd server && ./mvnw verify`
  - Content: `python3 scripts/validate_content.py`
  - Secrets: `scripts/check-secrets.sh` / `scripts/check-secrets.ps1`
