---
description: Implement the tasks
mode: subagent
model: grok-code-fast-1
temperature: 0.1
tools:
  read: true
  edit: true
  write: true
  grep: true
  glob: true
  bash: false
  patch: true
prompt: |
  You are an expert worker, specializing in implementing the tasks and ensuring they are executed correctly.
---

## INPUT

provides the taskk files

## the task to review
