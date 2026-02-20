#!/bin/bash

# Common functions for all install scripts
# This file is sourced by bootstrap.sh before running component installers

# File operation functions
backup_file() {
    local file="$1"
    local backup_dir="$2"
    
    if [[ -f "$file" || -L "$file" ]]; then
        local backup_name="$(basename "$file").backup.$(date +%Y%m%d_%H%M%S)"
        local backup_path="$backup_dir/$backup_name"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            debug "Would backup $file to $backup_path"
        else
            cp "$file" "$backup_path" 2>/dev/null || true
            log "Backed up $file to $backup_path"
        fi
        return 0
    fi
    return 1
}

# Safe file operations - append only if content doesn't exist
append_if_missing() {
    local file="$1"
    local content="$2"
    local marker="$3"  # Optional: unique marker to check for content
    
    # Create file if it doesn't exist
    if [[ ! -f "$file" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            debug "Would create file: $file"
            return 0
        else
            touch "$file"
            log "Created file: $file"
        fi
    fi
    
    # Check if content already exists
    if [[ -n "$marker" ]]; then
        if grep -q "$marker" "$file" 2>/dev/null; then
            debug "Content already exists in $file (marker: $marker)"
            return 0
        fi
    else
        # Use the content itself as marker
        if grep -Fq "$content" "$file" 2>/dev/null; then
            debug "Content already exists in $file"
            return 0
        fi
    fi
    
    # Append content
    if [[ "$DRY_RUN" == "true" ]]; then
        debug "Would append to $file: $content"
    else
        echo "$content" >> "$file"
        log "Appended content to $file"
    fi
}

# Template rendering with variable substitution
render_template() {
    local template_file="$1"
    local output_file="$2"
    local backup_existing="${3:-true}"
    
    if [[ ! -f "$template_file" ]]; then
        error_exit "Template file not found: $template_file"
    fi
    
    # Backup existing file
    if [[ "$backup_existing" == "true" ]] && [[ -f "$output_file" ]]; then
        backup_file "$output_file" "$BACKUPS_DIR"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        debug "Would render $template_file to $output_file"
    else
        # Simple template rendering (supports ${VAR} substitution)
        envsubst < "$template_file" > "$output_file"
        log "Rendered template $template_file to $output_file"
    fi
}

# Package installation functions
is_package_installed() {
    local package="$1"
    
    case "$PKG_MANAGER" in
        apt)
            dpkg -l "$package" 2>/dev/null | grep -q "^ii"
            ;;
        brew)
            brew list "$package" >/dev/null 2>&1
            ;;
        *)
            error_exit "Unsupported package manager: $PKG_MANAGER"
            ;;
    esac
}

install_package() {
    local package="$1"
    local force="${2:-false}"
    
    if [[ "$force" == "false" ]] && is_package_installed "$package"; then
        debug "Package already installed: $package"
        return 0
    fi
    
    log "Installing package: $package"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        debug "Would install package: $package"
        return 0
    fi
    
    case "$PKG_MANAGER" in
        apt)
            sudo apt-get update -qq
            sudo apt-get install -y "$package"
            ;;
        brew)
            brew install "$package"
            ;;
        *)
            error_exit "Unsupported package manager: $PKG_MANAGER"
            ;;
    esac
}

# Tool availability checking
command_exists() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1
}

# Network operations
download_file() {
    local url="$1"
    local output="$2"
    local timeout="${3:-30}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        debug "Would download $url to $output"
        return 0
    fi
    
    log "Downloading $url"
    
    if command_exists curl; then
        curl -fsSL --connect-timeout "$timeout" "$url" -o "$output"
    elif command_exists wget; then
        wget -q --timeout="$timeout" "$url" -O "$output"
    else
        error_exit "Neither curl nor wget found. Please install one of them."
    fi
}

# Git operations (safe)
safe_git_clone() {
    local repo_url="$1"
    local target_dir="$2"
    local branch="${3:-}"
    
    if [[ -d "$target_dir" ]]; then
        debug "Directory already exists: $target_dir"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        debug "Would git clone $repo_url to $target_dir"
        return 0
    fi
    
    log "Cloning repository: $repo_url"
    
    local clone_cmd="git clone"
    if [[ -n "$branch" ]]; then
        clone_cmd="$clone_cmd --branch $branch"
    fi
    clone_cmd="$clone_cmd $repo_url $target_dir"
    
    eval "$clone_cmd" || error_exit "Failed to clone repository"
}

# Shell detection and configuration
detect_shell() {
    local shell_name
    shell_name=$(basename "$SHELL")
    
    case "$shell_name" in
        bash)
            export SHELL_CONFIG="$HOME/.bashrc"
            ;;
        zsh)
            export SHELL_CONFIG="$HOME/.zshrc"
            ;;
        fish)
            export SHELL_CONFIG="$HOME/.config/fish/config.fish"
            ;;
        *)
            warn "Unsupported shell: $shell_name, defaulting to bash"
            export SHELL_CONFIG="$HOME/.bashrc"
            ;;
    esac
    
    debug "Detected shell: $shell_name, config: $SHELL_CONFIG"
}

# Check system requirements
check_system_requirements() {
    local required_commands=("curl" "git")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        error_exit "Missing required commands: ${missing_commands[*]}"
    fi
}

# Initialize common variables and checks
init_common() {
    detect_shell
    check_system_requirements
    
    # Ensure backup directory exists
    if [[ ! -d "$BACKUPS_DIR" ]]; then
        mkdir -p "$BACKUPS_DIR"
    fi
}