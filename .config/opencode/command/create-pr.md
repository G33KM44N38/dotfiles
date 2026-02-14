---
description: create a pull request
agent: build
---
Generate a pull request from the current branch to the target branch (defaults to main if no target branch specified).

Analyze the current branch changes, commit history, and generate an appropriate PR title and description following standard PR template format.

Target branch: $ARGUMENTS (defaults to "main" if not provided)

Follow this workflow:
1. **Validate Environment**:
   - Ensure we're in a git repository
   - Determine current branch name
   - Ensure we are not in detached HEAD state
   - Ensure current branch is not the target branch
   - Ensure gh CLI is available
2. **Branch Analysis**:
   - Show current branch name
   - Ensure branch is pushed to remote
   - Get list of commits since branching from target
   - Analyze git diff for changes
3. **Generate PR Content**:
   - Create meaningful PR title based on commits and changes
   - Generate comprehensive PR description with:
     - Summary section explaining the changes
     - Test plan section with testing instructions
     - Any relevant notes about the implementation
4. **Create Pull Request**:
   - Use gh CLI to create PR with generated title and description
   - Handle any errors (authentication, permissions, conflicts)
   - Provide PR URL upon successful creation

Implementation notes / commands:

- Resolve target branch:
  - `TARGET_BRANCH="${ARGUMENTS:-main}"`

- Validate git repo:
  - `git rev-parse --is-inside-work-tree`

- **Get & check current branch name (added):**
  - `CURRENT_BRANCH="$(git branch --show-current)"`
  - If empty, you're likely in detached HEAD:
    - `git rev-parse --short HEAD` (for helpful context)
    - Error: "Detached HEAD state; please checkout a branch before creating a PR."
  - Output:
    - `echo "Current branch: ${CURRENT_BRANCH}"`

- Ensure current branch != target branch:
  - If `${CURRENT_BRANCH} == ${TARGET_BRANCH}`:
    - Error: "Current branch is the same as target branch; refusing to create PR."

- Check gh CLI exists:
  - `command -v gh`

- Check gh auth:
  - `gh auth status`

- Ensure branch is pushed to remote:
  - Check upstream:
    - `git rev-parse --abbrev-ref --symbolic-full-name @{u}`
  - If missing upstream, push and set:
    - `git push -u origin "${CURRENT_BRANCH}"`
  - Otherwise, ensure remote has latest:
    - `git push`

- Commits since branching from target:
  - `git fetch origin "${TARGET_BRANCH}"`
  - Base:
    - `BASE="$(git merge-base HEAD "origin/${TARGET_BRANCH}")"`
  - Commits:
    - `git log --oneline "${BASE}..HEAD"`

- Diff analysis:
  - `git diff --stat "origin/${TARGET_BRANCH}...HEAD"`
  - `git diff "origin/${TARGET_BRANCH}...HEAD"`

- Create PR via gh:
  - `gh pr create --base "${TARGET_BRANCH}" --head "${CURRENT_BRANCH}" --title "${TITLE}" --body "${BODY}"`

Error Handling:
- Check if current branch is same as target branch
- Verify branch name exists (not detached HEAD)
- Verify branch is pushed to remote (push if needed)
- Handle cases where no commits exist since branching
- Check for gh CLI authentication
- Provide helpful error messages for common issues

Output:
- Show `Current branch: <name>` early
- Show generated PR title and description before creating
- Confirm PR creation with URL
- Provide next steps (review process, etc.)
