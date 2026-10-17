# Working on Piko

- Read README.md and all relevant docs before changing scope.
- Use the Git-ignored `.local/planning/index.md` to locate current product contracts, quick specs, priorities and the single active ledger. Resolve the canonical store across worktrees; do not create divergent copies.
- Feature records own accepted functional and UX rules in separate sections. Preserve consequential rationale and original evidence in private history; public README/app documentation describes current implemented behavior.
- Do not invent requirements, target users, architecture, or release dates.
- Ask the user when a missing decision would materially change the result.
- Keep raw or identifiable user research outside the public repository.
- Keep secrets out of tracked files and examples.
- Update documentation whenever an accepted decision changes.
- Before UX specification or UI implementation work, read the private planning workflow, shared design record and relevant feature/finding entries. Keep proposed choices explicit and require revision-specific Android verification before marking a finding fixed.
- When implementation begins, add tests alongside behavior.
- Use focused branches named codex/<short-description> for substantive work.
- Keep commits narrowly scoped and explain observable outcomes.
- Do not claim work is complete merely because code was written; verify the intended outcome.
- Add GitHub Project integration or heavier lifecycle automation only when the project's delivery volume justifies it.

## Owner findings and feature requests

- A reported finding, bug, defect or new feature starts clarification and specification work. It never implicitly authorizes implementation, even during an authorized implementation round. Begin implementation only when the owner explicitly requests it for the clarified scope.
- First capture the affected flow, observed behavior or desired outcome as a short Idea/Proposal in its owning feature record using `piko-spec-update`. Do not require full refinement for quick capture or silently turn an ambiguous report into an accepted requirement. Ask when intent itself cannot be recorded accurately or a material decision is needed.
- A very small, focused investigation is appropriate to help understand the issue. Attempt reproduction on the existing Android emulator/device when relevant, or use the available mockup, existing tests or source inspection. Keep the investigation proportional to the report; do not expand it into a broad audit or change app/mockup behavior as a fix.
- Record the exact preconditions, data/state, action sequence, expected versus actual result, relevant build/environment and repeatability that can be established. Distinguish the owner's report, directly observed evidence and hypotheses. Source inspection alone is not runtime reproduction; if reproduction is unavailable or unsuccessful, state the limitation and remaining questions.
- Use `piko-planning` to refine selected quick specs into agreed behavior and concrete acceptance scenarios in their owning functional/UX sections, preserving IDs/revisions. Keep unresolved details and reported-versus-observed evidence explicit; raw recordings and identifying research remain outside the public repository.
- Specification acceptance and successful reproduction do not authorize app or mockup implementation. Keep implementation and verification pending until separately requested and performed.

## Design autonomy and efficient clarification

- Apply the accepted design principles, shared components, tokens and EN/DE copy conventions using agent judgment. Resolve routine layout, control placement, wording and reversible interaction details coherently; do not require the owner to align on each choice in advance.
- For an accepted scope, ask only when the intended outcome is genuinely unclear or a choice would contradict accepted behavior, materially expand scope or put data/learning preservation at risk. An implementation detail listed as open is not automatically an owner approval gate. Record the chosen detail in its owning specification when resolved.
- Use the working Flutter app as the primary UI review surface, guided by the canonical functional/UX/design requirements. HTML mockups and small sketches are optional exploration tools when they resolve a real uncertainty or the owner requests them; do not maintain a parallel mockup implementation of every app change.
- After implementation is authorized, verify the actual app and let the owner give design feedback on the working result. Intermediate design reviews are optional, not a routine prerequisite. This does not waive automated/Android checks or the existing publication and phone-acceptance gates.
- Keep documentation proportional: the index owns ordering, feature records own meaning, and one active ledger owns authorization/progress/evidence. Rewrite current rules in place rather than appending repeated status narratives. Preserve IDs and historical evidence.

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
- Keep secrets, identifiable research and raw recordings outside the public repository. Internal planning may use the owner's explicit Git-ignored `.local/planning/` exception; never stage or publish its contents. Use explicitly listed files when staging; do not stage unrelated local files.

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
5. Use `piko-planning` to fetch and verify the merged result before removing completed local/remote branches or worktrees. Squash merges require PR/head and content verification, not only ancestry. Preserve dirty files, unique commits, APKs, evidence and the entire ignored planning store; a managed Git archive may omit ignored files. Wait for affected chats to be idle, then remove only verified obsolete targets. Do not delete unrelated/active work.
6. Reconcile implemented work into concise private contracts and current public feature/technical documentation if omitted; retain partial delivery and acceptance gaps. Archive the completed ledger. Update local `develop` safely and create or reuse the correctly based `codex/round-<next>-implementation` branch with one prepared ledger. Refine quick specs and suggest an ordered next scope. Branch preparation or scope acceptance does not authorize app/mockup execution; that remains a separate explicit request.

This handoff is development integration. Release branches, promotion to `main`, tags and store publication retain their separate owner-requested process.

## Internal planning and skills

- Read the private planning index/workflow, affected feature records and current ledger; read original history only when needed. If the private store is unavailable, locate/recover it before changing affected requirements. Do not infer contracts from obsolete public snapshots.
- `piko-spec-update` captures ideas/findings as lightweight quick specs and applies explicit accepted requirement changes. `piko-planning` refines candidates, verifies prior integration, safely prepares branch/ledger and proposes scope. `piko-implementation` executes authorized revisions, tests/Android checks and the existing handoff. Existing decisions persist across these skills.
- Keep IDs stable; increment behavior revisions only for accepted behavior changes, not editorial repair or defects against unchanged rules. Preserve dropped/superseded IDs and evidence in history. Owner decisions are required before dropping uncertain accepted intentions.
- Findings live beside their owning requirements with stable Fxx IDs and their original lifecycle/evidence. Migration, a commit, a passing host test or a mockup never closes Android verification. Reopen the same finding for a regression.
- Keep one short index link per relevant planning item, no parallel backlog/decision/status registers. Move completed ledgers and superseded narratives into history after preserving provenance. Git ignore is not a backup or erasure of old published commits; preserve private planning before checkout cleanup.
- Sustained planning/implementation work posts meaningful chat progress at checkpoints, verification results, discoveries and blockers. Keep silence below 60 seconds where tool execution permits; use bounded waits. Say what finished, current uncertainty and next action without raw logs or repeated unchanged updates.
- Public documentation stands alone and describes implemented capabilities/limitations. Private planning links, account/budget notes, local absolute paths and raw evidence do not belong in tracked documents or PR descriptions. Preserve the original handoff privately; do not publish `.local/`.
- Use the working Flutter app as the primary UI review surface. HTML mockups remain optional historical/exploratory references using sample data; update only when requested or useful for an unresolved design question. No parallel Figma source or mandatory duplicate implementation.
- `shared/copy.js` owns EN/DE wording and placeholders. `shared/design-config.js` owns semantic colors, spacing, typography, radii, dimensions and component roles; adapters are not independent defaults. Keep generated app adapters aligned. The approved nine-color palette and existing accepted design rules remain authoritative; studio experiments stay drafts.
- Preserve explicit owner choices, apply design autonomy within accepted scope and document meaningful decisions in the owning record. Keep prototype/studio summaries factual, distinguish browser evidence from Android, and never infer a release schedule or implementation authorization.
