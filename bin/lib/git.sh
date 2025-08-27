#!/bin/bash

# Git operations for dotfiles script

# Check if we're in a git repository
function _is_git_repo {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

# Check for uncommitted changes
function _has_uncommitted_changes {
    [[ -n "$(git status --porcelain 2>/dev/null)" ]]
}

# Check for unpushed commits
function _has_unpushed_commits {
    local unpushed=$(git rev-list @{u}..HEAD 2>/dev/null || true)
    [[ -n "$unpushed" ]]
}

# Get current branch name
function _get_current_branch {
    git branch --show-current 2>/dev/null || echo "main"
}

# Check if upstream branch exists
function _has_upstream {
    git rev-parse --abbrev-ref @{u} >/dev/null 2>&1
}

# Stash changes if any exist
function _stash_changes {
    if _has_uncommitted_changes; then
        _task "Stashing changes..."
        if _cmd_safe "git stash push -m 'dotfiles-auto-stash-$(date +%s)'" "Stashing uncommitted changes"; then
            _task_done
            return 0
        else
            _error "Failed to stash changes"
            return 1
        fi
    fi
    return 0
}

# Pop stashed changes if stash exists
function _restore_stashed_changes {
    if git stash list | grep -q 'dotfiles-auto-stash'; then
        _task "Restoring stashed changes..."
        if _cmd_safe "git stash pop" "Restoring stashed changes"; then
            _task_done
            return 0
        else
            _warning "Failed to restore stashed changes - they remain in stash"
            return 1
        fi
    fi
    return 0
}

# Commit staged changes
function _commit_changes {
    local commit_message="$1"
    
    if [[ -z "$commit_message" ]]; then
        commit_message="Automated commit by dotfiles script"
    fi
    
    _task "Committing changes..."
    if _cmd_safe "git commit -m \"$commit_message\"" "Committing staged changes"; then
        _task_done
        return 0
    else
        _error "Failed to commit changes"
        return 1
    fi
}

# Push commits to remote
function _push_changes {
    local current_branch=$(_get_current_branch)
    
    _task "Pushing changes to remote..."
    if _has_upstream; then
        if _cmd_safe "git push" "Pushing to existing upstream"; then
            _task_done
            return 0
        fi
    else
        if _cmd_safe "git push -u origin $current_branch" "Pushing and setting upstream"; then
            _task_done
            return 0
        fi
    fi
    
    _error "Failed to push changes"
    return 1
}

# Interactive git status check and commit/push prompt
function _check_git_status_and_prompt_commit {
    if ! _is_git_repo; then
        _warning "Not in a git repository, skipping git operations"
        return 0
    fi
    
    local has_uncommitted=$(_has_uncommitted_changes && echo "yes" || echo "no")
    local has_unpushed=$(_has_unpushed_commits && echo "yes" || echo "no")
    
    if [[ "$has_uncommitted" == "no" && "$has_unpushed" == "no" ]]; then
        return 0  # Nothing to do
    fi
    
    _warning "Git status check:"
    if [[ "$has_uncommitted" == "yes" ]]; then
        echo -e "  ${YELLOW}- Uncommitted changes detected${NC}"
    fi
    if [[ "$has_unpushed" == "yes" ]]; then
        echo -e "  ${YELLOW}- Unpushed commits detected${NC}"
    fi
    
    if _confirm "Do you want to commit and/or push these changes now?" "n"; then
        _handle_git_operations "$has_uncommitted" "$has_unpushed"
    else
        _warning "Skipping git operations"
    fi
}

# Handle git operations based on status
function _handle_git_operations {
    local has_uncommitted="$1"
    local has_unpushed="$2"
    
    # Handle uncommitted changes
    if [[ "$has_uncommitted" == "yes" ]]; then
        _task "Staging all changes..."
        if _cmd_safe "git add -A" "Staging all changes"; then
            _task_done
            
            # Get commit message from user
            read -p "${CYAN}Enter commit message (or press Enter for default): ${NC}" commit_message
            if ! _commit_changes "$commit_message"; then
                return 1
            fi
            
            # Update unpushed status after new commit
            has_unpushed="yes"
        else
            _error "Failed to stage changes"
            return 1
        fi
    fi
    
    # Handle unpushed commits
    if [[ "$has_unpushed" == "yes" ]]; then
        if _confirm "Push changes to remote?" "y"; then
            if ! _push_changes; then
                return 1
            fi
        else
            _warning "Skipping push - commits remain local"
        fi
    fi
    
    _success "Git operations completed successfully"
}

# Update repository with proper handling
function _update_repository {
    local repo_dir="$1"
    
    if [[ ! -d "$repo_dir" ]]; then
        _error "Repository directory does not exist: $repo_dir"
        return 1
    fi
    
    cd "$repo_dir" || return 1
    
    if ! _is_git_repo; then
        _error "Directory is not a git repository: $repo_dir"
        return 1
    fi
    
    # Stash any uncommitted changes
    if ! _stash_changes; then
        return 1
    fi
    
    # Check and handle any pending git operations
    _check_git_status_and_prompt_commit
    
    # Pull latest changes
    _task "Pulling latest changes..."
    if _cmd_safe "git pull --rebase --quiet" "Pulling latest changes from remote"; then
        _task_done
    else
        _error "Failed to pull latest changes"
        return 1
    fi
    
    # Restore stashed changes
    _restore_stashed_changes
    
    return 0
}

# Clone repository
function _clone_repository {
    local repo_url="$1"
    local target_dir="$2"
    
    _task "Cloning repository from $repo_url..."
    if _cmd_safe "git clone --quiet '$repo_url' '$target_dir'" "Cloning repository"; then
        _task_done
        return 0
    else
        _error "Failed to clone repository"
        return 1
    fi
}