---
name: attach-pr-artifacts
description: Upload local screenshots, images, GIFs, and proof videos to a GitHub pull request and place them reliably in the PR body or a comment. Use when Codex needs to add, attach, embed, replace, arrange, or verify visual artifacts on a PR, including before/after evidence, image grids, screen recordings, MP4 proof, or GitHub user-attachment URLs.
---

# Attach PR artifacts

Upload binaries directly with the GitHub token managed by `gh`. Use `gh` for PR discovery, body or comment updates, and read-back verification. This workflow does not need Chrome, browser control, browser cookies, or Computer Use.

The upload helper uses GitHub's token-authenticated `uploads.github.com/user-attachments/assets` endpoint. This endpoint is not part of GitHub's documented REST API, so treat HTTP failures as a possible upstream protocol change and report them honestly.

## Workflow

1. Resolve the PR.
   - Prefer the current branch when no PR URL or number was supplied: `gh pr view --json number,url,title,body,headRefName,baseRefName`.
   - For a GitHub URL, use `gh`, not generic web fetching, to inspect the PR.
   - Confirm that every artifact belongs to this PR. Do not upload unrelated local files.

2. Inspect and prepare every artifact.
   - Run `scripts/prepare_artifacts.sh <paths...>` from this skill directory.
   - Use the `READY` paths it prints. It validates image limits and converts incompatible videos to H.264 MP4 with `yuv420p` and fast-start metadata.
   - Keep generated proof files in `/tmp` or another ignored directory. Never commit or push them.
   - GitHub accepts PNG, GIF, JPEG, and SVG images up to 10 MB. It accepts MP4, MOV, and WebM video. Video is limited to 10 MB on free plans and can be up to 100 MB on paid plans. Prefer an MP4 below 10 MB when practical.

3. Choose the destination.
   - If the user named a body section or comment, honor it.
   - Otherwise, add or update one `## Proof` section in the PR body. Do not create a second proof section.
   - Preserve the rest of the body byte-for-byte where practical. Read the current body before editing.
   - Use a new PR comment only when the user asks for a comment or the body cannot be edited.

4. Upload through GitHub's user-attachments endpoint.
   - Run `scripts/upload_artifacts.sh --repo OWNER/REPO <ready-paths...>` from this skill directory.
   - The helper resolves the repository's numeric ID, checks push permission, reads the active token with `gh auth token`, uploads raw bytes, and prints Markdown containing stable `https://github.com/user-attachments/...` URLs.
   - Use `--json` when structured output is easier to consume. It prints one JSON object per artifact with `path`, `name`, `kind`, `content_type`, `url`, and `markdown` fields.
   - Keep each returned URL unchanged. Replace the filename alt text for images with a useful description before publishing.
   - Use `gh pr edit --body-file` to update a PR body. Use `gh pr comment --body-file` only when the chosen destination is a new comment.
   - Save only after every upload succeeds. Uploading creates the attachment, but it does not edit the PR by itself.

5. Format the result.
   - Image: `![Short description](https://github.com/user-attachments/assets/...)`
   - Video: keep the generated attachment URL on its own line. Do not wrap video URLs in image syntax.
   - Put a short label above each artifact when the meaning is not obvious.
   - For a requested four-image grid, use a two-column Markdown table with two image rows. Never squeeze videos into a grid.

   ```markdown
   | Before | After |
   | --- | --- |
   | ![Before, first view](URL_1) | ![After, first view](URL_2) |
   | ![Before, second view](URL_3) | ![After, second view](URL_4) |
   ```

6. Verify after saving.
   - Read the saved PR body or comment with `gh` and confirm that every expected attachment URL is present exactly once.
   - Fetch every attachment URL with an authenticated `curl` request and confirm that GitHub returns a successful status and the expected content type. Do not use a browser for verification.
   - Check that labels match the right files and that the rest of the PR body was preserved.
   - Report success only after the API read-back and attachment checks pass.

## Failure handling

- If `gh auth status` fails, ask the user to authenticate `gh` and continue after they confirm.
- If the upload endpoint returns 401 or 403, verify the active `gh` account and repository permission without printing the token.
- If it returns 404, verify the numeric repository ID and push permission.
- If it returns 422, re-run preparation and verify the file type and size. The endpoint may reject a type that the web interface accepts.
- If the upload protocol changes, stop with the exact HTTP error. Do not fall back to Chrome, browser control, Computer Use, release assets, or repository commits unless the user explicitly requests another method.
- If the file is rejected, re-run the preparation script and fix the reported format or size problem. Do not retry the same invalid binary repeatedly.
- If the PR body already contains stable GitHub user-attachment URLs, reuse them instead of uploading duplicate binaries.
- If saving changed unrelated PR text, restore the prior body and retry with the smallest edit.

## Safety

- Uploaded files in public repositories are publicly accessible. For private repositories, repository readers can access them.
- Inspect filenames and visible content for secrets, tokens, customer data, notifications, and unrelated browser chrome before upload.
- Never commit proof screenshots, videos, or generated test artifacts to the product repository.
- Never delete source artifacts. Leave cleanup to explicit user direction and use `trash` for user-authorized deletion.
