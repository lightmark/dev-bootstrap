# Production-Grade Development Environment Bootstrap

一键搭建现代化开发环境，支持本地和VPS部署。

## 特性

- **一条命令安装**: `curl -sSL https://raw.githubusercontent.com/yourusername/dev-bootstrap/main/bootstrap.sh | bash`
- **幂等性**: 可重复执行，不会破坏现有配置
- **安全**: 自动备份现有文件，默认不覆盖用户配置
- **跨平台**: 支持 Ubuntu 22.04/24.04 和 macOS
- **模块化**: 可选择性安装组件
- **现代工具**: tmux、fzf、ripgrep、fd、bat等

## 快速开始

### 一条命令安装（推荐）

```bash
curl -sSL https://raw.githubusercontent.com/yourusername/dev-bootstrap/main/bootstrap.sh | bash
```

### 本地安装

```bash
git clone https://github.com/yourusername/dev-bootstrap.git
cd dev-bootstrap
./bootstrap.sh
```

## 使用选项

```bash
# 查看帮助
./bootstrap.sh --help

# 预览将要安装的内容（不执行）
./bootstrap.sh --dry-run

# 自动确认所有提示
./bootstrap.sh --yes

# 跳过特定组件
./bootstrap.sh --skip tmux,vim

# 只安装特定组件
./bootstrap.sh --components system,fzf
```

## 组件说明

| 组件 | 描述 | 默认安装 |
|------|------|----------|
| `system` | 基础系统工具（curl、git、build-essential、ripgrep、fd、bat等） | ✅ |
| `tmux` | 终端复用器 + TPM插件管理器 + 现代化配置 | ✅ |
| `fzf` | 模糊查找工具 + 键盘快捷键 + 集成配置 | ✅ |
| `git` | Git配置 + 实用别名 + 全局gitignore | ✅ |
| `ssh` | SSH客户端优化配置（KeepAlive、ControlMaster） | ❌ |
| `vim` | 轻量级Vim配置（无插件管理器） | ❌ |

## 安装的工具

### 系统工具
- **ripgrep** (`rg`) - 快速文本搜索
- **fd** - 快速文件查找
- **bat** - 语法高亮的cat替代品  
- **direnv** - 目录环境变量管理
- **tree** - 目录树显示
- **htop** - 系统监控
- **jq** - JSON处理工具

### 开发工具
- **tmux** - 终端复用器，配置了vi模式、鼠标支持、现代主题
- **fzf** - 模糊查找，集成了Ctrl-T（文件）、Ctrl-R（历史）、Alt-C（目录）
- **git** - 预配置了50+实用别名和安全默认值

## 配置文件位置

安装完成后，配置文件位于：

- `~/.tmux.conf` - tmux配置
- `~/.bashrc` 或 `~/.zshrc` - shell配置（追加内容）
- `~/.gitconfig` - git配置
- `~/.gitignore_global` - 全局gitignore
- `~/backups/` - 原有配置的备份

## 验证安装

安装完成后，验证主要工具：

```bash
# 检查工具版本
tmux -V
fzf --version
rg --version
fd --version
bat --version

# 测试tmux配置
tmux new-session -d -s test
tmux list-sessions
tmux kill-session -t test

# 测试fzf快捷键
# Ctrl-T: 查找文件
# Ctrl-R: 搜索命令历史  
# Alt-C: 切换目录

# 测试git别名
git alias
git lg  # 美化的git log
```

## 自定义配置

### 跳过不需要的组件

```bash
# 只安装基础工具，跳过tmux
./bootstrap.sh --skip tmux

# 只安装系统工具和fzf
./bootstrap.sh --components system,fzf
```

### 修改配置模板

编辑 `configs/` 目录下的模板文件：

- `configs/tmux.conf` - tmux配置模板
- `configs/bashrc.snippet` - bash配置片段
- `configs/vimrc.minimal` - 轻量vim配置

### 添加自定义组件

1. 在 `install/` 目录创建新的安装脚本
2. 在 `bootstrap.sh` 中添加组件到相应列表
3. 确保脚本source了 `install/common.sh`

## 安全说明

- **备份**: 所有被修改的文件都会自动备份到 `backups/` 目录
- **非破坏性**: 默认只追加配置，不覆盖现有内容
- **权限检查**: 拒绝以root用户运行，需要sudo权限时才提示
- **网络安全**: 只从官方源下载，验证校验和

## 故障排除

### 常见问题

1. **Permission denied**: 确保以普通用户运行，不要使用sudo
2. **Command not found**: 重启shell或执行 `source ~/.bashrc`
3. **Tmux插件未安装**: 启动tmux后按 `prefix + I` 安装插件
4. **fzf快捷键不生效**: 确保重新加载shell配置

### 查看日志

```bash
# 查看安装日志
cat bootstrap.log

# 检查备份文件
ls -la backups/
```

### 回滚配置

```bash
# 恢复备份的配置文件
cp backups/bashrc.backup.20240101_120000 ~/.bashrc
cp backups/.tmux.conf.backup.20240101_120000 ~/.tmux.conf
```

## 系统要求

### Ubuntu
- Ubuntu 22.04 LTS 或更新版本
- 具有sudo权限的用户账户
- 网络连接

### macOS  
- macOS 12.0 或更新版本
- 安装了Command Line Tools或Xcode
- 网络连接

## 贡献

欢迎提交Issue和Pull Request！

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件。