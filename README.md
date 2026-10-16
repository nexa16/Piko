# Piko

**Status: Implementation round 2 is ready for owner testing, with bounded Android evidence and documented verification limitations. Not a published product release.**

The local-first Flutter app includes round-2 JSON interchange, Speed learning, categories, filtering/search, usability changes and the approved reading mascot. The final candidate passed 1,022 host tests and static analysis; the implementation ledger records scoped Android results, preservation checks and remaining limitations. A local test APK and one English normal-size screenshot gallery are available privately. The HTML/CSS mockup remains the design reference; neither the mockup nor written code alone establishes application acceptance.

This repository contains Piko's product planning, interactive mockups and local-first Flutter implementation.

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

The Flutter application lives in [app/](app/README.md). See [foundation requirements](docs/implementation-foundation.md), [contribution guidelines](CONTRIBUTING.md) and [agent instructions](AGENTS.md). The round-2 ledger records each implemented feature's specification revision, commit and verification evidence, including outstanding gates.

Interface wording is maintained once in `shared/copy.js`. The mockup consumes it directly and Flutter consumes a generated adapter; the same approach applies to `shared/design-config.js`. The studio supports immediate draft previews and export. See the design foundations document for persistence and synchronization limits.

`main` is the default and release branch; `develop` is for development. The initial planning and mockup bootstrap on `main` does not represent a release. Substantive work uses thematic feature PRs from short-lived branches, squash-merged into `develop`. Implementation rounds are planning scopes, not release numbers. A future owner-requested release branch will start from accepted `develop`; no promotion or store publication is currently authorized. See the [feature-PR transition plan](docs/ROADMAP.md#feature-pr-transition).

Review the full content and commit metadata with the owner before the first public push. Keep private research, identifying data, and secrets outside this public repository.

## Licensing

No open-source license has been selected. Public visibility alone does not grant reuse rights. No additional permission to use, modify, or redistribute this repository is granted by a license at this time.
