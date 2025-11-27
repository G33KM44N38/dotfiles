---
description: create a pull request
agent: build
model: anthropic/claude-haiku-4-5
---
Generate a pull request from the current branch to the target branch (defaults to main if no target branch specified).

Analyze the current branch changes, commit history, and generate an appropriate PR title and description following standard PR template format.

Target branch: $ARGUMENTS (defaults to "main" if not provided)

Follow this workflow:
1. **Validate Environment**: Ensure we're in a git repository, current branch is not the target branch, and gh CLI is available
2. **Branch Analysis**: 
   - Get current branch name
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

Error Handling:
- Check if current branch is same as target branch
- Verify branch is pushed to remote (push if needed)
- Handle cases where no commits exist since branching
- Check for gh CLI authentication
- Provide helpful error messages for common issues

Output:
- Show generated PR title and description before creating
- Confirm PR creation with URL
- Provide next steps (review process, etc.)
