---
name: attach-pr-artifacts
description: Upload local screenshots, images, GIFs, and proof videos to a GitHub pull request and place them reliably in the PR body or a comment. Use when Codex needs to add, attach, embed, replace, arrange, or verify visual artifacts on a PR, including before/after evidence, image grids, screen recordings, MP4 proof, or GitHub user-attachment URLs.
---

# Attach PR artifacts

Use GitHub's authenticated web attachment control for binary uploads. Use `gh` for PR discovery, metadata, and read-back verification. GitHub's documented REST and GraphQL APIs do not provide the normal PR attachment upload flow, so do not invent an API endpoint or use an undocumented upload endpoint.

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

4. Upload through the GitHub PR page.
   - Use an available Browser or Chrome browser-control skill and follow its setup instructions. Do not use Computer Use unless the user explicitly requested Computer Use.
   - Open the resolved PR URL and use the Conversation tab.
   - Edit the PR body or open the requested comment box. Place the cursor inside the intended section.
   - Use GitHub's `Attach files` control and select the local file. Do not paste base64, a `file://` URL, or a repository path.
   - Wait for each upload to finish. Success means the editor contains a stable `https://github.com/user-attachments/assets/...` URL and no upload placeholder or progress indicator remains.
   - Add useful alt text to images. Keep the uploaded URL unchanged.
   - Save the body or submit the comment only after every upload has finished.

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
   - Reopen or refresh the PR page and verify that images render and videos show a playable attachment instead of plain broken text.
   - Check that labels match the right files and that the rest of the PR body was preserved.
   - Report success only after this read-back and rendered-page check.

## Failure handling

- If GitHub asks for authentication, ask the user to sign in to the selected browser and continue after they confirm.
- If upload remains in progress, wait and inspect again. Do not save a temporary `Uploading...` token.
- If the file is rejected, re-run the preparation script and fix the reported format or size problem. Do not retry the same invalid binary repeatedly.
- If the PR body already contains stable GitHub user-attachment URLs, reuse them instead of uploading duplicate binaries.
- If browser control cannot select a local file, stop and give the user the prepared absolute path plus the exact destination section. Do not claim the artifact was attached.
- If saving changed unrelated PR text, restore the prior body and retry with the smallest edit.

## Safety

- Uploaded files in public repositories are publicly accessible. For private repositories, repository readers can access them.
- Inspect filenames and visible content for secrets, tokens, customer data, notifications, and unrelated browser chrome before upload.
- Never commit proof screenshots, videos, or generated test artifacts to the product repository.
- Never delete source artifacts. Leave cleanup to explicit user direction and use `trash` for user-authorized deletion.
