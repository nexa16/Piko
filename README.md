# Piko

**Status: Implementation round 1 under Android testing; round 2 specifications and mockup ready for review. Not a published product release.**

The local-first Flutter app has an Android test build for implementation round 1. Round 2 currently covers canonical definitions and an interactive mockup, not new production features. The HTML/CSS mockup remains the design reference; the roadmap separates accepted round-2 scope, production implementation order and later capabilities.

This repository contains Piko's product planning and future implementation.

## Planning

- [Product brief](docs/PRODUCT.md)
- [Roadmap](docs/ROADMAP.md)
- [Implementation-round-1 implementation order and evidence](docs/implementation-round-1.md)
- [Implementation-round-2 execution and evidence](docs/implementation-round-2.md)
- [Decision log](docs/DECISIONS.md)
- [Research plan](docs/RESEARCH.md)
- [Functional requirements](docs/piko-functional.md) and [UX requirements](docs/piko-ux.md)
- [Design foundations and open visual decisions](docs/DESIGN.md)
- [Design studio](mockups/design-lab.html) — compare palettes and edit English/German labels in a live mockup preview
- [Filterable requirements](mockups/requirements.html) — derives lists from the canonical specifications; use an HTTP preview for reading Markdown files
- [Navigation mockup](mockups/piko-mockup.html) — download and open locally; sample data and placeholder interactions

## Development

The Flutter application lives in [app/](app/README.md). See [foundation requirements](docs/implementation-foundation.md), [contribution guidelines](CONTRIBUTING.md) and [agent instructions](AGENTS.md). The initial Android scaffold now supports local collection creation; each feature requires its own tests and verification.

Interface wording is maintained once in `shared/copy.js`. The mockup consumes it directly. The studio supports immediate draft previews and export; a future app will consume the same catalog through an adapter appropriate to its platform. See the design foundations document for persistence and synchronization limits.

`main` is the default and release branch; `develop` is for development. The initial planning and mockup bootstrap on `main` does not represent a release. Substantive work uses thematic feature PRs from short-lived branches, squash-merged into `develop`. Implementation rounds are planning scopes, not release numbers. A future owner-requested release branch will start from accepted `develop`; no promotion or store publication is currently authorized. See the [feature-PR transition plan](docs/ROADMAP.md#feature-pr-transition).

Review the full content and commit metadata with the owner before the first public push. Keep private research, identifying data, and secrets outside this public repository.

## Licensing

No open-source license has been selected. Public visibility alone does not grant reuse rights. No additional permission to use, modify, or redistribute this repository is granted by a license at this time.
