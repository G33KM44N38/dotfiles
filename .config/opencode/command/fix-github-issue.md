---
description: Comprehensively fix GitHub issues from URL or issue number
agent: build
model: anthropic/claude-3-5-sonnet-20241022
---

Fix GitHub issue: $ARGUMENTS

Follow this comprehensive workflow to address the GitHub issue:

## 1. **Issue Analysis & Validation**
- Parse the input to determine if it's a GitHub URL (https://github.com/owner/repo/issues/N) or just an issue number
- If just a number, detect the current repository from git remote origin
- Fetch the issue details using GitHub CLI: !`gh issue view $ISSUE_NUMBER --json title,body,labels,state,assignees,milestone`
- Validate that the issue exists and is open
- Extract key information: title, description, issue type (bug/feature/enhancement), labels, and requirements

## 2. **Issue Context & Repository Analysis**
- Get current repository structure: !`find . -type f -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" | head -20`
- Check recent commits related to the issue: !`git log --oneline --grep="#$ISSUE_NUMBER" -10`
- Identify relevant files based on issue description and error traces
- Check if there are existing tests: !`find . -path "*/test*" -o -path "*/spec*" -o -name "*test*" -o -name "*spec*" | head -10`
- Review project structure and dependencies: !`ls -la && cat package.json 2>/dev/null || cat Cargo.toml 2>/dev/null || cat requirements.txt 2>/dev/null || echo "No standard dependency file found"`

## 3. **Create Implementation Plan**
Based on the issue type and analysis:

### For Bug Fixes:
- Identify the root cause from error messages/stack traces
- Locate the problematic code sections
- Plan the fix with minimal impact
- Identify tests that need updating or creation

### For Features:
- Break down the feature requirements
- Identify files that need modification or creation
- Plan the implementation approach
- Design the API/interface if applicable

### For Enhancements:
- Understand the current implementation
- Plan incremental improvements
- Consider backward compatibility

## 4. **Implementation**
Execute the planned changes:
- Create or modify necessary files
- Implement the fix/feature with clean, well-documented code
- Follow the project's coding standards and patterns
- Add appropriate error handling and edge case coverage
- Ensure the solution addresses all aspects mentioned in the issue

## 5. **Testing & Validation**
- Run existing tests to ensure no regressions: !`npm test 2>/dev/null || cargo test 2>/dev/null || python -m pytest 2>/dev/null || go test ./... 2>/dev/null || echo "No standard test command found"`
- Create new tests for the fix/feature if needed
- Perform manual testing of the specific issue scenario
- Validate that all requirements from the issue are met
- Test edge cases and error conditions

## 6. **Documentation Updates**
If applicable:
- Update README.md with new features or changed behavior
- Update API documentation
- Add or update code comments for complex logic
- Update changelog if the project maintains one

## 7. **Commit with Proper Message**
Create a well-formatted commit message:
- Use conventional commits format if the project follows it
- Reference the issue number in the commit message
- Include a clear description of what was fixed/implemented
- Example formats:
  - "fix: resolve memory leak in data processing (#123)"
  - "feat: add user authentication system (#456)"
  - "docs: update API documentation for new endpoints (#789)"

Execute: !`git add . && git status`

## 8. **Optional: Create Pull Request**
If requested or if it's best practice for the project:
- Push the changes to a new branch named like "fix-issue-$ISSUE_NUMBER" or "feature-issue-$ISSUE_NUMBER"
- Create a pull request that references and closes the issue
- Include a comprehensive PR description with:
  - Summary of changes
  - How the issue was resolved
  - Testing performed
  - Any breaking changes or migration notes

Use: !`gh pr create --title "Fix #$ISSUE_NUMBER: [descriptive title]" --body "Fixes #$ISSUE_NUMBER\n\n## Changes\n[description of changes]\n\n## Testing\n[testing performed]\n\n## Notes\n[any additional notes]"`

## 9. **Final Verification**
- Ensure all changes are committed
- Verify the issue requirements are fully addressed
- Run a final test suite if available
- Provide a summary of what was accomplished

## Error Handling
Throughout the process, handle common scenarios:
- Issue not found or inaccessible
- Missing GitHub CLI or insufficient permissions  
- Build/test failures
- Git repository issues
- Network connectivity problems

## Output Summary
Provide a comprehensive summary including:
- Issue details and type
- Changes made (files modified/created)
- Tests run and results
- Commit message used
- Next steps (PR creation, manual testing needed, etc.)
- Any remaining tasks or considerations

**Note:** This command requires GitHub CLI (gh) to be installed and authenticated. Install with `brew install gh` or `sudo apt install gh`, then authenticate with `gh auth login`.