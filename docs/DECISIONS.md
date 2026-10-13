# Decision log

Planning documents are the initial source of truth. Record accepted changes here and update the affected documents.

## Initial decisions — 2026-10-13

| Date | Decision | Status | Context | Alternatives | Reason | Consequences |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-10-13 | GitHub is used for version history and future collaboration. | Accepted | Piko needs a durable planning home. | Local-only documents or another host. | Owner selected GitHub. | Changes have version history and a collaboration path. |
| 2026-10-13 | The repository begins public. | Accepted | Repository bootstrap. | Private repository. | Owner selected public visibility. | Commit only material suitable for public access. |
| 2026-10-13 | Planning documents are the initial source of truth. | Accepted | Product discovery precedes implementation. | Code-first or external planning tools. | Keep planning lightweight and versioned. | PRODUCT.md defines the product; this log records choices. |
| 2026-10-13 | No GitHub Project or Luufi integration is required for the discovery phase. | Accepted | Low initial delivery volume. | Add integrations immediately. | Owner requested a lightweight bootstrap. | Revisit only when delivery volume justifies more tooling. |
| 2026-10-13 | No application stack is selected during repository bootstrap. | Accepted | Product needs and platform are unresolved. | Select a framework now. | Discovery must inform the technical foundation. | No framework or package manifests are introduced. |
| 2026-10-13 | No open-source license is selected yet. | Accepted | Licensing has not been decided. | Select a license now. | Owner deferred the choice. | Public visibility grants no additional reuse rights through a license. |

## Bootstrap additions — 2026-10-13

| Date | Decision | Status | Context | Alternatives | Reason | Consequences |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-10-13 | Integrate the supplied Piko specifications, handoff, and navigation mockup in the initial repository setup. | Accepted | Existing planning is available. | Keep a blank brief only. | Owner requested preserving the existing work. | PRODUCT.md links detailed requirements; remaining unknowns stay explicit. |
| 2026-10-13 | Commit and push the initial bootstrap to main; create develop from it. Main serves releases and develop serves development. | Accepted | Establish branch roles before future implementation. | One branch only. | Owner selected the branch model. | Feature branches target develop; release-ready promotion targets main through a PR. No release is declared. |
| 2026-10-13 | Start GitHub CLI web authentication, show the device code, and open a visible Codex browser tab; the user completes sign-in and authorization. | Accepted | The assisted device-login flow succeeded. | Ask the user to run the command, or use the default browser. | Owner selected this as the project's default authentication flow. | Use the default browser only as a fallback; verify nexa16 before resuming and keep authentication data out of commits. |
| 2026-10-13 | Review the complete proposed publication with the owner before the first push; review new content before later pushes. | Accepted | Repository will be public. | Publish without a shared review. | Owner requested a project-wide public-data review rule. | Inspect contents, history, identities, and metadata; obtain first-push approval and escalate questionable data. |

## Documentation cleanup — 2026-10-13

| Date | Decision | Status | Context | Alternatives | Reason | Consequences |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-10-13 | Consolidate the specification index into PRODUCT.md and integrate unique handoff decisions into the specifications. Retain original handoff materials locally, excluded from Git and published history. | Accepted | Overlapping documents complicated navigation. | Publish all overlapping transfer documents. | Owner approved cleanup and local-only handoff retention. | Public documentation stands alone; unpublished bootstrap history must exclude the originals. |
| 2026-10-13 | Record five Collection Overview annotations without applying mockup changes yet. | Accepted | Owner supplied browser feedback and requested deferral. | Change the mockup immediately. | Owner wants the annotations remembered for a later UX pass. | UX specification holds the pending feedback; final wording and layout remain open. |

## Template for the next decision

- **Date:** To be decided — when was this choice accepted?
- **Decision:** To be decided — what exactly was chosen?
- **Status:** Proposed / Accepted / Superseded
- **Context:** To be decided — what prompted the decision?
- **Alternatives:** To be decided — what other options were considered?
- **Reason:** To be decided — why was this option selected?
- **Consequences:** To be decided — what changes, constraints, or follow-up work result?
