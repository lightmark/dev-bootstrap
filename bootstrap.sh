#!/bin/bash

# Production-grade Development Environment Bootstrap
# Supports Ubuntu 22.04/24.04 and macOS
# Usage: ./bootstrap.sh [--dry-run] [--yes] [--skip component1,component2]

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INSTALL_DIR="${SCRIPT_DIR}/install"
readonly CONFIGS_DIR="${SCRIPT_DIR}/configs"
readonly BACKUPS_DIR="${SCRIPT_DIR}/backups"
readonly LOG_FILE="${SCRIPT_DIR}/bootstrap.log"

# Default components
readonly DEFAULT_COMPONENTS="system,tmux,fzf,git"
readonly OPTIONAL_COMPONENTS="ssh,vim"

# CLI flags
DRY_RUN=false
AUTO_YES=false
SKIP_COMPONENTS=""
INSTALL_COMPONENTS="${DEFAULT_COMPONENTS}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Initialize logging
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

# Error handling
error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    echo "Check log file: $LOG_FILE"
    exit 1
}

# Trap errors
trap 'error_exit "Script failed at line $LINENO"' ERR

# Utility functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error_exit "Do not run this script as root. Use a regular user with sudo access."
    fi
}

# Detect OS and package manager
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get >/dev/null 2>&1; then
            export OS_TYPE="ubuntu"
            export PKG_MANAGER="apt"
        else
            error_exit "Unsupported Linux distribution. Only Ubuntu is supported."
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        export OS_TYPE="macos"
        export PKG_MANAGER="brew"
    else
        error_exit "Unsupported operating system: $OSTYPE"
    fi
    
    log "Detected OS: $OS_TYPE with package manager: $PKG_MANAGER"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                log "Dry run mode enabled"
                shift
                ;;
            --yes|-y)
                AUTO_YES=true
                log "Auto-yes mode enabled"
                shift
                ;;
            --skip)
                SKIP_COMPONENTS="$2"
                log "Skipping components: $SKIP_COMPONENTS"
                shift 2
                ;;
            --components)
                INSTALL_COMPONENTS="$2"
                log "Installing components: $INSTALL_COMPONENTS"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                error_exit "Unknown option: $1"
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Development Environment Bootstrap

Usage: $0 [OPTIONS]

OPTIONS:
    --dry-run           Show what would be done without making changes
    --yes, -y           Automatically answer yes to all prompts
    --skip COMPONENTS   Comma-separated list of components to skip
    --components LIST   Comma-separated list of components to install (default: $DEFAULT_COMPONENTS)
    --help, -h          Show this help message

COMPONENTS:
    system             Essential system tools (curl, git, build-essential)
    tmux               Terminal multiplexer with configuration
    fzf                Fuzzy finder with key bindings
    git                Git configuration and aliases
    ssh                SSH client configuration (optional)
    vim                Minimal vim configuration (optional)

EXAMPLES:
    $0                          # Install default components
    $0 --skip tmux,vim          # Skip tmux and vim
    $0 --components system,fzf  # Install only system tools and fzf
    $0 --dry-run               # Preview what would be installed
EOF
}

# Create necessary directories
setup_directories() {
    local dirs=("$BACKUPS_DIR")
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                debug "Would create directory: $dir"
            else
                mkdir -p "$dir"
                log "Created directory: $dir"
            fi
        fi
    done
}

# Filter components based on skip list
filter_components() {
    local components="$INSTALL_COMPONENTS"
    
    if [[ -n "$SKIP_COMPONENTS" ]]; then
        IFS=',' read -ra SKIP_ARRAY <<< "$SKIP_COMPONENTS"
        for skip in "${SKIP_ARRAY[@]}"; do
            components=$(echo "$components" | sed "s/$skip,//g" | sed "s/,$skip//g" | sed "s/^$skip$//g")
        done
    fi
    
    echo "$components"
}

# Install components
install_components() {
    local components
    components=$(filter_components)
    
    IFS=',' read -ra COMPONENT_ARRAY <<< "$components"
    
    log "Installing components: ${components}"
    
    for component in "${COMPONENT_ARRAY[@]}"; do
        if [[ -z "$component" ]]; then
            continue
        fi
        
        local install_script="${INSTALL_DIR}/${component}.sh"
        
        if [[ ! -f "$install_script" ]]; then
            warn "Install script not found: $install_script"
            continue
        fi
        
        log "Installing component: $component"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            debug "Would run: $install_script"
        else
            # Source common functions and run component installer
            source "${INSTALL_DIR}/common.sh"
            source "$install_script"
        fi
    done
}

# Verification
verify_installation() {
    log "Verifying installation..."
    
    local failed_checks=()
    
    # Check if installed tools are available
    local tools=("git" "curl")
    
    # Add tools based on installed components
    if [[ "$INSTALL_COMPONENTS" == *"tmux"* ]]; then
        tools+=("tmux")
    fi
    if [[ "$INSTALL_COMPONENTS" == *"fzf"* ]]; then
        tools+=("fzf")
    fi
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            failed_checks+=("$tool not found in PATH")
        fi
    done
    
    if [[ ${#failed_checks[@]} -gt 0 ]]; then
        warn "Some verification checks failed:"
        for check in "${failed_checks[@]}"; do
            warn "  - $check"
        done
    else
        log "All verification checks passed!"
    fi
}

# Main execution
main() {
    echo "=== Development Environment Bootstrap ===" 
    echo "Started at: $(date)"
    echo
    
    check_root
    parse_args "$@"
    detect_os
    setup_directories
    
    if [[ "$AUTO_YES" == "false" ]]; then
        echo "This will install development tools and configure your environment."
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Installation cancelled by user"
            exit 0
        fi
    fi
    
    install_components
    verify_installation
    
    echo
    log "Bootstrap completed successfully!"
    log "Log file: $LOG_FILE"
    log "Backups stored in: $BACKUPS_DIR"
    
    if [[ "$OS_TYPE" == "ubuntu" ]]; then
        log "You may need to restart your shell or run: source ~/.bashrc"
    elif [[ "$OS_TYPE" == "macos" ]]; then
        log "You may need to restart your shell or run: source ~/.zshrc"
    fi
}

# Run main function with all arguments
main "$@"