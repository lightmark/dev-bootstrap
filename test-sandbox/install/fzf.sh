#!/bin/bash

# FZF installation and configuration
# Installs fzf with key bindings and completion

init_common

log "Installing and configuring fzf..."

# Install fzf
install_fzf() {
    if command_exists fzf; then
        debug "fzf already installed"
        return 0
    fi
    
    log "Installing fzf..."
    
    case "$OS_TYPE" in
        ubuntu)
            # Try package manager first, fall back to git installation
            if apt-cache show fzf >/dev/null 2>&1; then
                install_package "fzf"
            else
                install_fzf_from_git
            fi
            ;;
        macos)
            install_package "fzf"
            ;;
        *)
            error_exit "Unsupported OS type: $OS_TYPE"
            ;;
    esac
}

# Install fzf from git (fallback method)
install_fzf_from_git() {
    local fzf_dir="$HOME/.fzf"
    
    if [[ -d "$fzf_dir" ]]; then
        debug "fzf git installation already exists"
        return 0
    fi
    
    log "Installing fzf from git..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        debug "Would clone fzf to $fzf_dir and run install"
        return 0
    fi
    
    # Clone fzf repository
    safe_git_clone "https://github.com/junegunn/fzf.git" "$fzf_dir"
    
    # Run fzf install script
    if [[ -x "$fzf_dir/install" ]]; then
        log "Running fzf installation script..."
        "$fzf_dir/install" --bin --key-bindings --completion --no-update-rc
        
        # Add fzf to PATH
        append_if_missing "$SHELL_CONFIG" 'export PATH="$HOME/.fzf/bin:$PATH"' "fzf/bin"
    fi
}

# Configure fzf key bindings and completion
configure_fzf() {
    local shell_name
    shell_name=$(basename "$SHELL")
    
    case "$shell_name" in
        bash)
            configure_fzf_bash
            ;;
        zsh)
            configure_fzf_zsh
            ;;
        *)
            warn "Unsupported shell for fzf configuration: $shell_name"
            return 0
            ;;
    esac
    
    # Configure fzf options
    configure_fzf_options
}

configure_fzf_bash() {
    local fzf_bash_completion="/usr/share/doc/fzf/examples/completion.bash"
    local fzf_bash_keybindings="/usr/share/doc/fzf/examples/key-bindings.bash"
    
    # Try different common locations for fzf scripts
    local completion_paths=(
        "/usr/share/doc/fzf/examples/completion.bash"
        "/usr/share/fzf/completion.bash"
        "$HOME/.fzf/shell/completion.bash"
        "$(brew --prefix fzf 2>/dev/null)/shell/completion.bash"
    )
    
    local keybinding_paths=(
        "/usr/share/doc/fzf/examples/key-bindings.bash"
        "/usr/share/fzf/key-bindings.bash"
        "$HOME/.fzf/shell/key-bindings.bash"
        "$(brew --prefix fzf 2>/dev/null)/shell/key-bindings.bash"
    )
    
    # Find and source completion script
    for path in "${completion_paths[@]}"; do
        if [[ -f "$path" ]]; then
            append_if_missing "$SHELL_CONFIG" "source \"$path\"" "fzf.*completion"
            debug "Added fzf completion: $path"
            break
        fi
    done
    
    # Find and source key bindings script
    for path in "${keybinding_paths[@]}"; do
        if [[ -f "$path" ]]; then
            append_if_missing "$SHELL_CONFIG" "source \"$path\"" "fzf.*key-bindings"
            debug "Added fzf key bindings: $path"
            break
        fi
    done
}

configure_fzf_zsh() {
    local completion_paths=(
        "/usr/share/doc/fzf/examples/completion.zsh"
        "/usr/share/fzf/completion.zsh"
        "$HOME/.fzf/shell/completion.zsh"
        "$(brew --prefix fzf 2>/dev/null)/shell/completion.zsh"
    )
    
    local keybinding_paths=(
        "/usr/share/doc/fzf/examples/key-bindings.zsh"
        "/usr/share/fzf/key-bindings.zsh"
        "$HOME/.fzf/shell/key-bindings.zsh"
        "$(brew --prefix fzf 2>/dev/null)/shell/key-bindings.zsh"
    )
    
    # Find and source completion script
    for path in "${completion_paths[@]}"; do
        if [[ -f "$path" ]]; then
            append_if_missing "$SHELL_CONFIG" "source \"$path\"" "fzf.*completion"
            debug "Added fzf completion: $path"
            break
        fi
    done
    
    # Find and source key bindings script
    for path in "${keybinding_paths[@]}"; do
        if [[ -f "$path" ]]; then
            append_if_missing "$SHELL_CONFIG" "source \"$path\"" "fzf.*key-bindings"
            debug "Added fzf key bindings: $path"
            break
        fi
    done
}

configure_fzf_options() {
    local fzf_options='export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --inline-info"'
    
    # Configure default command to use fd or ripgrep if available
    if command_exists fd; then
        local fzf_default_command='export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"'
        append_if_missing "$SHELL_CONFIG" "$fzf_default_command" "FZF_DEFAULT_COMMAND"
    elif command_exists rg; then
        local fzf_default_command='export FZF_DEFAULT_COMMAND="rg --files --hidden --follow --glob '!.git/*'"'
        append_if_missing "$SHELL_CONFIG" "$fzf_default_command" "FZF_DEFAULT_COMMAND"
    fi
    
    # Add fzf options
    append_if_missing "$SHELL_CONFIG" "$fzf_options" "FZF_DEFAULT_OPTS"
    
    # Configure Ctrl-T to use fd if available
    if command_exists fd; then
        local ctrl_t_command='export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"'
        append_if_missing "$SHELL_CONFIG" "$ctrl_t_command" "FZF_CTRL_T_COMMAND"
    fi
    
    # Configure Alt-C for directory navigation
    if command_exists fd; then
        local alt_c_command='export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git"'
        append_if_missing "$SHELL_CONFIG" "$alt_c_command" "FZF_ALT_C_COMMAND"
    fi
}

# Add useful fzf aliases
configure_fzf_aliases() {
    local aliases=(
        'alias fzp="fzf --preview \"bat --style=numbers --color=always --line-range :500 {}\""'
        'alias fzv="fzf --preview \"bat --style=numbers --color=always --line-range :500 {}\" --bind \"enter:execute(vim {})\""'
    )
    
    for alias_def in "${aliases[@]}"; do
        append_if_missing "$SHELL_CONFIG" "$alias_def" "${alias_def%=*}"
    done
}

# Verify fzf installation
verify_fzf() {
    if ! command_exists fzf; then
        error_exit "fzf installation failed"
    fi
    
    local fzf_version
    fzf_version=$(fzf --version | cut -d' ' -f1)
    log "fzf version: $fzf_version"
    
    # Test fzf with a simple command
    if echo "test" | fzf --select-1 --exit-0 >/dev/null 2>&1; then
        debug "fzf is working correctly"
    else
        warn "fzf may not be working correctly"
    fi
}

# Main installation function
main() {
    install_fzf
    configure_fzf
    configure_fzf_aliases
    verify_fzf
    
    log "fzf installation and configuration completed"
    log "Key bindings: Ctrl-T (files), Ctrl-R (history), Alt-C (directories)"
}

# Run main function
main