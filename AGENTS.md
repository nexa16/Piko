# Working on Piko

- Read README.md and all relevant docs before changing scope.
- Treat docs/PRODUCT.md as the product-definition source of truth.
- Treat docs/DECISIONS.md as the record of deliberate choices.
- Do not invent requirements, target users, architecture, or release dates.
- Ask the user when a missing decision would materially change the result.
- Keep raw or identifiable user research outside the public repository.
- Keep secrets out of tracked files and examples.
- Update documentation whenever an accepted decision changes.
- Before UX specification or UI implementation work, read `docs/ux-quality.md` and the relevant entries in `docs/ux-findings.json`. Keep proposed design choices explicit; follow the accepted review scope and require revision-specific Android verification before marking a finding fixed.
- When implementation begins, add tests alongside behavior.
- Use focused branches named codex/<short-description> for substantive work.
- Keep commits narrowly scoped and explain observable outcomes.
- Do not claim work is complete merely because code was written; verify the intended outcome.
- Add GitHub Project integration or heavier lifecycle automation only when the project's delivery volume justifies it.

## Owner findings and feature requests

- A reported finding, bug, defect or new feature starts clarification and specification work. It never implicitly authorizes implementation, even during an authorized implementation round. Begin implementation only when the owner explicitly requests it for the clarified scope.
- First establish what the owner means: the affected flow, observed behavior and intended outcome. Ask focused questions where details materially affect understanding; do not silently turn an ambiguous report into an accepted requirement.
- A very small, focused investigation is appropriate to help understand the issue. Attempt reproduction on the existing Android emulator/device when relevant, or use the available mockup, existing tests or source inspection. Keep the investigation proportional to the report; do not expand it into a broad audit or change app/mockup behavior as a fix.
- Record the exact preconditions, data/state, action sequence, expected versus actual result, relevant build/environment and repeatability that can be established. Distinguish the owner's report, directly observed evidence and hypotheses. Source inspection alone is not runtime reproduction; if reproduction is unavailable or unsuccessful, state the limitation and remaining questions.
- Then document the understood finding and agreed behavior in the owning functional and/or UX specifications, preserving requirement IDs and revision rules. Include reproduction evidence and concrete acceptance scenarios; keep unresolved details explicit and raw recordings or identifying data outside the public repository.
- Specification acceptance and successful reproduction do not authorize app or mockup implementation. Keep implementation and verification pending until separately requested and performed.

## Design autonomy and efficient clarification

- Apply the accepted design principles, shared components, tokens and EN/DE copy conventions using agent judgment. Resolve routine layout, control placement, wording and reversible interaction details coherently; do not require the owner to align on each choice in advance.
- For an accepted scope, ask only when the intended outcome is genuinely unclear or a choice would contradict accepted behavior, materially expand scope or put data/learning preservation at risk. An implementation detail listed as open is not automatically an owner approval gate. Record the chosen detail in its owning specification when resolved.
- Use the working Flutter app as the primary UI review surface, guided by the canonical functional/UX/design requirements. HTML mockups and small sketches are optional exploration tools when they resolve a real uncertainty or the owner requests them; do not maintain a parallel mockup implementation of every app change.
- After implementation is authorized, verify the actual app and let the owner give design feedback on the working result. Intermediate design reviews are optional, not a routine prerequisite. This does not waive automated/Android checks or the existing publication and phone-acceptance gates.
- Keep documentation proportional: maintain the owning requirement and one implementation ledger; use cross-references in summaries instead of repeating the full rules. Preserve stable IDs and historical evidence.

## Authentication

- In this Windows sandbox, GitHub CLI stores authentication outside the workspace in `%APPDATA%\GitHub CLI\hosts.yml`. Start `gh auth login` with `sandbox_permissions: require_escalated` so it can save the authorization on the first attempt. A sandboxed login can complete browser authorization and then fail with Access denied while saving, forcing the owner to authorize a second device code. Do not repeat that known failing path or print/copy credential-file contents.
- Verify the saved session in the same elevated context: the sandbox can still see stale credentials and return HTTP 401 after a successful login. Do not start another device authorization for that mismatch. For elevated repository queries, pass `--repo nexa16/Piko` explicitly to `gh` to avoid Git's different-owner checkout error; do not add a global safe-directory exception merely for a GitHub query.
- If the command-line GitHub session is unauthenticated, start `gh auth login -h github.com --git-protocol https --web` yourself. Present its one-time device code in an easy-to-copy code block and open the verification URL in a visible Codex browser tab; use the user's default browser only when the Codex browser is unavailable.
- Ask the user to complete sign-in and authorization in the browser. Keep the login command waiting, then verify completion and confirm the active account is `nexa16` before resuming. Never commit the one-time code or authentication output.
- If a GitHub browser session requires sign-in, ask the user to sign in. Do not ask the user to send passwords, tokens, recovery codes, or other credentials in chat.
- Authentication is a user-assisted step, not a reason to abandon the task or switch accounts.

## Public-data review

- Before the first push or any first publication of local history, review the complete proposed file set and all commits being published with the user. Present the findings and wait for the user's approval before publishing.
- Check file contents, filenames, metadata, commit author/committer identities, email addresses, and history for credentials, tokens, environment files, private research, personal data, recordings, transcripts, machine-specific paths, and generated artifacts.
- Before subsequent pushes or public uploads, review the new content and commits for the same risks. Stop and involve the user if anything is questionable; never assume an ignore rule is enough.
- Keep private material outside the repository. Use explicitly listed files when staging; do not stage unrelated local files.

## Branches

- `main` is the default branch and the release branch. The initial documentation and mockup bootstrap is committed and pushed to `main` before its ruleset is enabled; this does not declare a release.
- `develop` is the development integration branch, initially created from the bootstrap commit on `main`.
- Base substantive `codex/<short-description>` branches on the latest `develop` and open focused Pull Requests into `develop`.
- Group related specifications into thematic feature PRs and squash each accepted feature PR into `develop`. Keep stable spec IDs, revisions and verification evidence in the PR; one commit per spec on `develop` is not required. Do not use release numbers in development PR titles.
- Implementation rounds are planning scopes, not published versions. Round 1 and round 2 do not authorize a release or store publication.
- Only when the owner requests release preparation, create a `release/<version>` branch from accepted `develop`, verify it and promote it to `main` through a Pull Request. Do not create a release branch, tag or publication now. No version or schedule is implied.
- Reserve owner emergency bypass for emergencies.

## Implementation round handoff

1. Finish the authorized scope, commit it in focused commits, and complete the applicable automated and Android verification. Prepare the owner's manual review with the final diff, covered spec IDs/revisions, test evidence, known limitations and the candidate APK's source commit and checksum. Keep the implementation ledger current; unfinished or deferred work stays explicit.
2. Wait for the owner's manual review approval before pushing the completed round and creating its focused PR into `develop`. Include the public-data review above in the proposed publication review and satisfy its approval requirements. Once approved, proceed without asking for the same approval again. Reuse an existing PR for that branch; use an outcome-based title and retain spec/verification evidence in the description.
3. Keep the PR unmerged until the owner confirms that the candidate APK installs or updates on their phone and the agreed happy path passes, including vocabulary learning and the relevant changed flow. Record which candidate and scenarios were checked and distinguish owner-reported evidence from agent verification. Do not infer broader acceptance from a happy-path check. Resolve any uncertainty about which candidate was tested before merging.
4. After the manual review approval, owner-confirmed phone check, passing required checks and resolved review discussions, squash-merge the approved PR into `develop`. These gates are the standing authorization to complete the merge; do not ask for redundant permission. If the owner already merged it, verify the actual GitHub merge instead. Changes after approval require review and verification of the affected scope; an app change requires an updated candidate and phone check. Never bypass branch protection.
5. Fetch and verify the merged result before deleting the completed branch locally and remotely. Squash merges require PR/head and content verification, not only an ancestry check. Preserve any uncommitted files, unique commits, APKs and useful evidence before cleanup; keep private material outside tracked history. Wait for chats using an affected checkout to be idle, then remove redundant worktrees and only the verified obsolete refs. Do not delete unrelated or active work.
6. Update local `develop` from the fetched integration branch without discarding local work, then create the next round's fresh `codex/round-<next>-implementation` branch from the latest `develop`. Do not continue from the old pre-squash branch. Record the new branch/base and pending scope in the next ledger. Creating the branch permits preparation; new app/mockup implementation still requires the owner's explicit request for the clarified scope.

This handoff is development integration. Release branches, promotion to `main`, tags and store publication retain their separate owner-requested process.

## Existing product planning

- Read `docs/PRODUCT.md`, `docs/ROADMAP.md`, `docs/piko-functional.md`, and `docs/piko-ux.md` before product or mockup changes.
- Original handoff materials are local references only. Do not stage or publish `docs/HANDOFF.md` or `.local/`; public documentation must stand on its own.
- Keep pending browser annotations in the UX specification. Do not apply deferred mockup changes until the user asks.
- `docs/PRODUCT.md` is the product brief and scope entry point; it links the detailed functional and UX requirements. Keep behavior and UX specifications separate and preserve requirement IDs.
- Respect confirmed requirements. Keep proposals, open questions, and deferred ideas explicit; newer accepted decisions supersede conflicting legacy text.
- When mockup work is specifically useful or requested, work page by page in `mockups/piko-mockup.html` and update the relevant UX documentation. A mockup pass is not required before app implementation.
- The mockup uses sample data and placeholders. Do not represent its persistence, AI, import, or learning calculations as working application features.
- Do not implement an application or select a stack until the user requests that work.
- Use `shared/copy.js` as the single source for interface labels and English/German translations. Preserve stable keys and matching placeholders; do not duplicate UI wording in mockup templates or future app code.
- Record proposed visual principles in `docs/DESIGN.md`. Update accepted design decisions and their owning UX requirements; during authorized implementation, keep shared tokens/copy and application adapters aligned. Update mockup behavior only when that work is requested or needed for an unresolved design question. Identify outdated prototype behavior rather than treating it as the current application contract.
- Use `shared/design-config.js` as the single canonical source for semantic colors and reusable spacing, typography, radii, control and component configuration. `theme.js`, `design-tokens.css` and `design-runtime.js` are adapters, not independent defaults. The approved nine-color Piko palette is the sole UI color target for all preview rounds and the application; migration remains pending a separate implementation request. Keep studio experiments as drafts until the unified exported configuration is reviewed and accepted.
- Use accepted UX/design requirements and shared configuration to guide the working application; the HTML/CSS mockup is a historical/exploratory reference, not a pixel-perfect constraint or mandatory duplicate. Preserve confirmed owner choices and correct awkward prototype layouts through the design autonomy above. Record meaningful decisions in the owning UX/design documentation. Do not create a parallel Figma source. Centralize recurring UI components and design tokens, including spacing, typography, radii and dimensions. Keep state variants explicit. Implementation authorization remains scoped to the owner's explicit requests.
- Keep the studio's design summary factual: concrete accepted rules and separately identified open decisions, not vague style slogans. Reconcile each new owner critique into the canonical UX/design documentation and studio summary; do not mark an ambiguous suggestion accepted or claim an unverified implementation complete.
