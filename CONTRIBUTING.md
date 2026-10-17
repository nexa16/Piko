# Contributing

Use [developer setup](docs/development.md) for commands and [documentation maintenance](docs/maintenance.md) when updating current-app documentation.

1. Fetch the latest branches. Start ordinary development from the latest `develop` branch.
2. Create a short-lived branch for substantive work; use codex/<short-description> for Codex work.
3. Capture ideas with `piko-spec-update`, refine/prepare rounds with `piko-planning`, and execute explicitly authorized scope with `piko-implementation`. Internal records use the Git-ignored `.local/planning/index.md`; feature records own requirements and one ledger owns execution/evidence. Public documentation describes implemented behavior and has no private planning dependencies.
4. For a completed implementation round, prepare the final diff, verification evidence and candidate APK for the owner's manual review. After approval and the required public-data review, push and open a focused thematic feature Pull Request into `develop`, using an outcome-based title without a release number. Several related specifications may belong to one feature PR.
5. Explain what changed, why it changed, the covered specification IDs/revisions, and how it was checked. Keep implementation commits focused; separate spec commits are optional, not a requirement for integration history.
6. Squash each feature PR into one descriptive commit only after discussion is resolved and required checks pass. Implementation-round PRs also require owner confirmation that the reviewed candidate installs or updates on their phone and passes the agreed happy path. Test dependent features at their integration boundaries; an earlier green aggregate build does not verify a newly split intermediate state.
7. Use `piko-planning` to verify merge/head/content, reconcile current documentation, archive the completed ledger and safely prepare the next branch/ledger. Preserve unique work, ignored planning and artifacts before removing only obsolete idle workspaces/refs. Reuse an already prepared correct branch. Follow the full [implementation round handoff](AGENTS.md#implementation-round-handoff); new scope still needs explicit implementation authorization.

Implementation rounds 1 and 2 describe planning scope, not published releases. The current work is not approved for store publication or promotion to `main`. When the owner later requests a release, create `release/<version>` from the accepted `develop` state, stabilize and verify it, and open a promotion PR into `main`. The version and publication are explicit release-preparation decisions; schema versions and Android debug/release build modes are unrelated and remain unchanged.

Trivial owner-only corrections do not need a formal Pull Request unless a branch rule requires one. The main branch rules take precedence; emergency bypass is reserved for emergencies, not ordinary work.

Owner findings, bugs, defects and feature requests follow the [clarification and investigation workflow](AGENTS.md#owner-findings-and-feature-requests): understand the intended outcome, clarify material details, make a small focused reproduction attempt where possible, and document evidence and agreed behavior in the owning specifications. A report or accepted specification does not authorize app or mockup implementation; that requires an explicit owner request for the clarified scope.

Keep research anonymous and secrets outside tracked files. See [security guidance](SECURITY.md).

Before the first public push, review all proposed files, history, and commit identity metadata with the owner and obtain approval. Review new content before subsequent pushes; escalate any questionable data before publication.
