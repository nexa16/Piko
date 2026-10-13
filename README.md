# Piko

**Status: First-release implementation started**

The accepted first-release vocabulary flow is being implemented in Flutter with a local-first approach and Android verification. The HTML/CSS mockup remains the binding design reference; product research and later capabilities remain separately tracked.

This repository contains Piko's product planning and future implementation.

## Planning

- [Product brief](docs/PRODUCT.md)
- [Roadmap](docs/ROADMAP.md)
- [First-release implementation order and evidence](docs/release-1-implementation.md)
- [Decision log](docs/DECISIONS.md)
- [Research plan](docs/RESEARCH.md)
- [Functional requirements](docs/piko-functional.md) and [UX requirements](docs/piko-ux.md)
- [Design foundations and open visual decisions](docs/DESIGN.md)
- [Design studio](mockups/design-lab.html) — compare palettes and edit English/German labels in a live mockup preview
- [Filterable requirements](mockups/requirements.html) — derives lists from the canonical specifications; use an HTTP preview for reading Markdown files
- [Navigation mockup](mockups/piko-mockup.html) — download and open locally; sample data and placeholder interactions

## Development

The Flutter application lives in [app/](app/README.md). See [foundation requirements](docs/implementation-foundation.md), [contribution guidelines](CONTRIBUTING.md) and [agent instructions](AGENTS.md). Implementation begins with an empty Android scaffold; feature completion requires its own tests and verification.

Interface wording is maintained once in `shared/copy.js`. The mockup consumes it directly. The studio supports immediate draft previews and export; a future app will consume the same catalog through an adapter appropriate to its platform. See the design foundations document for persistence and synchronization limits.

`main` is the default and release branch; `develop` is for development. The initial planning and mockup bootstrap on `main` does not represent a release. Substantive work uses short-lived branches from `develop`.

Review the full content and commit metadata with the owner before the first public push. Keep private research, identifying data, and secrets outside this public repository.

## Licensing

No open-source license has been selected. Public visibility alone does not grant reuse rights. No additional permission to use, modify, or redistribute this repository is granted by a license at this time.
