# OpenCode Configuration

This repository contains the configuration for OpenCode, a sophisticated AI-powered coding assistant system designed to help with software development tasks through specialized agents and commands.

## Overview

OpenCode is an extensible framework that uses multiple specialized AI agents to handle different aspects of software development, from planning and implementation to testing and documentation. The system is configured through a modular architecture with agents, commands, and plugins.

## Core Configuration

### Main Settings (`opencode.json`)

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "opencode/sonic",
  "provider": {},
  "mcp": {}
}
```

- **Model**: Uses `opencode/sonic` as the primary AI model
- **Provider**: Currently empty, can be configured for different AI providers
- **MCP**: Model Context Protocol settings (currently empty)

## Agent Architecture

### Core Agent (`agent/agent-core.md`)

The main agent orchestrates the entire development workflow:

**Key Features:**
- Coordinates multiple specialized subagents
- Manages the development lifecycle
- Ensures quality through structured workflows

**Workflow Sequence:**
1. **Planning**: Analyze incoming requests using the planner agent
2. **Task Management**: Break down features into subtasks using task-manager
3. **Implementation**: Execute tasks using the worker agent
4. **Testing**: Validate code using testing-expert
5. **Review**: Code review using reviewer agent
6. **Documentation**: Generate documentation using documentation agent

### Specialized Subagents

#### 1. Planner (`agent/subagents/planner.md`)
- **Purpose**: Analyzes incoming requests and creates actionable plans
- **Tools**: Read, edit, write, grep, glob, patch
- **Temperature**: 0.1 (focused and consistent)
- **Output Format**: Structured plan with features, objectives, tasks, and dependencies

#### 2. Task Manager (`agent/subagents/task-manager.md`)
- **Purpose**: Breaks complex features into small, verifiable subtasks
- **Tools**: Read, edit, write, grep, glob, patch (with security restrictions)
- **Key Features**:
  - Two-phase workflow (planning → implementation)
  - Atomic task creation with dependencies
  - Structured task files with acceptance criteria
  - Security restrictions (no access to env files, secrets, node_modules, .git)

#### 3. Worker (`agent/subagents/worker.md`)
- **Purpose**: Implements the planned tasks
- **Tools**: Read, edit, write, grep, glob, patch
- **Role**: Executes the actual code changes and implementations

#### 4. Testing Expert (`agent/subagents/testing-expert.md`)
- **Purpose**: Handles software testing including unit, integration, and end-to-end tests
- **Tools**: Read, edit, write, grep, glob, patch
- **Focus**: Quality assurance and test coverage

#### 5. Reviewer (`agent/subagents/reviewer.md`)
- **Purpose**: Code review, security, and quality assurance
- **Tools**: Read, edit, write, grep, glob, patch
- **Role**: Validates code quality and identifies issues

#### 6. Documentation (`agent/subagents/documentation.md`)
- **Purpose**: Writing and maintaining project documentation
- **Tools**: Read, edit, write, grep, glob, patch
- **Focus**: Comprehensive documentation generation

#### 7. Security Auditor (`agent/subagents/security-auditor.md`)
- **Purpose**: Performs security audits and identifies vulnerabilities
- **Tools**: Read, edit, write, grep, glob, patch
- **Focus**: Security analysis and recommendations

## Commands

OpenCode includes various commands for specific development tasks:

### Development Workflow Commands
- **`auto-task.md`**: Automates complete task implementation workflow
- **`generate-task.md`**: Creates structured task files
- **`process-task.md`**: Processes individual tasks with user interaction

### Git and Version Control
- **`commit-stage.md`**: Handles git commits with proper analysis
- **`create-pr.md`**: Creates pull requests with proper formatting
- **`create-prd.md`**: Creates Product Requirements Documents

### Issue Management
- **`fix-github-issue.md`**: Fixes GitHub issues
- **`fix-issue.md`**: General issue resolution

### Quality and Security
- **`audit-security.md`**: Security auditing
- **`security-analyze.md`**: Security analysis
- **`architect.md`**: System architecture planning

## Plugins

### Notification Plugin (`plugins/notification.js`)

Provides macOS notifications for important events:
- **Assistant Message Completed**: Notifies when AI responses are ready
- **Session Idle**: Alerts when the coding session becomes idle

```javascript
// Sends macOS notifications using osascript
await $`osascript -e 'display notification "OpenCode response completed!" with title "OpenCode"'`
```

## Usage Examples

### Basic Development Workflow

1. **Plan a feature**:
   ```
   Use planner agent to analyze requirements
   ```

2. **Break down tasks**:
   ```
   Task manager creates structured subtasks
   ```

3. **Implement**:
   ```
   Worker agent executes the implementation
   ```

4. **Test**:
   ```
   Testing expert validates the code
   ```

5. **Review**:
   ```
   Reviewer agent performs quality checks
   ```

6. **Document**:
   ```
   Documentation agent creates/updates docs
   ```

### Command Usage

```bash
# Auto-implement all tasks in a file
auto-task tasks/feature-implementation.md

# Create a new pull request
create-pr --title "Add user authentication" --body "Implements user login system"

# Fix a GitHub issue
fix-github-issue https://github.com/user/repo/issues/123

# Generate security audit
audit-security --scope src/ --output security-report.md
```

## Configuration Philosophy

### Modularity
- Each agent has a specific, well-defined role
- Commands are focused on particular tasks
- Plugins extend functionality without core modifications

### Quality Assurance
- Multi-layer review process (planning → implementation → testing → review)
- Security restrictions prevent accidental damage
- Comprehensive testing integration

### Automation
- Workflow automation reduces manual overhead
- Consistent formatting and structure
- Error handling and recovery mechanisms

## Integration Points

### With Development Tools
- **Git**: Commit staging, PR creation, branch management
- **Testing Frameworks**: Integration with npm, pytest, etc.
- **CI/CD**: Report generation for automated pipelines

### With AI Models
- Configurable model selection
- Provider abstraction for different AI services
- Context preservation across agent interactions

## Best Practices

1. **Always use the workflow**: Follow the 1→6 sequence for complex tasks
2. **Create atomic tasks**: Break features into small, testable units
3. **Include acceptance criteria**: Define clear completion conditions
4. **Test thoroughly**: Use testing expert for validation
5. **Document changes**: Keep documentation current
6. **Security first**: Run security audits regularly

## Customization

The system is highly customizable:
- Add new subagents for specific domains
- Create custom commands for specialized tasks
- Extend plugins for additional integrations
- Modify workflows for different development methodologies

## File Structure

```
opencode/
├── opencode.json              # Main configuration
├── agent/
│   ├── agent-core.md          # Main agent workflow
│   └── subagents/             # Specialized agents
│       ├── planner.md
│       ├── task-manager.md
│       ├── worker.md
│       ├── testing-expert.md
│       ├── reviewer.md
│       ├── documentation.md
│       └── security-auditor.md
├── command/                   # Executable commands
│   ├── auto-task.md
│   ├── commit-stage.md
│   ├── create-pr.md
│   └── ...
└── plugins/                   # Extension plugins
    └── notification.js
```

This configuration creates a comprehensive, AI-powered development environment that combines the strengths of specialized agents with structured workflows to deliver high-quality software development assistance.
