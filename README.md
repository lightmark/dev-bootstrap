# Universal Development Environment Bootstrap

A comprehensive, production-ready bootstrap script that sets up development environments for both local machines (macOS) and VPS servers (Ubuntu). The script automatically detects your environment and configures essential tools, dotfiles, SSH keys, and Claude Teams integration.

## Features

- 🖥️ **Universal**: Works on both macOS (local) and Ubuntu (VPS) environments
- 🤖 **Smart Detection**: Automatically detects environment type (local vs VPS)
- 📦 **Package Management**: Installs essential development tools via Homebrew (macOS) or APT (Ubuntu)
- 🔧 **Modular Design**: Enable/disable specific components as needed
- 🔑 **SSH Integration**: Generates GitHub SSH keys with proper configuration
- 🤝 **Claude Teams**: Sets up Claude AI integration for local development
- 🛡️ **Safe Operations**: Dry-run mode, automatic backups, and idempotent execution
- 📋 **Rich Logging**: Colored output with detailed progress information

## Quick Start

```bash
# Clone the repository
git clone <your-repo-url> dev-bootstrap
cd dev-bootstrap

# Make executable
chmod +x bootstrap-new.sh

# Local development environment
./bootstrap-new.sh --role local

# VPS server environment
./bootstrap-new.sh --role vps --setup-github-key
```

## Installation Modules

| Module | Description | Local | VPS |
|--------|-------------|-------|-----|
| **packages** | Essential development tools (git, tmux, fzf, ripgrep, fd, bat, tree, htop, jq, direnv) | ✅ | ✅ |
| **dotfiles** | Links configuration files from `configs/` directory | ✅ | ✅ |
| **tmux** | Configures tmux with vi bindings, mouse support, and true color | ✅ | ✅ |
| **shell** | Sets up bash history, aliases, and direnv integration | ✅ | ✅ |
| **ssh** | Generates GitHub SSH keys and configures SSH client | ❌* | ✅ |
| **claude** | Sets up Claude Teams integration for AI-assisted development | ✅ | ❌ |

*\* SSH module can be explicitly enabled for local environments with `--setup-github-key`*

## Command Line Options

### Basic Options
- `--role local|vps` - Specify environment role (auto-detected if not provided)
- `--yes`, `-y` - Skip confirmation prompts
- `--dry-run` - Preview changes without executing them
- `--help`, `-h` - Show help information

### Module Control
- `--skip MODULE[,...]` - Skip specific modules (e.g., `--skip packages,ssh`)
- `--only MODULE[,...]` - Run only specific modules (e.g., `--only tmux,shell`)

### SSH Configuration
- `--setup-github-key` - Generate GitHub SSH key (auto-enabled for VPS)
- `--key-name NAME` - SSH key filename (default: `id_ed25519_github_dev`)
- `--email EMAIL` - Email for SSH key (defaults to git config user.email)
- `--alias ALIAS` - SSH host alias (default: `github-dev`)
- `--no-alias` - Don't create SSH host alias
- `--force` - Force regenerate SSH key if it exists

## Usage Examples

### Basic Setup
```bash
# Local development machine
./bootstrap-new.sh --role local

# VPS server with GitHub access
./bootstrap-new.sh --role vps --setup-github-key

# Auto-detect environment (recommended)
./bootstrap-new.sh
```

### Advanced Configuration
```bash
# Custom SSH key setup
./bootstrap-new.sh --role vps --key-name myproject_key --email dev@company.com

# Skip package installation, only configure dotfiles
./bootstrap-new.sh --skip packages --role local

# Only setup SSH and Claude integration
./bootstrap-new.sh --only ssh,claude --setup-github-key

# Preview what would be installed
./bootstrap-new.sh --dry-run

# Silent installation
./bootstrap-new.sh --yes --role local
```

## What Gets Installed

### Packages (macOS via Homebrew)
- git - Version control
- tmux - Terminal multiplexer  
- fzf - Fuzzy finder
- ripgrep - Fast text search
- fd - Fast file finder
- bat - Enhanced cat with syntax highlighting
- tree - Directory tree viewer
- htop - Interactive process viewer
- jq - JSON processor
- direnv - Environment variable manager

### Packages (Ubuntu via APT)
- git, tmux, fzf, ripgrep, fd-find, bat, tree, htop, jq
- build-essential, curl, ca-certificates
- direnv (installed manually from GitHub releases)

*Note: Ubuntu packages `fd-find` and `batcat` are automatically symlinked as `fd` and `bat`*

### Configuration Files

#### Tmux Configuration (`~/.tmux.conf`)
- Vi-style key bindings for copy mode
- Mouse support enabled
- True color (24-bit) support
- Intuitive pane splitting (| and -)
- Status bar customization
- Window/pane numbering starts at 1

#### Shell Configuration (`~/.bashrc`)
- Enhanced history settings (10k entries, no duplicates)
- Multi-session history synchronization
- direnv integration
- Common aliases and shortcuts
- PATH enhancements

#### SSH Configuration (`~/.ssh/config`)
- GitHub host alias configuration
- Optimized connection settings
- Identity file management
- Connection multiplexing

#### Claude Teams Integration (`~/.claude/settings.json`)
- Full workspace access permissions
- Multi-language development support
- Safe execution permissions
- Git integration (commit allowed, push disabled)
- Automatic sensitive file filtering

## SSH Key Management

The bootstrap script generates ed25519 SSH keys for GitHub integration:

### Key Features
- **Secure**: Uses ed25519 algorithm (modern, fast, secure)
- **Organized**: Custom key names to avoid conflicts
- **Configured**: Automatic SSH client configuration
- **Tested**: Validates connection to GitHub

### SSH Workflow
1. Generate SSH key pair in `~/.ssh/`
2. Set proper permissions (600 for private, 644 for public)
3. Add GitHub to known_hosts
4. Configure SSH client with host alias
5. Test connection and display public key

### Adding Keys to GitHub

After installation, add the displayed public key to GitHub:

**For personal repositories:**
- Go to [GitHub SSH Settings](https://github.com/settings/ssh/new)
- Paste the public key and save

**For organization/deploy keys:**
- Go to repository → Settings → Deploy keys
- Add key with appropriate permissions

### Using SSH Keys

```bash
# Clone with SSH alias (if configured)
git clone git@github-dev:username/repository.git

# Or use standard GitHub hostname
git clone git@github.com:username/repository.git

# Test SSH connection
ssh -T git@github-dev
# or
ssh -T git@github.com
```

## Claude Teams Integration

The Claude Teams module (local environments only) provides:

### Features
- **Workspace Access**: Full read/write permissions for development files
- **Language Support**: JavaScript, TypeScript, Python, Go, Rust, Shell, and more
- **Tool Integration**: npm, cargo, docker, git, and other development tools
- **Security**: Automatic filtering of sensitive files (.env, keys, credentials)
- **Git Integration**: Commit allowed, push disabled for safety

### Supported File Types
- Source code: `.js`, `.ts`, `.py`, `.go`, `.rs`, `.java`, `.cpp`, `.c`, etc.
- Configuration: `.json`, `.yaml`, `.toml`, `.conf`, `.ini`
- Documentation: `.md`, `.txt`, README files
- Build files: `Dockerfile`, `Makefile`, `package.json`

### Security Exclusions
- Environment files (`.env*`)
- SSH keys (`~/.ssh/id_*`)
- AWS credentials (`~/.aws/credentials`)
- Password/secret files
- Build artifacts (`node_modules/`, `target/`, `dist/`)

## Directory Structure

```
dev-bootstrap/
├── bootstrap-new.sh          # Main bootstrap script
├── configs/                  # Configuration templates
│   ├── .tmux.conf           # Tmux configuration
│   ├── .bashrc.snippet      # Bash configuration additions
│   ├── .aliases             # Shell aliases
│   ├── claude_settings.json # Claude Teams configuration
│   └── ssh_config           # SSH configuration reference
├── scripts/                  # Utility scripts (optional)
├── .claude/                  # Claude integration (this repository)
└── README.md                # This file
```

## Backups and Safety

### Automatic Backups
All modified files are automatically backed up to:
```
~/.bootstrap-backups/YYYYMMDD_HHMMSS/
```

### Safe Operations
- **Idempotent**: Running multiple times is safe
- **Dry-run**: Test with `--dry-run` before real installation
- **Validation**: Checks existing configurations before modifying
- **Rollback**: Easy rollback using timestamped backups

### Error Handling
- Comprehensive error trapping with line numbers
- Graceful handling of missing dependencies
- Clear error messages and troubleshooting hints
- Non-destructive failures (won't break existing setup)

## Environment Detection

The script automatically detects your environment using these heuristics:

| Environment Type | Detection Method |
|------------------|------------------|
| **VPS** | SSH connection detected (`$SSH_CONNECTION`, `$SSH_CLIENT`) |
| **VPS** | systemd running (Linux server indicator) |
| **Local** | macOS detected (`$OSTYPE` contains "darwin") |
| **Local** | Fallback for unknown environments |

Override detection with `--role local` or `--role vps`.

## Troubleshooting

### Common Issues

**Package installation fails on Ubuntu:**
```bash
# Update package lists manually
sudo apt-get update
# Retry bootstrap
./bootstrap-new.sh --role vps
```

**SSH key already exists:**
```bash
# Force regenerate
./bootstrap-new.sh --only ssh --force --role vps
```

**Permission denied errors:**
```bash
# Ensure user has sudo access
sudo -v
# Run bootstrap as regular user (not root)
./bootstrap-new.sh
```

**Homebrew installation fails on macOS:**
```bash
# Install Homebrew manually first
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Retry bootstrap
./bootstrap-new.sh --role local
```

### Verification

After installation, verify components:

```bash
# Check installed tools
git --version
tmux -V
fzf --version
rg --version
fd --version
bat --version

# Test tmux configuration
tmux new-session -d -s test
tmux kill-session -t test

# Test SSH key
ssh -T git@github.com

# Check Claude integration (local only)
ls -la ~/.claude/settings.json
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on both macOS and Ubuntu if possible
5. Submit a pull request

### Development Guidelines
- Follow existing code style (bash with `set -euo pipefail`)
- Add comprehensive error handling
- Support both dry-run and real execution
- Update documentation for new features
- Test edge cases and error conditions

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Changelog

### Latest Version
- ✅ Added Claude Teams integration for local environments
- ✅ Improved SSH key management with custom naming
- ✅ Enhanced error handling and user feedback
- ✅ Added comprehensive dry-run support
- ✅ Modular architecture with flexible component selection

### Previous Versions
- Initial release with basic package installation
- Added SSH key generation and GitHub integration
- Implemented environment auto-detection
- Added tmux and shell configuration

## Support

For issues and feature requests, please open an issue on GitHub.