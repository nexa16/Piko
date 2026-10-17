# Piko

**Status: Round 6 has a local build-5 review candidate with the approved vocabulary-list rework and EN/DE learning-help dialog. [The round-6 ledger](docs/implementation-round-6.md#candidate-and-remaining-handoff-gates) owns source/checksum, host/Android evidence and remaining gates. F21 page-reflow clarification and owner phone acceptance are pending. Statistics remains planning-only; F22 is deferred. Not a published release.**

The local-first Flutter app includes compact autosaving vocabulary editors, editing within revealed normal/retry/Speed answers, independent Active/Inactive vocabulary, Collection Hint defaults and JSON schema-4 export with versions 1–4 accepted on import. The [round-5 ledger](docs/implementation-round-5.md#local-verification-and-candidate--2026-10-17) owns the exact candidate, requirement revisions, host/Android evidence, exclusions and acceptance gaps. Earlier learning, examples, categories and Collection preferences are retained. UX findings are tracked separately; scoped implementation evidence does not automatically close every finding.

This repository contains Piko's product planning, interactive mockups and local-first Flutter implementation.

## Planning

- [Product brief](docs/PRODUCT.md)
- [Roadmap](docs/ROADMAP.md)
- [Implementation-round-1 implementation order and evidence](docs/implementation-round-1.md)
- [Implementation-round-2 execution and evidence](docs/implementation-round-2.md)
- [Implementation-round-3 checkpoints and evidence](docs/implementation-round-3.md)
- [Implementation-round-4 candidate and verification](docs/implementation-round-4.md)
- [Implementation-round-5 plan and learning-specification overview](docs/implementation-round-5.md)
- [UX quality workflow](docs/ux-quality.md), [accepted criteria](docs/ux-consolidation-proposals.md) and [findings](docs/ux-findings.json)
- [Historical round-3 mockup evidence](docs/implementation-round-3-mockup.md)
- [Decision log](docs/DECISIONS.md)
- [Research plan](docs/RESEARCH.md)
- [Functional requirements](docs/piko-functional.md) and [UX requirements](docs/piko-ux.md)
- [Design foundations and open visual decisions](docs/DESIGN.md)
- [Design studio](mockups/design-lab.html) — compare palettes and edit English/German labels in a live mockup preview
- [Filterable requirements](mockups/requirements.html) — derives lists from the canonical specifications; use an HTTP preview for reading Markdown files
- [Navigation mockup](mockups/piko-mockup.html) — download and open locally; sample data and placeholder interactions

## Development

The Flutter application lives in [app/](app/README.md). See [foundation requirements](docs/implementation-foundation.md), [contribution guidelines](CONTRIBUTING.md) and [agent instructions](AGENTS.md). The implementation ledgers record specification revisions, source commits and verification evidence, including outstanding gates.

Interface wording is maintained once in `shared/copy.js`. The mockup consumes it directly and Flutter consumes a generated adapter; the same approach applies to `shared/design-config.js`. The studio supports immediate draft previews and export. See the design foundations document for persistence and synchronization limits.

`main` is the default and release branch; `develop` is for development. The initial planning and mockup bootstrap on `main` does not represent a release. Substantive work uses thematic feature PRs from short-lived branches, squash-merged into `develop`. Implementation rounds are planning scopes, not release numbers. A future owner-requested release branch will start from accepted `develop`; no promotion or store publication is currently authorized. See the [feature-PR transition plan](docs/ROADMAP.md#feature-pr-transition).

Review the full content and commit metadata with the owner before the first public push. Keep private research, identifying data, and secrets outside this public repository.

## Licensing

No open-source license has been selected. Public visibility alone does not grant reuse rights. No additional permission to use, modify, or redistribute this repository is granted by a license at this time.
