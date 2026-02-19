#!/bin/bash

# Git configuration and useful aliases
# Sets up git with sensible defaults and productivity aliases

init_common

log "Configuring git..."

# Configure git with extended settings
configure_git_extended() {
    log "Setting up extended git configuration..."
    
    # Core configuration
    local git_configs=(
        # Core settings
        "core.editor:vim"
        "core.pager:less -FRX"
        "core.excludesfile:~/.gitignore_global"
        "core.attributesfile:~/.gitattributes_global"
        "core.precomposeUnicode:true"
        
        # Color settings
        "color.branch:auto"
        "color.diff:auto"
        "color.grep:auto"
        "color.interactive:auto"
        "color.status:auto"
        "color.push:auto"
        
        # Diff and merge settings
        "diff.tool:vimdiff"
        "merge.tool:vimdiff"
        "merge.conflictstyle:diff3"
        "diff.algorithm:patience"
        
        # Push and pull settings
        "push.default:simple"
        "push.followTags:true"
        "pull.rebase:false"
        
        # Branch settings
        "branch.autosetupmerge:always"
        "branch.autosetuprebase:never"
        
        # Rebase settings
        "rebase.autoStash:true"
        
        # Status settings
        "status.showUntrackedFiles:all"
        
        # Log settings
        "log.decorate:short"
    )
    
    for config in "${git_configs[@]}"; do
        local key="${config%:*}"
        local value="${config#*:}"
        
        # Only set if not already configured
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

# Set up useful git aliases
configure_git_aliases() {
    log "Setting up git aliases..."
    
    local git_aliases=(
        # Status and info
        "st:status -s"
        "stat:status"
        "info:remote -v"
        
        # Logging
        "lg:log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
        "lga:log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --all"
        "ll:log --pretty=format:'%C(yellow)%h%Cred%d\\ %Creset%s%Cblue\\ [%cn]' --decorate --numstat"
        "lol:log --graph --decorate --pretty=oneline --abbrev-commit"
        "lola:log --graph --decorate --pretty=oneline --abbrev-commit --all"
        
        # Branching
        "br:branch"
        "co:checkout"
        "cob:checkout -b"
        "com:checkout main"
        "cod:checkout develop"
        
        # Committing
        "ci:commit"
        "ca:commit -a"
        "cam:commit -am"
        "amend:commit --amend"
        "amendn:commit --amend --no-edit"
        
        # Diffing
        "df:diff"
        "dfc:diff --cached"
        "dfh:diff HEAD"
        "dfn:diff --name-only"
        
        # Adding and resetting
        "aa:add --all"
        "ap:add -p"
        "unstage:reset HEAD --"
        "undo:reset --soft HEAD~1"
        
        # Stashing
        "sl:stash list"
        "sp:stash pop"
        "ss:stash save"
        "sd:stash drop"
        
        # Remote operations
        "pl:pull"
        "ps:push"
        "pso:push origin"
        "psu:push -u origin"
        "ft:fetch"
        "fta:fetch --all"
        
        # Utilities
        "alias:config --get-regexp alias"
        "whoami:config --get-regexp user"
        "cleanup:!git branch --merged | grep -v '\\*\\|main\\|master\\|develop' | xargs -n 1 git branch -d"
        "recent:branch --sort=-committerdate"
    )
    
    for alias_def in "${git_aliases[@]}"; do
        local alias_name="${alias_def%:*}"
        local alias_command="${alias_def#*:}"
        
        # Only set if not already configured
        if ! git config --global "alias.$alias_name" >/dev/null 2>&1; then
            if [[ "$DRY_RUN" == "true" ]]; then
                debug "Would set git alias: $alias_name = $alias_command"
            else
                git config --global "alias.$alias_name" "$alias_command"
                log "Set git alias: $alias_name = $alias_command"
            fi
        else
            debug "Git alias already set: $alias_name"
        fi
    done
}

# Create global gitignore file
create_global_gitignore() {
    local global_gitignore="$HOME/.gitignore_global"
    
    if [[ -f "$global_gitignore" ]]; then
        debug "Global gitignore already exists: $global_gitignore"
        return 0
    fi
    
    log "Creating global gitignore file..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        debug "Would create global gitignore: $global_gitignore"
        return 0
    fi
    
    cat > "$global_gitignore" << 'EOF'
# Global gitignore patterns

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Editor files
*~
*.swp
*.swo
.vscode/
.idea/
*.sublime-*

# Log files
*.log
logs/

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Coverage directory used by tools like istanbul
coverage/
*.lcov

# Dependency directories
node_modules/
bower_components/

# Optional npm cache directory
.npm

# dotenv environment variables file
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Build directories
build/
dist/
out/

# Temporary files
tmp/
temp/
*.tmp
*.temp

# Cache directories
.cache/
.parcel-cache/

# IDEs and editors
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db
EOF
    
    log "Created global gitignore: $global_gitignore"
}

# Create global gitattributes file
create_global_gitattributes() {
    local global_gitattributes="$HOME/.gitattributes_global"
    
    if [[ -f "$global_gitattributes" ]]; then
        debug "Global gitattributes already exists: $global_gitattributes"
        return 0
    fi
    
    log "Creating global gitattributes file..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        debug "Would create global gitattributes: $global_gitattributes"
        return 0
    fi
    
    cat > "$global_gitattributes" << 'EOF'
# Global gitattributes

# Text files
*.txt text
*.md text
*.json text
*.yml text
*.yaml text
*.xml text
*.html text
*.css text
*.js text
*.ts text
*.jsx text
*.tsx text
*.py text
*.rb text
*.go text
*.rs text
*.c text
*.cpp text
*.h text
*.hpp text
*.java text
*.php text
*.sh text
*.bash text
*.zsh text
*.fish text

# Line ending normalization
* text=auto

# Binary files
*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.ico binary
*.svg binary
*.pdf binary
*.zip binary
*.tar.gz binary
*.tgz binary
*.exe binary
*.dll binary
*.so binary
*.dylib binary
EOF
    
    log "Created global gitattributes: $global_gitattributes"
}

# Setup git hooks template directory
setup_git_hooks() {
    local hooks_dir="$HOME/.git-templates/hooks"
    
    if [[ -d "$hooks_dir" ]]; then
        debug "Git hooks template directory already exists"
        return 0
    fi
    
    log "Setting up git hooks template directory..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        debug "Would create git hooks template directory: $hooks_dir"
        return 0
    fi
    
    mkdir -p "$hooks_dir"
    
    # Set template directory in git config
    git config --global init.templatedir "$HOME/.git-templates"
    
    log "Created git hooks template directory: $hooks_dir"
}

# Verify git configuration
verify_git_config() {
    if ! command_exists git; then
        error_exit "Git is not installed"
    fi
    
    local git_version
    git_version=$(git --version | cut -d' ' -f3)
    log "Git version: $git_version"
    
    # Check if user name and email are configured
    if ! git config --global user.name >/dev/null 2>&1; then
        warn "Git user.name is not configured. Run: git config --global user.name 'Your Name'"
    fi
    
    if ! git config --global user.email >/dev/null 2>&1; then
        warn "Git user.email is not configured. Run: git config --global user.email 'your@email.com'"
    fi
    
    # Verify global gitignore
    local global_gitignore
    global_gitignore=$(git config --global core.excludesfile)
    if [[ -f "$global_gitignore" ]]; then
        debug "Global gitignore configured: $global_gitignore"
    fi
    
    debug "Git configuration completed successfully"
}

# Main configuration function
main() {
    configure_git_extended
    configure_git_aliases
    create_global_gitignore
    create_global_gitattributes
    setup_git_hooks
    verify_git_config
    
    log "Git configuration completed"
    log "Use 'git alias' to see all available aliases"
}

# Run main function
main