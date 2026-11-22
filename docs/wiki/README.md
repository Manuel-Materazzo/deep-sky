# Deep Sky — Users & Server Operators Wiki

This folder collects practical guides for anyone who **installs, configures, manages, or uses** Deep Sky (Android app and self-hosted server), without having to read the development documents, operational plans, or architectural specifications in `docs/`.

## Where to Start

| Guide | Who it's for | What you'll find |
| :--- | :--- | :--- |
| [Getting Started](getting-started.md) | Anyone starting from scratch (server + app) | Starting the server with Docker Compose, installing the APK, creating/joining a couple, and saving the Recovery Key |
| [Content Packs Management](content-packs-operations.md) | Server operators and users | How incremental 2D Home packs work and how to hot-publish new graphics on the server |
| [Server Operations, Firebase & Backups](server-operations.md) | Server operators (self-hosters) | Main `.env` variables, enabling FCM push notifications, consistent backups (`db` + `blob_data` + `pack_data`), and restore |
| [Emergencies & Recovery](troubleshooting-and-recovery.md) | Everyone (users and operators) | What to do if the server is offline, if one or both phones are lost, or if a version needs to be blocked/updated |

## Other Detailed Reference Guides

If you need more in-depth technical references already available in the repository:
- [Complete Server Configuration](../server-configuration.md) — full list of all environment variables, reverse proxy, and data retention.
- [Firebase (FCM) Setup Guide](../firebase-setup.md) — step-by-step procedure in the Firebase Console without `google-services.json`.
- [Backup and Restore Procedure](../backup-restore.md) — sample scripts and verification checklist on a VM.
- [Complete Emergency Procedure](../emergency-procedure.md) — detailed operational instructions for field incidents.
