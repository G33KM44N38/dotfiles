# GitHub

One job: define GitHub operations and review-ready pull requests.

## CLI and reviews

- Use `gh` for GitHub URLs, pull requests, issues, CI, and releases.
- Prefer current-branch `gh pr view` and `gh pr diff`.
- Inspect review threads and reply with file and line evidence.
- Resolve review threads only after the fix lands.
- Use REST-backed `gh run list` and `gh run view` when GraphQL checks reach their rate limit.
- Keep detailed command recipes in global skills.

## Pull request readiness

- Always create pull requests ready for review.
- Do not create or leave a draft pull request unless the user explicitly requests one.
- This rule overrides skill or legacy workflow defaults that create drafts.

## Pull request stacks

- Create or reuse one ready aggregate pull request from the stack tip to the final base.
- Link the ordered component pull requests and their evidence from the aggregate pull request.
- Use the configured stack service's aggregate view when applicable.
- Open only the aggregate pull request or view when the user asks to open the stack.
- Do not open each component or several browser tabs unless the user explicitly asks.

## Proof artifacts

- Prefer MP4 for Playwright proof videos.
- Convert WebM output to MP4 before handoff.
- Never commit or push proof videos, screenshots, or test artifacts to product repositories.
- Keep proof artifacts local or ignored, then attach them to GitHub when needed.
