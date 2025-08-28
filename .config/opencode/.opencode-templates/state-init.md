# OpenCode State Initialization Guide

## Directory Structure Template

When initializing state for a new session, create this structure:

```
.opencode/
├── state/
│   ├── session.json           # Current session metadata
│   ├── shared.json            # Cross-agent shared context
│   ├── context/               # Agent-specific contexts
│   │   ├── planner.json       # Planner agent state
│   │   ├── task-manager.json  # Task manager state
│   │   ├── worker.json        # Worker agent state
│   │   ├── testing-expert.json# Testing expert state
│   │   ├── reviewer.json      # Reviewer agent state
│   │   └── documentation.json # Documentation agent state
│   ├── workflow/              # Workflow management
│   │   ├── task-queue.json    # Current task queue
│   │   └── history.json       # Workflow execution history
│   └── artifacts/             # Generated artifacts
│       ├── plans/             # Strategic plans
│       ├── tasks/             # Task definitions
│       └── reports/           # Agent reports
└── backups/                   # State backups
    └── YYYYMMDD_HHMMSS/       # Timestamped backups
```

## Initialization Steps

### 1. Create Directory Structure
```bash
mkdir -p .opencode/state/context
mkdir -p .opencode/state/workflow  
mkdir -p .opencode/state/artifacts/plans
mkdir -p .opencode/state/artifacts/tasks
mkdir -p .opencode/state/artifacts/reports
mkdir -p .opencode/backups
```

### 2. Initialize Session File
Copy `session.json` template and replace placeholders:
- `TIMESTAMP_PLACEHOLDER` → current timestamp
- `ISO_TIMESTAMP_PLACEHOLDER` → ISO format timestamp
- `feature-name-placeholder` → actual feature name

### 3. Initialize Shared Context
Copy `shared.json` template and:
- Replace placeholders with actual values
- Discover project type (Node.js, Python, etc.)
- Identify build/test commands
- Map project structure

### 4. Initialize Agent Contexts
For each agent (`planner`, `task-manager`, `worker`, etc.):
- Copy `agent-context-template.json`
- Rename to `{agent-name}.json`
- Replace `AGENT_NAME_PLACEHOLDER`
- Initialize with agent-specific defaults

### 5. Initialize Task Queue
Copy `task-queue.json` template and set feature name.

## Template Placeholders

Replace these in all template files:
- `TIMESTAMP_PLACEHOLDER` → Unix timestamp
- `ISO_TIMESTAMP_PLACEHOLDER` → ISO 8601 timestamp  
- `feature-name-placeholder` → kebab-case feature name
- `AGENT_NAME_PLACEHOLDER` → actual agent name

## Validation Checklist

Before starting workflow, ensure:
- [ ] All directories exist
- [ ] All JSON files are valid JSON
- [ ] Session ID is unique
- [ ] Project type is detected
- [ ] Agent contexts are initialized
- [ ] Task queue is empty but valid

## State Backup Strategy

Before major changes:
1. Create timestamped backup directory
2. Copy entire `.opencode/state/` to backup
3. Validate backup integrity
4. Proceed with changes

## Recovery Procedures

### Corrupted State
1. Stop workflow immediately
2. Restore from most recent backup
3. Validate restored state
4. Resume from last known good state

### Missing Context
1. Reinitialize missing context files
2. Mark as "recovered" in agent context
3. Request context rebuild from agents
4. Validate cross-agent consistency

## Integration with Agent-Core

Agent-core should:
1. Check for existing state on startup
2. Initialize missing state components
3. Validate state integrity before agent calls
4. Update state after each agent interaction
5. Create backups before critical operations