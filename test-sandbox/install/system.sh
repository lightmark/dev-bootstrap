#!/bin/bash

# System tools installation
# Essential development tools and utilities

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

init_common

log "Installing system tools..."

# Package lists for different systems
declare -A UBUNTU_PACKAGES=(
    ["curl"]="curl"
    ["git"]="git"
    ["build-essential"]="build-essential"
    ["ca-certificates"]="ca-certificates"
    ["gnupg"]="gnupg"
    ["ripgrep"]="ripgrep"
    ["fd-find"]="fd-find"
    ["bat"]="bat"
    ["tree"]="tree"
    ["htop"]="htop"
    ["unzip"]="unzip"
    ["jq"]="jq"
)

declare -A MACOS_PACKAGES=(
    ["curl"]="curl"
    ["git"]="git" 
    ["ripgrep"]="ripgrep"
    ["fd"]="fd"
    ["bat"]="bat"
    ["tree"]="tree"
    ["htop"]="htop"
    ["jq"]="jq"
)

install_system_packages() {
    case "$OS_TYPE" in
        ubuntu)
            # Update package lists
            if [[ "$DRY_RUN" == "false" ]]; then
                log "Updating package lists..."
                sudo apt-get update -qq
            fi
            
            for package_name in "${!UBUNTU_PACKAGES[@]}"; do
                install_package "${UBUNTU_PACKAGES[$package_name]}"
            done
            
            # Special handling for bat on Ubuntu (command name conflict)
            if is_package_installed "bat"; then
                # Create batcat -> bat symlink if it doesn't exist
                local bat_link="$HOME/.local/bin/bat"
                if [[ ! -f "$bat_link" ]] && command_exists batcat; then
                    if [[ "$DRY_RUN" == "true" ]]; then
                        debug "Would create symlink: batcat -> $bat_link"
                    else
                        mkdir -p "$HOME/.local/bin"
                        ln -sf "$(command -v batcat)" "$bat_link"
                        log "Created symlink: batcat -> $bat_link"
                        
                        # Add to PATH if not already there
                        append_if_missing "$SHELL_CONFIG" 'export PATH="$HOME/.local/bin:$PATH"' "HOME/.local/bin"
                    fi
                fi
            fi
            
            # Special handling for fd on Ubuntu (different package name)
            if is_package_installed "fd-find"; then
                local fd_link="$HOME/.local/bin/fd"
                if [[ ! -f "$fd_link" ]] && command_exists fdfind; then
                    if [[ "$DRY_RUN" == "true" ]]; then
                        debug "Would create symlink: fdfind -> $fd_link"
                    else
                        mkdir -p "$HOME/.local/bin"
                        ln -sf "$(command -v fdfind)" "$fd_link"
                        log "Created symlink: fdfind -> $fd_link"
                        
                        # Add to PATH if not already there
                        append_if_missing "$SHELL_CONFIG" 'export PATH="$HOME/.local/bin:$PATH"' "HOME/.local/bin"
                    fi
                fi
            fi
            ;;
            
        macos)
            # Check if Homebrew is installed
            if ! command_exists brew; then
                log "Installing Homebrew..."
                if [[ "$DRY_RUN" == "true" ]]; then
                    debug "Would install Homebrew"
                else
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                fi
            fi
            
            for package_name in "${!MACOS_PACKAGES[@]}"; do
                install_package "${MACOS_PACKAGES[$package_name]}"
            done
            ;;
            
        *)
            error_exit "Unsupported OS type: $OS_TYPE"
            ;;
    esac
}

# Install direnv (universal installation)
install_direnv() {
    if command_exists direnv; then
        debug "direnv already installed"
        return 0
    fi
    
    log "Installing direnv..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        debug "Would install direnv"
        return 0
    fi
    
    case "$OS_TYPE" in
        ubuntu)
            # Install from official binary
            local direnv_version="v2.32.3"
            local direnv_url="https://github.com/direnv/direnv/releases/download/${direnv_version}/direnv.linux-amd64"
            local direnv_bin="$HOME/.local/bin/direnv"
            
            mkdir -p "$HOME/.local/bin"
            download_file "$direnv_url" "$direnv_bin"
            chmod +x "$direnv_bin"
            
            # Add to PATH
            append_if_missing "$SHELL_CONFIG" 'export PATH="$HOME/.local/bin:$PATH"' "HOME/.local/bin"
            ;;
            
        macos)
            install_package "direnv"
            ;;
    esac
    
    # Add direnv hook to shell config
    local hook_line
    case "$(basename "$SHELL")" in
        bash)
            hook_line='eval "$(direnv hook bash)"'
            ;;
        zsh)
            hook_line='eval "$(direnv hook zsh)"'
            ;;
        *)
            warn "Unsupported shell for direnv hook"
            return 0
            ;;
    esac
    
    append_if_missing "$SHELL_CONFIG" "$hook_line" "direnv hook"
}

# Configure git with safe defaults (only if not already configured)
configure_git_defaults() {
    log "Configuring git defaults..."
    
    # Only set defaults if git config is not already set
    local git_configs=(
        "init.defaultBranch:main"
        "pull.rebase:false"
        "core.autocrlf:input"
        "core.quotepath:false"
        "color.ui:auto"
        "push.default:simple"
        "merge.conflictstyle:diff3"
    )
    
    for config in "${git_configs[@]}"; do
        local key="${config%:*}"
        local value="${config#*:}"
        
        if ! git config --global "$key" >/dev/null 2>&1; then
            if [[ "$DRY_RUN" == "true" ]]; then
                debug "Would set git config: $key = $value"
            else
                git config --global "$key" "$value"
                log "Set git config: $key = $value"
            fi
        else
            debug "Git config already set: $key"
        fi
    done
}

# Main installation function
main() {
    install_system_packages
    install_direnv
    configure_git_defaults
    
    log "System tools installation completed"
}

# Run main function
main