Generate a pull request from the current branch to the target branch (defaults to main if no target branch specified).

Analyze the current branch changes, commit history, and generate an appropriate PR title and description following a standard PR template format.

Target branch: $ARGUMENTS (defaults to "main" if not provided)

Follow this workflow:

1. **Validate Environment**
   - Ensure we're in a git repository
   - Ensure the current branch is not the target branch
   - Ensure the `gh` CLI is available
   - Check `gh` CLI authentication status

2. **Branch Analysis**
   - Get the current branch name
   - Ensure the branch is pushed to remote
   - Get the list of commits since branching from the target branch
   - Analyze the git diff for changes
   - Identify the previous behaviour affected by the changes
   - Identify the expected behaviour after the changes

3. **Generate PR Content**
   - Create a meaningful PR title based on commits and changes
   - Generate a comprehensive PR description that always includes:
     - **Summary**
       - Explain what changed and why
     - **Previous Behaviour**
       - Describe how the feature, bug, flow, or system behaved before this change
     - **Expected Behaviour**
       - Describe how it should behave after this change
     - **Testing**
       - Include clear testing steps performed or recommended
       - Mention manual tests, automated tests, or verification steps where applicable
       - If no tests were run, explicitly state why
     - **Notes**
       - Include any relevant implementation details, risks, limitations, follow-ups, or context

4. **Create Pull Request**
   - Show the generated PR title and description before creating the PR
   - Use the `gh` CLI to create the PR with the generated title and description
   - Handle any errors, including authentication, permissions, branch conflicts, or missing remotes
   - Provide the PR URL upon successful creation

Error Handling:
- Check if the current branch is the same as the target branch
- Verify the branch is pushed to remote, and push if needed
- Handle cases where no commits exist since branching from the target branch
- Check for `gh` CLI authentication
- Provide helpful error messages for common issues

Output:
- Show generated PR title and description before creating the PR
- Confirm PR creation with URL
- Provide next steps, such as review process, CI checks, or follow-up actions
