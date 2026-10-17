# Piko

Piko is a local-first Flutter vocabulary app with English and German interface languages.

Create Collections with a target/native language pair, add vocabulary and examples, organize it with categories, and practice with Long-term or Speed learning. Saved vocabulary supports compact inline editing, independent Active/Inactive state, Collection Hint defaults and editing from a revealed learning answer. Collection lists provide search, filters, grouping, sorting and temporary vocabulary selection. JSON export includes Collection vocabulary-associated data; import preserves existing learning and accepts schema versions 1–4.

Statistics and a persistent shrinking Collection header are not available in this development baseline. Temporary selection has no bulk vocabulary operations or learning launch. This repository does not declare a store release.

See [application setup and technical verification](app/README.md), [contribution workflow](CONTRIBUTING.md), [agent instructions](AGENTS.md) and [security guidance](SECURITY.md).

Interface wording and English/German translations are maintained in `shared/copy.js`. Reusable design roles are maintained in `shared/design-config.js`; Flutter consumes generated adapters. The [design studio](mockups/design-lab.html) and [navigation mockup](mockups/piko-mockup.html) are exploratory/historical sample-data tools, not evidence of app persistence, AI or learning calculations.

`develop` is the development integration branch; `main` is reserved for the separately approved release process. Contributions use focused branches and reviewed pull requests. Keep secrets and identifiable research outside tracked content.

No open-source license has been selected. Public visibility alone does not grant reuse rights.
