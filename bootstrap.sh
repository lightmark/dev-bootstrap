#!/usr/bin/env bash
#
# Universal Development Environment Bootstrap
# Supports both local development and VPS deployment
# 
# Usage: ./bootstrap.sh [OPTIONS]
#

set -euo pipefail

# Colors and formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Global variables
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIGS_DIR="${SCRIPT_DIR}/configs"
readonly BACKUP_ROOT="${HOME}/.bootstrap-backups"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

# Default options
DRY_RUN=false
AUTO_YES=false
ROLE=""
SKIP_MODULES=""
ONLY_MODULES=""
SETUP_GITHUB_KEY=false
SSH_KEY_NAME=""
SSH_ALIAS="github-dev"
SSH_EMAIL=""
USE_SSH_ALIAS=true
FORCE_SSH=false

# Available modules
readonly ALL_MODULES="packages,dotfiles,tmux,shell,ssh,claude"
DEFAULT_LOCAL_MODULES="packages,dotfiles,tmux,shell,claude"
DEFAULT_VPS_MODULES="packages,dotfiles,tmux,shell,ssh"

# Error handler
error_exit() {
    local line_no="${1:-}"
    local error_code="${2:-1}"
    local command="${BASH_COMMAND:-unknown}"
    
    log_error "Script failed at line ${line_no}: ${command}"
    log_error "Exit code: ${error_code}"
    exit "${error_code}"
}

# Set up error trapping
trap 'error_exit ${LINENO} $?' ERR

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*"
    fi
}

# Utility functions
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

is_macos() {
    [[ "$OSTYPE" == "darwin"* ]]
}

is_ubuntu() {
    [[ -f /etc/os-release ]] && grep -q "ID=ubuntu" /etc/os-release
}

backup_file() {
    local file="$1"
    if [[ -e "$file" ]]; then
        local basename=$(basename "$file")
        local backup_path="${BACKUP_DIR}/${basename}.backup"
        mkdir -p "$BACKUP_DIR"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_debug "Would backup: $file -> $backup_path"
        else
            cp -r "$file" "$backup_path"
            log_info "Backed up: $file"
        fi
    fi
}

safe_append() {
    local file="$1"
    local content="$2"
    local marker="${3:-}"
    
    # Create file if it doesn't exist
    if [[ ! -f "$file" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_debug "Would create: $file"
            return 0
        else
            touch "$file"
        fi
    fi
    
    # Check if content already exists
    if [[ -n "$marker" ]]; then
        if grep -q "$marker" "$file" 2>/dev/null; then
            log_debug "Content already exists in $file (marker: $marker)"
            return 0
        fi
    else
        if grep -Fq "$content" "$file" 2>/dev/null; then
            log_debug "Content already exists in $file"
            return 0
        fi
    fi
    
    # Append content
    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "Would append to $file: $content"
    else
        backup_file "$file"
        echo "$content" >> "$file"
        log_info "Appended content to $file"
    fi
}

safe_symlink() {
    local source="$1"
    local target="$2"
    
    if [[ ! -e "$source" ]]; then
        log_warn "Source file does not exist: $source"
        return 1
    fi
    
    if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
        log_debug "Symlink already exists: $target -> $source"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "Would create symlink: $target -> $source"
        return 0
    fi
    
    backup_file "$target"
    mkdir -p "$(dirname "$target")"
    ln -sf "$source" "$target"
    log_info "Created symlink: $target -> $source"
}

# Show help
show_help() {
    cat << 'EOF'
Universal Development Environment Bootstrap

USAGE:
    ./bootstrap.sh [OPTIONS]

OPTIONS:
    --role local|vps        Specify environment role (auto-detected if not set)
    --yes, -y              Skip confirmation prompts
    --dry-run              Show what would be done without making changes
    --skip MODULE[,...]    Skip specific modules
    --only MODULE[,...]    Run only specific modules
    --setup-github-key     Generate GitHub SSH key (auto-enabled for VPS role)
    --key-name NAME        SSH key name (default: id_ed25519_github_dev)
    --email EMAIL          Email for SSH key
    --alias ALIAS          SSH host alias (default: github-dev)
    --no-alias            Don't use SSH host alias
    --force               Force regenerate SSH key if exists
    --help, -h            Show this help

MODULES:
    packages              Install essential packages (tmux, git, fzf, ripgrep, etc.)
    dotfiles              Link configuration files from configs/
    tmux                  Configure tmux with vi bindings and mouse support
    shell                 Configure bash history and aliases
    ssh                   Generate GitHub SSH key and configure (VPS/explicit only)
    claude                Setup Claude Teams integration (local environments only)

EXAMPLES:
    ./bootstrap.sh --role local
    ./bootstrap.sh --role vps --setup-github-key
    ./bootstrap.sh --only ssh --role vps --key-name mykey
    ./bootstrap.sh --only claude --role local
    ./bootstrap.sh --skip packages --dry-run

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --role)
                ROLE="$2"
                if [[ "$ROLE" != "local" && "$ROLE" != "vps" ]]; then
                    log_error "Invalid role: $ROLE. Must be 'local' or 'vps'"
                    exit 1
                fi
                shift 2
                ;;
            --yes|-y)
                AUTO_YES=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                log_info "Dry run mode enabled"
                shift
                ;;
            --skip)
                SKIP_MODULES="$2"
                shift 2
                ;;
            --only)
                ONLY_MODULES="$2"
                shift 2
                ;;
            --setup-github-key)
                SETUP_GITHUB_KEY=true
                shift
                ;;
            --key-name)
                SSH_KEY_NAME="$2"
                shift 2
                ;;
            --email)
                SSH_EMAIL="$2"
                shift 2
                ;;
            --alias)
                SSH_ALIAS="$2"
                shift 2
                ;;
            --no-alias)
                USE_SSH_ALIAS=false
                shift
                ;;
            --force)
                FORCE_SSH=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Auto-detect environment role
detect_role() {
    if [[ -n "$ROLE" ]]; then
        log_info "Using specified role: $ROLE"
        return
    fi
    
    # Simple heuristics for role detection
    if [[ -n "${SSH_CONNECTION:-}" ]] || [[ -n "${SSH_CLIENT:-}" ]] || [[ -n "${SSH_TTY:-}" ]]; then
        ROLE="vps"
        log_info "Detected VPS environment (SSH connection)"
    elif is_macos; then
        ROLE="local"
        log_info "Detected local environment (macOS)"
    elif command_exists systemctl && systemctl is-system-running >/dev/null 2>&1; then
        ROLE="vps"
        log_info "Detected VPS environment (systemd)"
    else
        ROLE="local"
        log_info "Defaulting to local environment"
    fi
}

# Determine which modules to run
determine_modules() {
    local modules=""
    
    # Start with default modules based on role
    if [[ "$ROLE" == "vps" ]]; then
        modules="$DEFAULT_VPS_MODULES"
    else
        modules="$DEFAULT_LOCAL_MODULES"
    fi
    
    # Override with --only if specified
    if [[ -n "$ONLY_MODULES" ]]; then
        modules="$ONLY_MODULES"
    fi
    
    # Remove modules from --skip
    if [[ -n "$SKIP_MODULES" ]]; then
        IFS=',' read -ra skip_array <<< "$SKIP_MODULES"
        for skip in "${skip_array[@]}"; do
            modules=$(echo "$modules" | sed "s/$skip,//g" | sed "s/,$skip//g" | sed "s/^$skip$//g")
        done
    fi
    
    # Clean up any double commas
    modules=$(echo "$modules" | sed 's/,,/,/g' | sed 's/^,//g' | sed 's/,$//g')
    
    echo "$modules"
}

# Module: Install packages
module_packages() {
    log_info "Installing essential packages..."
    
    local packages=()
    
    if is_macos; then
        # Check for Homebrew
        if ! command_exists brew; then
            log_info "Installing Homebrew..."
            if [[ "$DRY_RUN" == "true" ]]; then
                log_debug "Would install Homebrew"
            else
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
        fi
        
        packages=(git tmux fzf ripgrep fd bat tree htop jq direnv)
        
        for pkg in "${packages[@]}"; do
            if brew list "$pkg" >/dev/null 2>&1; then
                log_debug "Package already installed: $pkg"
            else
                log_info "Installing: $pkg"
                if [[ "$DRY_RUN" == "true" ]]; then
                    log_debug "Would run: brew install $pkg"
                else
                    brew install "$pkg"
                fi
            fi
        done
        
    elif is_ubuntu; then
        # Update package list
        if [[ "$DRY_RUN" == "true" ]]; then
            log_debug "Would run: apt update"
        else
            sudo apt-get update -qq
        fi
        
        packages=(git tmux fzf ripgrep fd-find bat tree htop jq build-essential curl ca-certificates)
        
        for pkg in "${packages[@]}"; do
            if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
                log_debug "Package already installed: $pkg"
            else
                log_info "Installing: $pkg"
                if [[ "$DRY_RUN" == "true" ]]; then
                    log_debug "Would run: apt install $pkg"
                else
                    sudo apt-get install -y "$pkg"
                fi
            fi
        done
        
        # Create fd and bat symlinks for Ubuntu
        if [[ "$DRY_RUN" == "true" ]]; then
            log_debug "Would create directory: $HOME/.local/bin"
        else
            mkdir -p "$HOME/.local/bin"
        fi
        if command_exists fdfind && [[ ! -f "$HOME/.local/bin/fd" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_debug "Would create fd symlink"
            else
                ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
                log_info "Created fd symlink"
            fi
        fi
        
        if command_exists batcat && [[ ! -f "$HOME/.local/bin/bat" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_debug "Would create bat symlink"
            else
                ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
                log_info "Created bat symlink"
            fi
        fi
        
        # Add ~/.local/bin to PATH if not already there
        safe_append "$HOME/.bashrc" 'export PATH="$HOME/.local/bin:$PATH"' '.local/bin'
        
        # Install direnv manually
        if ! command_exists direnv; then
            log_info "Installing direnv..."
            if [[ "$DRY_RUN" == "true" ]]; then
                log_debug "Would install direnv"
            else
                local direnv_version="v2.32.3"
                local direnv_url="https://github.com/direnv/direnv/releases/download/${direnv_version}/direnv.linux-amd64"
                curl -fsSL "$direnv_url" -o "$HOME/.local/bin/direnv"
                chmod +x "$HOME/.local/bin/direnv"
                log_info "Installed direnv to ~/.local/bin/direnv"
            fi
        fi
        
    else
        log_warn "Unsupported OS for package installation"
        return 1
    fi
}

# Module: Setup dotfiles
module_dotfiles() {
    log_info "Setting up dotfiles..."
    
    # Link configuration files if they exist
    local configs=(
        ".tmux.conf:$HOME/.tmux.conf"
        ".gitconfig:$HOME/.gitconfig"
        ".vimrc:$HOME/.vimrc"
    )
    
    for config in "${configs[@]}"; do
        local source="${CONFIGS_DIR}/${config%:*}"
        local target="${config#*:}"
        
        if [[ -f "$source" ]]; then
            safe_symlink "$source" "$target"
        else
            log_debug "Config file not found, skipping: $source"
        fi
    done
    
    # Append configuration snippets
    if [[ -f "${CONFIGS_DIR}/.bashrc.snippet" ]]; then
        safe_append "$HOME/.bashrc" "" "# Bootstrap configuration"
        safe_append "$HOME/.bashrc" "# Bootstrap configuration" "# Bootstrap configuration"
        while IFS= read -r line; do
            safe_append "$HOME/.bashrc" "$line"
        done < "${CONFIGS_DIR}/.bashrc.snippet"
    fi
    
    if [[ -f "${CONFIGS_DIR}/.aliases" ]]; then
        safe_append "$HOME/.bashrc" "source ${CONFIGS_DIR}/.aliases" "source ${CONFIGS_DIR}/.aliases"
    fi
}

# Module: Configure tmux
module_tmux() {
    log_info "Configuring tmux..."
    
    local tmux_config="$HOME/.tmux.conf"
    
    # Check if config already exists and has our settings
    if [[ -f "$tmux_config" ]] && grep -q "# Bootstrap tmux config" "$tmux_config" 2>/dev/null; then
        log_debug "Tmux already configured"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "Would configure tmux"
        return 0
    fi
    
    backup_file "$tmux_config"
    
    cat >> "$tmux_config" << 'EOF'

# Bootstrap tmux config
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",*256col*:Tc"

# Vi mode
setw -g mode-keys vi
bind-key -T copy-mode-vi 'v' send -X begin-selection
bind-key -T copy-mode-vi 'y' send -X copy-selection

# Mouse support
set -g mouse on

# Split panes
bind | split-window -h
bind - split-window -v

# Reload config
bind r source-file ~/.tmux.conf \; display-message "Config reloaded!"

# Start windows and panes at 1
set -g base-index 1
setw -g pane-base-index 1
EOF
    
    log_info "Configured tmux with vi bindings and mouse support"
}

# Module: Configure shell
module_shell() {
    log_info "Configuring shell..."
    
    local bashrc="$HOME/.bashrc"
    
    # Bash history settings
    local history_config="
# Bootstrap history configuration
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
shopt -s histappend
export PROMPT_COMMAND=\"history -a; history -c; history -r; \$PROMPT_COMMAND\"
"
    
    safe_append "$bashrc" "$history_config" "Bootstrap history configuration"
    
    # Add direnv hook if direnv is installed
    if command_exists direnv; then
        safe_append "$bashrc" 'eval "$(direnv hook bash)"' "direnv hook"
    fi
    
    # Common aliases
    if [[ -f "${CONFIGS_DIR}/.aliases" ]]; then
        safe_append "$bashrc" "source ${CONFIGS_DIR}/.aliases" "source ${CONFIGS_DIR}/.aliases"
    else
        local aliases="
# Bootstrap aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
"
        safe_append "$bashrc" "$aliases" "Bootstrap aliases"
    fi
}

# Module: Setup Claude Teams integration
module_claude() {
    log_info "Setting up Claude Teams integration..."
    
    # Only install on local environments, skip for VPS
    if [[ "$ROLE" == "vps" ]]; then
        log_info "Skipping Claude setup for VPS environment"
        return 0
    fi
    
    local home_claude_dir="$HOME/.claude"
    local settings_file="$home_claude_dir/settings.json"
    local template_file="$CONFIGS_DIR/claude_settings.json"
    
    # Check if template exists
    if [[ ! -f "$template_file" ]]; then
        log_warn "Claude settings template not found: $template_file"
        return 1
    fi
    
    # Create .claude directory in home
    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "Would create directory: $home_claude_dir"
    else
        mkdir -p "$home_claude_dir"
        chmod 755 "$home_claude_dir"
        log_info "Created Claude directory: $home_claude_dir"
    fi
    
    # Check if settings already exist
    if [[ -f "$settings_file" ]]; then
        log_info "Claude settings already exist at: $settings_file"
        
        # Check if Claude Teams is already enabled
        if grep -q '"enabled": true' "$settings_file" 2>/dev/null; then
            log_info "Claude Teams appears to be already enabled"
            return 0
        else
            backup_file "$settings_file"
        fi
    fi
    
    # Copy template to home directory
    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "Would copy Claude settings: $template_file -> $settings_file"
    else
        backup_file "$settings_file"
        cp "$template_file" "$settings_file"
        chmod 644 "$settings_file"
        log_info "Installed Claude Teams settings: $settings_file"
    fi
    
    # Add to gitignore if we're in a git repo
    if git rev-parse --git-dir >/dev/null 2>&1; then
        local gitignore_file="$HOME/.gitignore_global"
        
        # Setup global gitignore if it doesn't exist
        if [[ ! -f "$gitignore_file" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_debug "Would create global gitignore: $gitignore_file"
            else
                touch "$gitignore_file"
                git config --global core.excludesfile "$gitignore_file"
                log_info "Created global gitignore: $gitignore_file"
            fi
        fi
        
        # Add .claude to global gitignore
        safe_append "$gitignore_file" ".claude/" ".claude directory"
    fi
    
    log_info "Claude Teams integration configured successfully"
    if [[ "$DRY_RUN" == "false" ]]; then
        echo
        log_info "Claude Teams Features Enabled:"
        log_info "• Full workspace access for development"
        log_info "• Read/write permissions for code files" 
        log_info "• Execute permissions for scripts and dev tools"
        log_info "• Git integration (commit allowed, push disabled)"
        log_info "• Multi-language development support"
        echo
    fi
}

# Module: Setup SSH for GitHub
module_ssh() {
    log_info "Setting up SSH for GitHub..."
    
    # Set defaults
    if [[ -z "$SSH_KEY_NAME" ]]; then
        SSH_KEY_NAME="id_ed25519_github_dev"
    fi
    
    if [[ -z "$SSH_EMAIL" ]]; then
        SSH_EMAIL="$(git config --global user.email 2>/dev/null || echo "user@$(hostname)")"
    fi
    
    local ssh_dir="$HOME/.ssh"
    local key_path="${ssh_dir}/${SSH_KEY_NAME}"
    local config_path="${ssh_dir}/config"
    
    # Create SSH directory
    if [[ "$DRY_RUN" == "true" ]]; then
        log_debug "Would create SSH directory: $ssh_dir"
    else
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
    fi
    
    # Generate SSH key if it doesn't exist or force is specified
    if [[ ! -f "$key_path" ]] || [[ "$FORCE_SSH" == "true" ]]; then
        log_info "Generating SSH key: $key_path"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_debug "Would generate SSH key with email: $SSH_EMAIL"
        else
            backup_file "$key_path"
            backup_file "${key_path}.pub"
            ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$key_path" -N ""
            chmod 600 "$key_path"
            chmod 644 "${key_path}.pub"
            log_info "Generated SSH key: $key_path"
        fi
    else
        log_debug "SSH key already exists: $key_path"
    fi
    
    # Add GitHub to known_hosts
    local known_hosts="${ssh_dir}/known_hosts"
    if ! grep -q "github.com" "$known_hosts" 2>/dev/null; then
        log_info "Adding GitHub to known_hosts"
        if [[ "$DRY_RUN" == "true" ]]; then
            log_debug "Would run: ssh-keyscan github.com"
        else
            ssh-keyscan github.com >> "$known_hosts" 2>/dev/null
            log_info "Added GitHub to known_hosts"
        fi
    else
        log_debug "GitHub already in known_hosts"
    fi
    
    # Configure SSH config
    if [[ "$USE_SSH_ALIAS" == "true" ]]; then
        local ssh_config="
# Bootstrap GitHub SSH configuration
Host $SSH_ALIAS
    HostName github.com
    User git
    IdentityFile $key_path
    IdentitiesOnly yes
"
        safe_append "$config_path" "$ssh_config" "Host $SSH_ALIAS"
        
        if [[ "$DRY_RUN" == "false" ]]; then
            chmod 600 "$config_path"
        fi
        
        log_info "Configured SSH alias: $SSH_ALIAS -> github.com"
    fi
    
    # Test SSH connection (allow failure)
    if [[ "$DRY_RUN" == "false" ]] && [[ -f "$key_path" ]]; then
        log_info "Testing SSH connection to GitHub..."
        local test_host="github.com"
        if [[ "$USE_SSH_ALIAS" == "true" ]]; then
            test_host="$SSH_ALIAS"
        fi
        
        if ssh -T "git@$test_host" -o ConnectTimeout=10 -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"; then
            log_info "SSH connection to GitHub successful!"
        else
            log_warn "SSH connection failed - this is expected if the key hasn't been added to GitHub yet"
        fi
    fi
    
    # Display public key
    if [[ -f "${key_path}.pub" ]] && [[ "$DRY_RUN" == "false" ]]; then
        echo
        log_info "Your GitHub SSH public key:"
        echo -e "${BOLD}$(cat "${key_path}.pub")${NC}"
        echo
        log_info "Add this key to GitHub:"
        log_info "  - For personal access: https://github.com/settings/ssh/new"
        log_info "  - For repository deploy key: https://github.com/USER/REPO/settings/keys"
        echo
    fi
}

# Main execution
main() {
    echo -e "${BOLD}=== Universal Development Environment Bootstrap ===${NC}"
    echo "Started at: $(date)"
    echo
    
    parse_args "$@"
    detect_role
    
    # Enable SSH module for VPS role or if explicitly requested
    if [[ "$ROLE" == "vps" ]] || [[ "$SETUP_GITHUB_KEY" == "true" ]]; then
        if [[ "$SETUP_GITHUB_KEY" == "false" ]]; then
            SETUP_GITHUB_KEY=true
            log_info "Auto-enabling GitHub SSH key setup for VPS role"
        fi
        # Add SSH to default modules if not already specified
        if [[ -z "$ONLY_MODULES" ]] && [[ "$ROLE" == "local" ]]; then
            DEFAULT_LOCAL_MODULES="${DEFAULT_LOCAL_MODULES},ssh"
        fi
    fi
    
    local modules
    modules=$(determine_modules)
    
    log_info "Role: $ROLE"
    log_info "Modules to run: $modules"
    
    # Confirmation prompt
    if [[ "$AUTO_YES" == "false" ]] && [[ "$DRY_RUN" == "false" ]]; then
        echo
        read -p "Continue with installation? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled by user"
            exit 0
        fi
    fi
    
    # Create backup directory
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$BACKUP_DIR"
        log_info "Backups will be saved to: $BACKUP_DIR"
    fi
    
    # Run modules
    local completed_modules=()
    local skipped_modules=()
    
    IFS=',' read -ra module_array <<< "$modules"
    for module in "${module_array[@]}"; do
        if [[ -z "$module" ]]; then
            continue
        fi
        
        echo
        log_info "Running module: $module"
        
        case "$module" in
            packages)
                if module_packages; then
                    completed_modules+=("$module")
                else
                    skipped_modules+=("$module (failed)")
                fi
                ;;
            dotfiles)
                if module_dotfiles; then
                    completed_modules+=("$module")
                else
                    skipped_modules+=("$module (failed)")
                fi
                ;;
            tmux)
                if module_tmux; then
                    completed_modules+=("$module")
                else
                    skipped_modules+=("$module (failed)")
                fi
                ;;
            shell)
                if module_shell; then
                    completed_modules+=("$module")
                else
                    skipped_modules+=("$module (failed)")
                fi
                ;;
            ssh)
                if module_ssh; then
                    completed_modules+=("$module")
                else
                    skipped_modules+=("$module (failed)")
                fi
                ;;
            claude)
                if module_claude; then
                    completed_modules+=("$module")
                else
                    skipped_modules+=("$module (failed)")
                fi
                ;;
            *)
                log_warn "Unknown module: $module"
                skipped_modules+=("$module (unknown)")
                ;;
        esac
    done
    
    # Summary
    echo
    echo -e "${BOLD}=== Installation Summary ===${NC}"
    
    if [[ ${#completed_modules[@]} -gt 0 ]]; then
        log_info "Completed modules: ${completed_modules[*]}"
    fi
    
    if [[ ${#skipped_modules[@]} -gt 0 ]]; then
        log_warn "Skipped modules: ${skipped_modules[*]}"
    fi
    
    if [[ "$DRY_RUN" == "false" ]] && [[ -d "$BACKUP_DIR" ]]; then
        log_info "Backups saved to: $BACKUP_DIR"
    fi
    
    echo
    log_info "Bootstrap completed successfully!"
    
    # Next steps
    echo
    echo -e "${BOLD}Next steps:${NC}"
    if [[ ${#completed_modules[@]} -gt 0 ]]; then
        local completed_str="${completed_modules[*]}"
        if [[ "$completed_str" == *"shell"* ]]; then
            log_info "• Restart your shell or run: source ~/.bashrc"
        fi
        
        if [[ "$completed_str" == *"ssh"* ]]; then
            log_info "• Add the SSH public key to GitHub (see above)"
            if [[ "$USE_SSH_ALIAS" == "true" ]]; then
                log_info "• Use SSH alias in git remotes: git@${SSH_ALIAS}:user/repo.git"
            fi
        fi
        
        if [[ "$completed_str" == *"packages"* ]]; then
            log_info "• All tools are ready to use!"
        fi
    else
        log_info "• No modules were completed successfully"
    fi
}

# Handle script being sourced vs executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi