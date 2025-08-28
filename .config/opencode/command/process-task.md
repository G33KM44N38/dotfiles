# Process Task Command

**Command:** `process-task`  
**Description:** Enhanced task list management system for tracking and completing PRD implementation tasks in markdown files  
**Version:** 2.0.0  
**Usage:** `process-task [task-file.md] [options]`

## Overview

This command provides a structured approach to managing task lists in markdown files, specifically designed for tracking progress on Product Requirements Document (PRD) implementation. It enforces a disciplined workflow of completing one sub-task at a time while maintaining clear progress tracking.

## additionnal features

IMPORTANT: always see if there is an agent for the task you working on.

## Core Principles

### 1. Sequential Task Processing
- **One Sub-task Rule:** Complete only ONE sub-task per interaction cycle
- **Permission Protocol:** Always ask for explicit permission before proceeding to the next sub-task
- **Progress Validation:** Verify completion of current sub-task before moving forward
- **Context Preservation:** Maintain awareness of overall project context while focusing on individual tasks

### 2. Task State Management
- **Clear Status Indicators:** Use consistent markdown formatting for task states
- **Progress Tracking:** Maintain completion timestamps and progress notes
- **Dependency Awareness:** Identify and respect task dependencies
- **Quality Gates:** Ensure each completed task meets acceptance criteria

## Task Implementation Workflow

### Phase 1: Task Analysis
1. **Load Task File:** Read and parse the target markdown task file
2. **Status Assessment:** Identify current progress state and pending tasks
3. **Priority Evaluation:** Determine next logical task based on dependencies and priority
4. **Context Review:** Ensure understanding of overall project goals and constraints

### Phase 2: Task Execution
1. **Task Selection:** Choose the next actionable sub-task
2. **Scope Confirmation:** Clearly define what will be accomplished
3. **Implementation:** Execute the specific sub-task with full focus
4. **Validation:** Verify completion against acceptance criteria
5. **Documentation:** Update task status and add completion notes

### Phase 3: Progress Management
1. **Status Update:** Mark completed task with timestamp and notes
2. **Next Task Identification:** Identify the logical next step
3. **Permission Request:** Ask for explicit approval to continue
4. **Context Handoff:** Provide clear summary for next interaction

## Task List Format Standards

### Basic Task Structure
```markdown
## Task List: [Project/Feature Name]

### Phase 1: [Phase Name]
- [ ] **Task 1:** Description of first task
  - [ ] Sub-task 1.1: Specific actionable item
  - [ ] Sub-task 1.2: Another specific item
  - [ ] Sub-task 1.3: Final item in this task
- [ ] **Task 2:** Description of second task
  - [ ] Sub-task 2.1: Specific actionable item

### Phase 2: [Phase Name]
- [ ] **Task 3:** Description of third task
```

### Enhanced Task Structure with Metadata
```markdown
## Task List: [Project/Feature Name]
**Status:** In Progress | **Priority:** High | **Deadline:** 2024-XX-XX

### Phase 1: Foundation Setup
**Status:** Completed ✅ | **Completed:** 2024-XX-XX
- [x] **Task 1:** Database schema design
  - [x] Sub-task 1.1: Define user entity structure *(Completed: 2024-XX-XX)*
  - [x] Sub-task 1.2: Create migration files *(Completed: 2024-XX-XX)*
  - [x] Sub-task 1.3: Add validation rules *(Completed: 2024-XX-XX)*

### Phase 2: Core Implementation
**Status:** In Progress 🚧 | **Started:** 2024-XX-XX
- [ ] **Task 2:** User authentication system
  - [x] Sub-task 2.1: Implement login endpoint *(Completed: 2024-XX-XX)*
  - [~] Sub-task 2.2: Add password hashing *(Current Focus)*
  - [ ] Sub-task 2.3: Create JWT token management
  - [ ] Sub-task 2.4: Implement logout functionality
```

## Status Indicators Reference

### Task States
- `[ ]` - Pending/Not Started
- `[x]` - Completed
- `[~]` - In Progress (current focus)
- `[-]` - Blocked/On Hold
- `[!]` - Needs Review/Attention

### Progress Symbols
- ✅ **Completed** - Phase or major task finished
- 🚧 **In Progress** - Currently being worked on
- ⏸️ **Paused** - Temporarily halted
- 🚫 **Blocked** - Cannot proceed due to dependency
- ⚠️ **At Risk** - May miss deadline or has issues
- 📋 **Planned** - Scheduled for future work

## AI Assistant Instructions

### Primary Directives
1. **Single Task Focus:** Only work on ONE sub-task per interaction
2. **Permission Protocol:** Always request permission before proceeding to next sub-task
3. **Status Maintenance:** Keep task list current with accurate progress indicators
4. **Context Awareness:** Understand project goals while maintaining task-level focus

### Interaction Pattern
```
1. ANALYZE: Review current task list state
2. IDENTIFY: Select next actionable sub-task
3. CONFIRM: State what will be accomplished
4. EXECUTE: Complete the specific sub-task
5. UPDATE: Mark task complete with timestamp
6. REQUEST: Ask permission to continue with next sub-task
```

### Communication Templates

#### Starting a Task Session
```
Task Analysis Complete:
- Current Phase: [Phase Name]
- Next Sub-task: [Sub-task Description]
- Estimated Effort: [Time/Complexity]
- Dependencies: [Any prerequisites]

Ready to proceed with: [Specific sub-task]
Shall I begin implementation?
```

#### Completing a Sub-task
```
Sub-task Completed: [Sub-task Name]
- Implementation: [Brief description of what was done]
- Files Modified: [List of changed files]
- Status: ✅ Complete
- Timestamp: [Current date/time]

Next recommended sub-task: [Next item]
May I proceed with the next sub-task?
```

#### Requesting Permission
```
Current sub-task completed successfully.

Progress Summary:
- Just completed: [Task name]
- Overall progress: [X of Y] sub-tasks complete
- Next logical step: [Next sub-task name]

Would you like me to continue with the next sub-task, or would you prefer to review the current progress first?
```

## Advanced Features

### Dependency Management
- **Task Dependencies:** Use `depends-on: [task-id]` notation
- **Blocking Issues:** Mark dependent tasks appropriately
- **Critical Path:** Identify sequence-critical tasks

### Time Tracking
- **Estimated Duration:** Add time estimates to tasks
- **Actual Duration:** Track completion times
- **Progress Velocity:** Monitor completion rates

### Quality Assurance
- **Acceptance Criteria:** Define completion requirements
- **Review Checkpoints:** Built-in quality gates
- **Testing Integration:** Link to test completion

## Best Practices

### Task Definition
1. **Specific and Actionable:** Each sub-task should be concrete and measurable
2. **Right-Sized:** Sub-tasks should be completable in a single session
3. **Independent:** Minimize unnecessary dependencies between sub-tasks
4. **Testable:** Include clear success criteria

### Progress Management
1. **Regular Updates:** Keep status current after each session
2. **Clear Documentation:** Add context and notes for completed tasks
3. **Honest Assessment:** Accurately reflect progress and blockers
4. **Continuous Improvement:** Learn from completed tasks to improve estimates

### Collaboration
1. **Transparent Progress:** Make status visible to all stakeholders
2. **Regular Communication:** Provide updates on significant milestones
3. **Issue Escalation:** Promptly flag blockers and risks
4. **Knowledge Sharing:** Document learnings and decisions

## Error Handling

### Common Issues
- **Invalid Task Format:** Provide clear formatting guidance
- **Missing Dependencies:** Identify and resolve prerequisite tasks
- **Scope Creep:** Keep tasks focused and well-defined
- **Progress Conflicts:** Resolve status inconsistencies

### Recovery Procedures
- **Task List Corruption:** Restore from backup or rebuild
- **Lost Context:** Review recent progress and restart
- **Blocking Dependencies:** Escalate or find alternatives
- **Quality Issues:** Implement review and rework procedures

## Integration Points

### Development Workflow
- **Version Control:** Sync with git commits and branches
- **Code Reviews:** Link tasks to pull requests
- **Testing:** Connect to test execution and results
- **Deployment:** Track release and deployment tasks

### Project Management
- **Sprint Planning:** Align with agile ceremonies
- **Milestone Tracking:** Connect to project deadlines
- **Resource Planning:** Consider team capacity and skills
- **Risk Management:** Monitor and mitigate task-level risks

## Examples

### Simple Feature Implementation
```markdown
## Task List: User Profile Feature

### Phase 1: Backend Development
- [ ] **API Development:** Create user profile endpoints
  - [ ] Design profile data model
  - [ ] Implement GET /profile endpoint
  - [ ] Implement PUT /profile endpoint
  - [ ] Add input validation
  - [ ] Write unit tests

### Phase 2: Frontend Development
- [ ] **UI Components:** Build profile interface
  - [ ] Create profile display component
  - [ ] Add profile edit form
  - [ ] Implement image upload
  - [ ] Add form validation
```

### Complex Project with Dependencies
```markdown
## Task List: E-commerce Platform Migration

### Phase 1: Infrastructure Setup
- [x] **Database Migration:** Move to new database system *(Completed: 2024-01-15)*
  - [x] Export existing data *(Completed: 2024-01-10)*
  - [x] Set up new database instance *(Completed: 2024-01-12)*
  - [x] Import and validate data *(Completed: 2024-01-15)*

### Phase 2: Core Services (depends-on: Phase 1)
- [ ] **User Service:** Rebuild user management
  - [~] Implement authentication API *(In Progress)*
  - [ ] Add user profile management
  - [ ] Integrate with payment system
```

---

**Note:** This command is designed to work with markdown task files and requires discipline in following the one-sub-task-at-a-time methodology. The system's effectiveness depends on consistent application of the defined workflow and communication patterns.
