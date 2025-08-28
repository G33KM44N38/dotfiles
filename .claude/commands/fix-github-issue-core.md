---
description: Fix GitHub issues using the agent-core orchestration workflow with state management and subagent coordination
agent: agent-core
model: opencode/grok-code
---

Fix the GitHub issue: $ARGUMENTS

Use the full agent-core orchestration workflow to comprehensively address this GitHub issue:

## Task Overview
- Parse the GitHub issue URL or number from $ARGUMENTS
- If just a number, detect current repository from git remote
- Fetch issue details and analyze requirements
- Execute the complete agent-core workflow for implementation

## Orchestrated Workflow Steps

### 1. Initialization & State Setup
- Initialize `.opencode/state/` directory structure
- Create session.json with unique workflow ID
- Load or discover project context into shared.json

### 2. Planning Phase
- Call planner subagent with issue context
- Generate structured implementation plan
- Save plan to `.opencode/state/artifacts/plans/`
- Update shared context with planning decisions

### 3. Task Breakdown
- Call task-manager subagent with plan context
- Break down into executable tasks with dependencies
- Create task queue in `.opencode/state/workflow/task-queue.json`
- Update contexts with task insights

### 4. Implementation Loop
- For each task in queue:
  - Call worker subagent with full context
  - Implement code changes
  - Update shared context with changes
  - Call testing-expert subagent for validation
  - Update context with test results
  - Mark task complete or flag for revision

### 5. Quality Assurance
- Call reviewer subagent with complete implementation context
- Extract security and quality findings
- Update shared context with review results
- Loop back to implementation if critical issues found

### 6. Documentation & Finalization
- Call documentation subagent with full feature context
- Update documentation as needed
- Mark workflow complete
- Provide comprehensive summary with state references

## State Management Requirements
- Maintain persistent state across all phases
- Update shared.json after each agent interaction
- Log workflow history and decisions
- Ensure state consistency and backup critical changes

## Output Summary
Provide a final summary including:
- Issue details and resolution approach
- All changes made (files, commits)
- Test results and quality metrics
- Documentation updates
- Workflow completion status

## Usage Examples

### Basic usage with issue number:
```
/fix-github-issue-core 123
```

### Usage with full GitHub URL:
```
/fix-github-issue-core https://github.com/owner/repo/issues/456
```

### Advanced usage with additional context:
```
/fix-github-issue-core 789 --priority high --assignee @username
```

**Note:** This command leverages the full agent-core orchestration system for comprehensive issue resolution with persistent state management and specialized subagent coordination. Ensure all required tools and permissions are available for GitHub CLI operations.
