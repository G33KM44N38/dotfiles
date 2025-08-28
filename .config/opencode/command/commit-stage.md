Create a well-formatted commit message for the currently staged files and commit them using `git commit`.

Follow these steps:
1. Check what files are currently staged using `git status --porcelain` and `git diff --cached --name-only`
2. If no files are staged, inform the user and exit
3. Generate a clear, conventional commit message based on the staged changes
4. Use `git commit` (NOT `git add`) to commit only the staged files
5. Show the commit hash and summary of what was committed

Requirements:
- Only commit files that are already staged (in the git index)
- Do NOT stage any additional files
- Generate conventional commit messages (feat:, fix:, docs:, refactor:, etc.)
- Include a brief description of the changes
- Verify the commit was successful

If arguments are provided via $ARGUMENTS, use them as additional context for the commit message.

Example workflow:
- Check staged files: `git diff --cached --name-only`
- Generate appropriate commit message based on file changes
- Commit with: `git commit -m "generated message"`
- Show result: `git log -1 --oneline`
