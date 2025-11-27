---
description: code review what's has been done
agent: build
model: anthropic/claude-haiku-4-5
---
# Main Branch Comparison Review

**Current branch:**
`!git branch --show-current`

**Comparison with main branch:**
`!git diff --name-only origin/main..HEAD || git diff --name-only main..HEAD`

**Detailed diff stats:**
`!git diff --stat origin/main..HEAD || git diff --stat main..HEAD`

**Commits ahead of main:**
`!git log --oneline origin/main..HEAD || git log --oneline main..HEAD`

## Files Changed
Let me analyze each changed file:

`!git diff --name-only origin/main..HEAD || git diff --name-only main..HEAD | head -10`

## Project Context
**Project setup:**
@AGENTS.md

**Dependencies:**
@package.json

**Project README:**
@README.md

## Review Analysis

Please provide comprehensive feedback comparing the current branch against main, focusing on:

### 🔍 Code Quality & Best Practices
- Code structure and organization improvements/regressions
- Adherence to project coding standards
- Design pattern implementations
- Code maintainability and readability
- Proper error handling and edge cases

### 🐛 Potential Bugs & Issues  
- Logic errors in new/modified code
- Breaking changes that could affect existing functionality
- Missing validation or error handling
- Resource leaks or performance issues
- Integration points that might fail

### ⚡ Performance Considerations
- Algorithm efficiency in new code
- Database query patterns
- API call optimizations  
- Memory usage patterns
- Bundle size impact

### 🔒 Security Review
- Input validation in new endpoints/functions
- Authentication/authorization changes
- Sensitive data handling
- Dependency security implications
- Configuration security

### 🧪 Testing & Coverage
- New tests for added functionality
- Modified tests for changed behavior
- Integration test coverage
- Edge case handling
- Test quality and maintainability

## Instructions

Based on the comparison with main branch:

1. **Identify what's new/changed** and assess the quality
2. **Flag potential issues** with specific line references where possible
3. **Suggest improvements** with concrete examples
4. **Verify completeness** - are there missing pieces for the feature?
5. **Check backward compatibility** - will this break existing code?

Prioritize feedback by impact:
- 🔴 **Critical**: Must fix before merge (bugs, security, breaking changes)
- 🟡 **Important**: Should fix (performance, maintainability) 
- 🔵 **Nice to have**: Consider for future (style, optimization)

Focus on being constructive and educational. Explain not just what to change, but why the change would improve the codebase.
