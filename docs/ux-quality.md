# UX quality workflow and design consolidation

Reconciliation status, 2026-10-16: this preserves the accepted preparation criteria. Round-3 checkpoints 1–4 now record related implementation and scoped verification in [implementation-round-3.md](implementation-round-3.md). F01–F18 retain their recorded specified status until their complete acceptance criteria receive finding-specific evidence; historical preparation statements are not claims that the current app is unimplemented. New implementation is not authorized by this record.

Status: workflow, reviewed typography/copy and four state designs accepted on 2026-10-16. Nunito Sans is the selected interface family. This document does not claim Android integration, fixed findings or release acceptance.

Design acceptance is complete for this preparation package. F01–F18 are specified; none is Fixed. Canonical runtime integration and native verification belong to the implementation packages.

## Sources of truth

- Product and functional requirements own outcomes and data behavior. UX requirements own screen/state presentation. DESIGN owns shared visual rules. The findings register owns status, not a competing full specification.
- Existing requirement IDs stay stable. Revise accepted requirements in place; add an ID only for a genuinely new shared requirement. Historical implementation checkpoints remain evidence of their recorded revision, not the current status.
- Preserve the finished round-2 baseline and newer accepted definitions, including round-3 checkpoint evidence. JSON presentation follows UX-IMPORT-JSON-001 revision 3 and UX-IMPORT-JSON-002 revision 2; IMPORT-JSON-003 remains Later and the plain-book launcher remains pending integration. Do not revert those boundaries while integrating this package.
- Canonical tokens and EN/DE copy remain single sources. Prototypes are illustrative. Do not reproduce known prototype defects in Android.

## Before a UI feature is ready to implement

Specify its owning requirement/revision, user outcome, shared components and roles, copy keys, meaningful empty/loading/error/pending/success/disabled states, keyboard/dismissal behavior and long-content/text-scaling behavior. Include testable acceptance scenarios and relevant open findings. A required exception is documented with rationale; it is not silently introduced as a screen-local default.

## Shared design contract

- Every action color has a foreground/background pair. Use only the agreed palette roles and documented alpha blends for app UI; original artwork and OS interfaces retain their own appearance. Explicitly map framework defaults that could introduce extra colors.
- Use named typography roles, shared spacing/radii and existing Lucide icons. Nunito Sans is selected; the accepted role sizes and reviewed Korean fallback are defined in DESIGN.md. Keep offline font assets and license notices; verify glyph coverage, weight mapping and Android metrics.
- Grow or rearrange content before clipping meaningful labels. Decision labels and validation text remain complete. Titles move to a separate row when actions constrain them. Keep accessible text scaling; do not shrink it to force a fit.
- Long input values may scroll inside an editable field; read-only content needs an explicit wrap/truncation policy and access to the full value. Do not infer support for every writing system from the Korean sample.
- Preserve purpose-based dialog dismissal, safe focus, changed-only Apply, pending-write guards and learning/data semantics. A stable selection shell must not jump when its footer appears.
- UI wording names observable outcomes. Keep EN/DE meaning equivalent, preserve placeholders, distinguish current due state from completion/mastery, and test new longer labels at their actual width.

## Finding lifecycle

Use open → specified → in_progress → needs_verification → fixed. Deferred requires a reason. Reopen the same ID with a history event for a regression; assign the next ID to an independent issue. Severity and implementation order are separate.

Specified requires an accepted concrete decision, owning requirement revision and acceptance criteria. Fixed requires implementation revision, relevant passing checks, a named Android state inspection and evidence reference. A mockup, commit, generated file or host test alone is insufficient. Preserve original observations and prior verification history.

## Review selection and economy

For each change inspect the affected component/state and direct neighboring flow. At round end review changed areas and findings awaiting verification, plus six anchors: Collection Detail; vocabulary entry with keyboard; selection dialog; JSON preview; revealed review; Speed setup.

For a global font/theme/navigation/dialog change expand to all affected consumers, without multiplying every screen by every locale and scale. Main capture: English, normal emulator size and text scale. Use targeted German, 320 logical-pixel width and 200% text for changed or length-sensitive components. Reuse existing fixtures and tests; do not claim browser text scaling equals Android.

Read the change summary, relevant requirements and active register first, not the entire old audit each time. Capture only changed/new/reverification states; record unchanged states as reused evidence with their original revision. Render reports from the register. De-duplicate before adding findings. Broaden a review only when a shared cause or new failure justifies it.

Existing host checks cover catalog generation, placeholder parity, semantics and many responsive components. Extend them for observable behavior such as stable row position, action reachability and draft preservation. Keep visual judgement explicit; do not create a brittle screenshot test for every cosmetic edit or introduce heavy automation without demonstrated need.

## Android and evidence safeguards

Batch emulator work and yield to implementation. Use the established isolated fixtures, same-schema restoration and preservation procedure; never clear normal app data. Store raw captures and detailed local evidence outside publication. Public summaries/registries contain no machine-specific paths or personal data.

Each review manifest records app/source revision, spec revisions, fixture version, locale, logical size/text scale, checked states, failures and gaps. Prior evidence is not fresh verification. Native keyboard, clipboard and restoration claims require native evidence.

## Implementation order

Follow [the accepted implementation packages](ux-implementation-plan.md). Shared foundations precede new consumers; independent owning packages may proceed after their prerequisites. The order does not authorize extra features or a release.

## Render a status report without re-reviewing unchanged screens

Run `python tools/render-ux-review.py --registry docs/ux-findings.json --out .local/ux-review/current/index.html`. Add `--evidence-root` with the local original review directory to link historical captures. The renderer never edits the registry or assigns status; unavailable evidence links are explicit. New evidence can use a `file` reference relative to that evidence root.

When marking Fixed, record `verifiedAt` and a `verification` object containing the implementation revision, checked requirement revisions, relevant checks, named Android states and evidence references. Keep historical evidence and history events. Update status deliberately, then regenerate the report. Do not replay the one-time preparation scripts, which would rebuild the old snapshot.
