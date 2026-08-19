---
name: external-proof-workflow
description: Create tracked GitHub pull requests with external-system proof artifacts. Use when work needs Linear linkage, GitHub PR creation, browser/web proof videos, Playwright screenshots/videos, Chrome fallback, or durable before/after evidence for changes that are not visually obvious.
---

# External Proof Workflow

Use this skill when a task leaves the codebase and touches Linear, GitHub, Chrome, Playwright, or proof artifacts.

## Workflow

1. Resolve tracking first.
   - Search Linear before creating a new issue.
   - If creating via GraphQL, use `branchName`, not `gitBranchName`.
   - `AttachmentCreateInput` requires `title`, `url`, and `issueId`. It rejects `data:` URLs; do not try to upload proof binaries that way.

2. Protect base worktrees.
   - If current worktree is `main` or `release`, do not switch branches there.
   - Create a sibling worktree from the remote base:
     `git worktree add -b baba-123-short-slug <path> origin/release`
   - Copy the intended diff with a patch file from `/tmp/`.
   - Fresh worktrees need dependencies. Run repo setup or at least `pnpm install` before formatter/build commands when `node_modules` is missing.

3. Capture web proof.
   - Prefer the in-app Browser skill when available.
   - If `iab` is unavailable, use Playwright directly.
   - If Playwright says the bundled browser is missing, prefer system Chrome before downloading more:
     `chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' })`
   - Record WebM if that is what Playwright emits, then convert to MP4:
     `ffmpeg -y -i proof.webm -movflags +faststart -pix_fmt yuv420p proof.mp4`
   - Keep screenshots/videos in `/tmp` or another ignored location. Never commit proof artifacts.

4. For API-only changes, make proof visual anyway.
   - Generate a small local HTML proof page showing before/after numbers and validation results.
   - Record that page with Playwright/Chrome.
   - State clearly when the proof is local and evidence is derived from code-path query counts rather than production post-deploy telemetry.

5. PR body proof section.
   - Include Linear issue ID/link.
   - Include screenshot and MP4 artifact names/paths if upload is unavailable.
   - Include exact validation commands run.
   - Include before/after numbers in the PR body, not only in the video.

## Gotchas

- Do not paste large base64 proof files into tool calls or comments.
- Do not use `npx` in BabaCoiffure; use `pnpm exec`.
- GitHub origin may use SSH; if push over port 22 fails, switch the push URL to HTTPS or SSH-over-443.
- In a new worktree, Prettier can fail with `Cannot find module '@babacoiffure/prettier-config'` until dependencies are installed.
