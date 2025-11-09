#!/bin/bash

# Dependency installation and management for dotfiles script

# Check if a command exists
function _command_exists {
    command -v "$1" >/dev/null 2>&1
}

# Check if we're on macOS
function _is_macos {
    [[ "$(uname)" == "Darwin" ]]
}

# Check if we're on Linux
function _is_linux {
    [[ "$(uname)" == "Linux" ]]
}

# Get the Linux distribution
function _get_linux_distro {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Install Homebrew on macOS
function _install_homebrew {
    if _is_macos && ! _command_exists brew; then
        _task "Installing Homebrew..."
        local install_script
        install_script="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        if [[ -n "$install_script" ]]; then
            if _cmd_safe "/bin/bash -c '$install_script'" "Installing Homebrew"; then
                _task_done
                
                # Add Homebrew to PATH for current session
                if [[ -x "/opt/homebrew/bin/brew" ]]; then
                    export PATH="/opt/homebrew/bin:$PATH"
                elif [[ -x "/usr/local/bin/brew" ]]; then
                    export PATH="/usr/local/bin:$PATH"
                fi
                
                return 0
            else
                _error "Failed to install Homebrew"
                return 1
            fi
        else
            _error "Could not download Homebrew install script"
            return 1
        fi
    fi
    return 0
}

# Install package using system package manager
function _install_system_package {
    local package="$1"
    local distro
    
    if _is_macos; then
        if _command_exists brew; then
            _task "Installing $package via Homebrew..."
            if _cmd_safe "brew install '$package'" "Installing $package with brew"; then
                _task_done
                return 0
            fi
        else
            _error "Homebrew not available for installing $package"
            return 1
        fi
    elif _is_linux; then
        distro=$(_get_linux_distro)
        case "$distro" in
            ubuntu|debian)
                 if _command_exists apt-get; then
                     _task "Installing $package via apt..."
                     local apt_cmd="apt-get"
                     if [[ "$EUID" -ne 0 ]]; then
                         apt_cmd="sudo $apt_cmd"
                     fi
                     if _cmd_safe "$apt_cmd update && $apt_cmd install -y '$package'" "Installing $package with apt"; then
                         _task_done
                         return 0
                     fi
                 fi
                 ;;
            rhel|centos|fedora)
                 if _command_exists dnf; then
                     _task "Installing $package via dnf..."
                     local dnf_cmd="dnf"
                     if [[ "$EUID" -ne 0 ]]; then
                         dnf_cmd="sudo $dnf_cmd"
                     fi
                     if _cmd_safe "$dnf_cmd install -y '$package'" "Installing $package with dnf"; then
                         _task_done
                         return 0
                     fi
                 elif _command_exists yum; then
                     _task "Installing $package via yum..."
                     local yum_cmd="yum"
                     if [[ "$EUID" -ne 0 ]]; then
                         yum_cmd="sudo $yum_cmd"
                     fi
                     if _cmd_safe "$yum_cmd install -y '$package'" "Installing $package with yum"; then
                         _task_done
                         return 0
                     fi
                 fi
                 ;;
             arch)
                 if _command_exists pacman; then
                     _task "Installing $package via pacman..."
                     local pacman_cmd="pacman"
                     if [[ "$EUID" -ne 0 ]]; then
                         pacman_cmd="sudo $pacman_cmd"
                     fi
                     if _cmd_safe "$pacman_cmd -S --noconfirm '$package'" "Installing $package with pacman"; then
                         _task_done
                         return 0
                     fi
                 fi
                 ;;
        esac
        
        _error "Could not install $package: unsupported Linux distribution or package manager"
        return 1
    else
        _error "Unsupported operating system for installing $package"
        return 1
    fi
}

# Install Ansible
function _install_ansible {
    if ! _command_exists ansible; then
        _task "Installing Ansible..."
        
        if _is_macos; then
            if ! _install_system_package ansible; then
                # Fallback to pip if available
                if _command_exists pip3; then
                    if _cmd_safe "pip3 install --user ansible" "Installing Ansible with pip3"; then
                        _task_done
                        return 0
                    fi
                fi
                _error "Failed to install Ansible"
                return 1
            fi
        elif _is_linux; then
            if ! _install_system_package ansible; then
                # Try pip as fallback
                if _command_exists pip3; then
                    if _cmd_safe "pip3 install --user ansible" "Installing Ansible with pip3"; then
                        _task_done
                        # Add user pip bin to PATH
                        export PATH="$HOME/.local/bin:$PATH"
                        return 0
                    fi
                fi
                _error "Failed to install Ansible"
                return 1
            fi
        fi
    fi
    return 0
}

# Install git if not present
function _install_git {
    if ! _command_exists git; then
        _task "Installing Git..."
        if _install_system_package git; then
            return 0
        else
            _error "Failed to install Git"
            return 1
        fi
    fi
    return 0
}

# Install curl if not present
function _install_curl {
    if ! _command_exists curl; then
        _task "Installing curl..."
        if _install_system_package curl; then
            return 0
        else
            _error "Failed to install curl"
            return 1
        fi
    fi
    return 0
}

# Install stow if not present
function _install_stow {
    if ! _command_exists stow; then
        _task "Installing GNU Stow..."
        if _install_system_package stow; then
            return 0
        else
            _error "Failed to install GNU Stow"
            return 1
        fi
    fi
    return 0
}

# Check and install all required dependencies
function install_dependencies {
    local failed=0
    
    _task "Checking dependencies..."
    _task_done
    
    # Core dependencies
    if ! _install_curl; then
        ((failed++))
    fi
    
    if ! _install_git; then
        ((failed++))
    fi
    
    # macOS specific: Install Homebrew first
    if _is_macos; then
        if ! _install_homebrew; then
            ((failed++))
        fi
    fi
    
    # Install Ansible
    if ! _install_ansible; then
        ((failed++))
    fi
    
    # Install Stow (optional but recommended)
    if ! _install_stow; then
        _warning "GNU Stow installation failed - some features may not work"
    fi
    
    if [[ $failed -eq 0 ]]; then
        _success "All dependencies installed successfully"
        return 0
    else
        _error "$failed dependencies failed to install"
        return 1
    fi
}

# Validate that all required tools are available
function validate_dependencies {
    local missing=()
    local required_tools=("git" "curl" "ansible" "ansible-playbook")
    
    for tool in "${required_tools[@]}"; do
        if ! _command_exists "$tool"; then
            missing+=("$tool")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        _error "Missing required dependencies: ${missing[*]}"
        echo -e "${ARROW} Run the dependency installation first"
        return 1
    fi
    
    _success "All required dependencies are available"
    return 0
}

# Update Ansible Galaxy collections
function update_ansible_galaxy {
    local requirements_file="$1"
    
    if [[ -z "$requirements_file" ]]; then
        requirements_file="$DOTFILES_DIR/install/requirements.yml"
    fi
    
    if [[ ! -f "$requirements_file" ]]; then
        _warning "Ansible requirements file not found: $requirements_file"
        return 0
    fi
    
    _task "Updating Ansible Galaxy collections..."
    if _cmd_safe "ansible-galaxy install -r '$requirements_file'" "Installing Ansible Galaxy requirements"; then
        _task_done
        return 0
    else
        _error "Failed to update Ansible Galaxy collections"
        return 1
    fi
}

# Show system information
function show_system_info {
    echo -e "${LBLUE}System Information:${NC}"
    echo -e "  OS: ${CYAN}$(uname -s)${NC}"
    echo -e "  Architecture: ${CYAN}$(uname -m)${NC}"
    
    if _is_linux; then
        echo -e "  Distribution: ${CYAN}$(_get_linux_distro)${NC}"
    fi
    
    echo -e "${LBLUE}Available Tools:${NC}"
    local tools=("git" "curl" "ansible" "ansible-playbook" "brew" "stow")
    for tool in "${tools[@]}"; do
        if _command_exists "$tool"; then
            echo -e "  $tool: ${GREEN}✓${NC}"
        else
            echo -e "  $tool: ${RED}✗${NC}"
        fi
    done
}