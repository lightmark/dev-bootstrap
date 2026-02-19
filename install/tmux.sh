#!/bin/bash

# Tmux installation and configuration
# Installs tmux with TPM and configures with modern settings

init_common

log "Installing and configuring tmux..."

# Install tmux package
install_tmux() {
    case "$OS_TYPE" in
        ubuntu)
            install_package "tmux"
            ;;
        macos)
            install_package "tmux"
            ;;
        *)
            error_exit "Unsupported OS type: $OS_TYPE"
            ;;
    esac
}

# Install TPM (Tmux Plugin Manager)
install_tpm() {
    local tpm_dir="$HOME/.tmux/plugins/tpm"
    
    if [[ -d "$tpm_dir" ]]; then
        debug "TPM already installed at $tpm_dir"
        return 0
    fi
    
    log "Installing TPM (Tmux Plugin Manager)..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        debug "Would clone TPM to $tpm_dir"
        return 0
    fi
    
    safe_git_clone "https://github.com/tmux-plugins/tpm" "$tpm_dir"
}

# Configure tmux with our template
configure_tmux() {
    local tmux_config="$HOME/.tmux.conf"
    local config_template="$CONFIGS_DIR/tmux.conf"
    
    # Backup existing config
    if [[ -f "$tmux_config" ]]; then
        backup_file "$tmux_config" "$BACKUPS_DIR"
    fi
    
    # Check if our config template exists, if not use current dotfiles version
    if [[ ! -f "$config_template" ]]; then
        log "Using existing tmux config from dotfiles"
        config_template="$SCRIPT_DIR/dotfiles/.tmux.conf"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        debug "Would copy $config_template to $tmux_config"
    else
        cp "$config_template" "$tmux_config"
        log "Installed tmux configuration to $tmux_config"
    fi
    
    # Install plugins automatically
    if command_exists tmux && [[ -d "$HOME/.tmux/plugins/tpm" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            debug "Would install tmux plugins"
        else
            log "Installing tmux plugins..."
            # Run TPM install script
            "$HOME/.tmux/plugins/tpm/scripts/install_plugins.sh" || true
        fi
    fi
}

# Configure SSH agent forwarding for tmux (if SSH is available)
configure_ssh_agent() {
    if [[ ! -d "$HOME/.ssh" ]]; then
        debug "No SSH directory found, skipping SSH agent configuration"
        return 0
    fi
    
    local ssh_script="$HOME/.ssh/tmux-ssh-agent.sh"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        debug "Would create SSH agent script for tmux"
        return 0
    fi
    
    # Create SSH agent helper script
    cat > "$ssh_script" << 'EOF'
#!/bin/bash
# SSH agent socket management for tmux

SSH_AUTH_SOCK_LINK="$HOME/.ssh/ssh_auth_sock"

# If we're in a tmux session, use the persistent socket
if [[ -n "$TMUX" ]]; then
    # If the persistent socket exists and points to a valid agent, use it
    if [[ -S "$SSH_AUTH_SOCK_LINK" ]]; then
        export SSH_AUTH_SOCK="$SSH_AUTH_SOCK_LINK"
    fi
# If we're not in tmux but have an agent, create/update the persistent socket  
elif [[ -n "$SSH_AUTH_SOCK" ]]; then
    if [[ ! -S "$SSH_AUTH_SOCK_LINK" ]] || [[ "$SSH_AUTH_SOCK" != "$SSH_AUTH_SOCK_LINK" ]]; then
        ln -sf "$SSH_AUTH_SOCK" "$SSH_AUTH_SOCK_LINK"
    fi
fi
EOF
    
    chmod +x "$ssh_script"
    log "Created SSH agent helper script: $ssh_script"
    
    # Add to shell configuration
    local source_line="source \"$ssh_script\""
    append_if_missing "$SHELL_CONFIG" "$source_line" "tmux-ssh-agent.sh"
}

# Verify tmux installation
verify_tmux() {
    if ! command_exists tmux; then
        error_exit "Tmux installation failed"
    fi
    
    # Check tmux version
    local tmux_version
    tmux_version=$(tmux -V | cut -d' ' -f2)
    log "Tmux version: $tmux_version"
    
    # Verify TPM installation
    if [[ -d "$HOME/.tmux/plugins/tpm" ]]; then
        debug "TPM installed successfully"
    else
        warn "TPM installation may have failed"
    fi
    
    # Verify config file
    if [[ -f "$HOME/.tmux.conf" ]]; then
        debug "Tmux configuration file exists"
    else
        warn "Tmux configuration file not found"
    fi
}

# Main installation function
main() {
    install_tmux
    install_tpm
    configure_tmux
    configure_ssh_agent
    verify_tmux
    
    log "Tmux installation and configuration completed"
    log "Start tmux and press prefix + I to install plugins"
}

# Run main function
main