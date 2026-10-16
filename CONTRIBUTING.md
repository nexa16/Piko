# Contributing

1. Fetch the latest branches. Start ordinary development from the latest `develop` branch.
2. Create a short-lived branch for substantive work; use codex/<short-description> for Codex work.
3. Update relevant planning or decision documentation.
4. Open a thematic feature Pull Request into `develop`, using an outcome-based title without a release number. Several related specifications may belong to one feature PR.
5. Explain what changed, why it changed, the covered specification IDs/revisions, and how it was checked. Keep implementation commits focused; separate spec commits are optional, not a requirement for integration history.
6. Squash each feature PR into one descriptive commit only after discussion is resolved and available checks pass. Test dependent features at their integration boundaries; an earlier green aggregate build does not verify a newly split intermediate state.

Implementation rounds 1 and 2 describe planning scope, not published releases. The current work is not approved for store publication or promotion to `main`. When the owner later requests a release, create `release/<version>` from the accepted `develop` state, stabilize and verify it, and open a promotion PR into `main`. The version and publication are explicit release-preparation decisions; schema versions and Android debug/release build modes are unrelated and remain unchanged.

Trivial owner-only corrections do not need a formal Pull Request unless a branch rule requires one. The main branch rules take precedence; emergency bypass is reserved for emergencies, not ordinary work.

Keep research anonymous and secrets outside tracked files. See [security guidance](SECURITY.md).

Before the first public push, review all proposed files, history, and commit identity metadata with the owner and obtain approval. Review new content before subsequent pushes; escalate any questionable data before publication.
