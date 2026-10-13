# Working on Piko

- Read README.md and all relevant docs before changing scope.
- Treat docs/PRODUCT.md as the product-definition source of truth.
- Treat docs/DECISIONS.md as the record of deliberate choices.
- Do not invent requirements, target users, architecture, or release dates.
- Ask the user when a missing decision would materially change the result.
- Keep raw or identifiable user research outside the public repository.
- Keep secrets out of tracked files and examples.
- Update documentation whenever an accepted decision changes.
- When implementation begins, add tests alongside behavior.
- Use focused branches named codex/<short-description> for substantive work.
- Keep commits narrowly scoped and explain observable outcomes.
- Do not claim work is complete merely because code was written; verify the intended outcome.
- Add GitHub Project integration or heavier lifecycle automation only when the project's delivery volume justifies it.

## Authentication

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
- Promote accepted development changes to `main` through a Pull Request when the owner requests a release-ready promotion. No release schedule or milestone is implied.
- Reserve owner emergency bypass for emergencies.

## Existing product planning

- Read `docs/PRODUCT.md`, `docs/ROADMAP.md`, `docs/piko-functional.md`, and `docs/piko-ux.md` before product or mockup changes.
- Original handoff materials are local references only. Do not stage or publish `docs/HANDOFF.md` or `.local/`; public documentation must stand on its own.
- Keep pending browser annotations in the UX specification. Do not apply deferred mockup changes until the user asks.
- `docs/PRODUCT.md` is the product brief and scope entry point; it links the detailed functional and UX requirements. Keep behavior and UX specifications separate and preserve requirement IDs.
- Respect confirmed requirements. Keep proposals, open questions, and deferred ideas explicit; newer accepted decisions supersede conflicting legacy text.
- Continue UX work page by page in `mockups/piko-mockup.html`, updating the relevant UX documentation together.
- The mockup uses sample data and placeholders. Do not represent its persistence, AI, import, or learning calculations as working application features.
- Do not implement an application or select a stack until the user requests that work.
- Use `shared/copy.js` as the single source for interface labels and English/German translations. Preserve stable keys and matching placeholders; do not duplicate UI wording in mockup templates or future app code.
- Record proposed visual principles in `docs/DESIGN.md`. Update accepted design decisions, relevant UX requirements, shared tokens/copy, and mockup together. Keep the prototype aligned with the future product without treating proposals as accepted decisions.
- Use `shared/theme.js` for canonical semantic color roles; Cobalt is the current baseline. Keep direct color experiments in the studio as drafts until exported and accepted.
