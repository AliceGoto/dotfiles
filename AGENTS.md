# Dotfiles — macOS 开发环境配置（GNU Stow）

使用 [GNU Stow](https://www.gnu.org/software/stow/) 管理的全栈 macOS 开发环境配置仓库。所有配置文件以 stow package 形式组织，每个顶级目录对应一个可部署包，相对路径直接镜像到 `$HOME`。统一使用 Tokyo Night Storm 配色方案。仓库内注释与文档均为中文。

## 快速命令（从仓库根目录运行）

| 命令 | 功能 |
|------|------|
| `./configure link` | 部署所有 stow symlink 到 `$HOME` |
| `./configure unlink` | 移除所有 symlink |
| `./configure reinstall` | 重新部署（unlink + link） |
| `./configure doctor` | 检查所有 symlink 健康状态（含源目录断链检测） |
| `./configure list` | 列出所有包及其文件数量 |
| `just lint` | 运行 lint（ruff, stylua, golangci-lint, zsh -n, bash -n） |
| `just fix` | 自动格式化（stylua, ruff, gofumpt, shfmt） |
| `just verify` | **提交前验证**：lint → configure doctor → 控制面 doctor → 配置面审计 → brew bundle check → mise current → docker compose config |
| `just doctor` | 打印系统版本信息（OS/Shell/Node/Python/Go/nvim/mise/Docker） |
| `just update-all` | brew update+upgrade, mise upgrade, uv tool upgrade |
| `just status` | git status + diff 概览 |
| `just c <type> <msg>` | conventional commit（必须先显式暂存，`just c` 是 `just commit` 别名） |
| `just review [dir]` | 对指定项目运行离线静态安全审查 |
| `just self-audit` | 每日全量自检（调用 `~/.hermes/scripts/daily-self-audit.sh`） |
| `just install-hooks <项目目录>` | 给项目装 pre-commit 静态扫描钩子 |
| `just ollama` | 在宿主机启动 ollama 服务 |
| `just pentest-sync` | 将 pentest agents 从 Claude Code 同步到 Codex CLI |
| `./scripts/dotfiles <cmd>` | 系统控制面统一入口（status/inventory/doctor/hermes/config/docs/sync/audit/cleanup） |
| `bash setup-mac.sh` | 全新 Mac 一键安装（幂等可重跑；隐私环节只提示引导，不封装） |

## 技术栈

- **管理工具**：GNU Stow（symlink 部署）
- **任务编排**：[just](https://github.com/casey/just)（`justfile` 中定义所有任务）
- **Shell**：ZSH（Zimfw 模块管理器 + Powerlevel10k 提示符 + fzf/zoxide 增强）
- **编辑器**：Neovim（lazy.nvim 插件管理器，19 个插件模块）
- **运行时**：mise（Node 22.23.0 + Python 3.12.13），Go 由 Homebrew 管理
- **包管理**：Homebrew（formulae + casks），Python 项目使用 uv，Node 全局工具用 corepack/uv tool
- **容器**：OrbStack + Docker Compose（Qdrant 默认向量库 + LiteLLM 可选 profile）
- **AI 辅助**：Claude Code（OMC 编排层）/ OpenCode / Codex CLI 三工具协同
- **系统代理**：Go 编写的 `prox` CLI（cobra 框架）
- **审查体系**：`auto-review` 离线静态扫描 + 每日自检（纯本地，不依赖网络/LLM）

## 项目结构

### 包管理入口

| 文件 | 功能 |
|------|------|
| `configure` | Stow 部署脚本（PACKAGES 数组定义 24 个包） |
| `justfile` | 所有任务编排入口 |
| `.gitignore` | 全局忽略规则：AGENTS.md（需 `git add -f` 跟踪）、.env、凭证、运行时状态 |
| `README.md` | 面向人类的项目说明（目录结构、插件、快捷键） |
| `CONFIG_MAP.md` | 家目录配置一站式索引（配置面地图） |
| `arch-setup.sh` | Arch Linux (ARM/OrbStack) 部署脚本（实验性） |
| `claude-settings.json` | Claude Code 配置模板（Zen Proxy + 免费模型） |

### Shell 环境

| 包 | 部署路径 | 功能 |
|----|----------|------|
| `zsh/` | `~/.zshenv`, `~/.zprofile`, `~/.zshrc`, `~/.zsh/` | ZSH 三层入口 + 4 个交互模块（aliases, aliases-dev, functions, integrations） |
| `zim/` | `~/.zimrc` | Zimfw 模块清单 |
| `p10k/` | `~/.p10k.zsh` | Powerlevel10k Pure 风格提示符，transient + instant prompt |

### 版本控制与包管理

| 包 | 部署路径 | 功能 |
|----|----------|------|
| `git/` | `~/.gitconfig`, `~/.gitignore_global` | 全局 Git 配置：delta diff（TokyoNight 主题）、SSH insteadOf 别名、histogram 算法、zdiff3 冲突样式 |
| `npm/` | `~/.npmrc` | npm 镜像源配置 |
| `pip/` | `~/.config/pip/pip.conf` | pip 清华镜像源 |
| `brew/` | `~/.Brewfile` | 声明式 Homebrew 包清单（formulae + casks，目前 1 个 cask：ghostty） |
| `mise/` | `~/.config/mise/config.toml` | 运行时版本（Node 22.23.0 + Python 3.12.13） |

### 终端工具

| 包 | 部署路径 | 功能 |
|----|----------|------|
| `ghostty/` | `~/.config/ghostty/config` | GPU 加速终端，macOS 毛玻璃，Maple Mono NF 14pt |
| `zellij/` | `~/.config/zellij/config.kdl` | 终端复用器（原生模式，鼠标支持） |
| `yazi/` | `~/.config/yazi/yazi.toml` | 终端文件管理器（Vim 键位） |
| `btop/` | `~/.config/btop/btop.conf` | 系统监控（CPU/内存/磁盘/GPU） |
| `fastfetch/` | `~/.config/fastfetch/config.jsonc` | 系统信息 |
| `lazygit/` | `~/.config/lazygit/config.yml` | Git TUI（Tokyo Night 主题） |

### 编辑器

| 包 | 部署路径 | 功能 |
|----|----------|------|
| `nvim/` | `~/.config/nvim/` | Neovim IDE（lazy.nvim，19 个插件模块文件） |

nvim 目录结构：
- `init.lua` — 入口：引导 lazy.nvim、加载核心配置和插件
- `lua/core/{options,keymaps,git,fm,runner}.lua` — 核心选项、全局快捷键（唯一入口）、Git/文件管理/运行
- `lua/plugins/init.lua` — lazy.nvim 自动发现入口；其余 18 个 `*.lua` 每文件一组插件（ai, cursor, debug, explorer, format, git, im-select, lsp, markdown, mini, misc, neotest, snacks, theme, tools, trouble, treesitter, ui）
- `lua/configs/{dashboard,icons}.lua` — 模块配置
- `lazy-lock.json` — 插件版本锁文件，**禁止手动编辑**
- 支持 LSP：bashls / gopls / lua_ls / pyright / ruff / ts_ls；Neovim >= 0.11 要求

### AI 工具

| 包 | 部署路径 | 功能 |
|----|----------|------|
| `claude/` | `~/.claude/` | Claude Code 配置（CLAUDE.md、rules/30、skills/49、agents/70、hooks、hud） |
| `opencode/` | `~/.config/opencode/` | OpenCode 配置（模型路由、MCP、插件、权限） |
| `codex/` | `codex/scripts/` | Codex CLI 工具脚本（pentest agent 转换器） |

### 容器与 AI 服务

| 包 | 文件 | 功能 |
|----|------|------|
| `docker/` | `docker-compose-ai.yml`, `litellm_config.yaml` | Qdrant 默认向量库（`127.0.0.1:6333/6334`）+ LiteLLM（`llm` profile，`127.0.0.1:4000`） |

前置条件：OrbStack 运行中，`docker context show` 返回 `orbstack`。
- 启动 Qdrant：`docker compose -f docker/docker-compose-ai.yml up -d`
- 启用 LiteLLM：加 `--profile llm`
- Ollama 由 `just ollama` 在宿主机直接运行，不在容器内

### 系统控制面（非 stow 包，仓库内脚本）

| 文件 | 功能 |
|---------|------|
| `scripts/dotfiles` | 统一 CLI 入口（status/inventory/doctor/hermes/config/docs/sync/audit/cleanup，inventory 状态输出到 `$XDG_STATE_HOME/dotfiles`） |
| `scripts/config-audit` | 配置面审计（managed/runtime/legacy 三类配置路径） |
| `scripts/hermes-audit` | Hermes Studio profile 审计（`HERMES_AUDIT_STRICT=1` 时内联密钥等失败即报错） |
| `scripts/system-inventory` | 脱敏系统清单生成 |
| `scripts/sync-obsidian` | 仅生成 Obsidian 系统页面，不复制原始配置 |
| `manifests/` | 软件治理清单（`software.tsv`, `ai-profiles.tsv`, `config-surface.tsv`, `README.md`） |
| `local-bin/` | `~/.local/bin/{dotfiles,excalidraw-mcp,dev}` 兼容入口 |

### 其他工具

| 包 | 部署路径 | 功能 |
|----|----------|------|
| `gh/` | `~/.config/gh/config.yml` | GitHub CLI 配置（SSH 协议；`hosts.yml` 机器相关，gitignored） |
| `prox/` | `~/.local/bin/prox` | Go/cobra 编写的系统代理 CLI（预设端口 7892/7897/1080/3128/8080，`eval "$(prox on)"` 生效） |
| `pentest/` | `~/.local/bin/omni-pentest` | 渗透测试编排入口（Claude Code + OpenCode/OMC + Codex CLI 三工具联动，约 50 个 pentest agent） |
| `auto-review/` | `~/.hermes/scripts/` | 离线代码审查（`auto-review.py`）+ 夜间审查 + 每日自检（`daily-self-audit.sh`）+ pre-commit 钩子安装脚本 |

### 作为独立项目的子目录

以下目录是该用户的独立项目，**不属于 dotfiles 配置管理范畴**（不在 PACKAGES 数组，勿用 configure 部署）：

- `LingChat/` — Vue 3 + Tauri AI 聊天应用
- `NotitleCode/` — React + TypeScript AI 编码助手
- `Document/` — 知识文档与子智能体教程
- `list/` — Python 虚拟环境目录（本地使用）

## 架构约定

### Stow 路径映射

每个 stow 包内的相对路径直接映射到 `$HOME`。例如：
- `git/.gitconfig` → `~/.gitconfig`
- `nvim/.config/nvim/` → `~/.config/nvim/`
- `ghostty/.config/ghostty/config` → `~/.config/ghostty/config`

**永远不要嵌套额外目录层级。**

### configure 的忽略规则

`configure` 的 STOW_ARGS 不部署以下文件：
- 所有 `AGENTS.md`（`--ignore='(^|/)AGENTS\.md$'`）
- `claude/.claude/CLAUDE.md` 与 `settings.json`（OMC 生成物，保持本地）
- `claude/.claude/hud/cache/`
- `opencode/.claude.json`（运行时状态）
- `opencode/.config/opencode/oh-my-openagent.json`

### 包依赖关系

```
zsh/ → p10k/, zim/, git/
nvim/ → git/, mise/（LSP 运行时）
opencode/ → claude/（OMC 规则、技能、agents）
docker/ → brew/（工具安装来源）
gh/ → git/（SSH 协议一致）
auto-review/ → 无（纯本地 python3，零外部依赖）
```

### Shell 加载顺序（zsh/）

| 文件 | 作用域 | 触发时机 |
|------|--------|----------|
| `.zshenv` | 所有 Shell（含脚本） | 每次 Shell 启动（保持轻量，不访问 Keychain） |
| `.zprofile` | 登录 Shell | 终端登录（Homebrew 镜像源 + shellenv） |
| `.zshrc` + `.zsh/` | 交互式 Shell | 终端打开（加载顺序在 `.zshrc` 内显式 source，不用数字文件名控制） |

API 密钥由 `load-keychain` 在 `functions.zsh` 中按需懒加载。`claude`、`opencode`、`zen-proxy` 命令会自动调用。

### 代码风格

| 语言 | 格式化工具 | 规则 |
|------|-----------|------|
| Shell | shfmt（`just fix`） | 4 空格缩进，必须通过 `bash -n` / `zsh -n` 语法检查 |
| Lua | StyLua | `just fix` 自动格式化（`nvim/.config/nvim/stylua.toml`） |
| Python | Ruff | `just lint` + `just fix` |
| Go | gofumpt | `just fix` 自动格式化 |

### 提交规范

- 使用 Conventional Commits：`chore:`、`fix:`、`refactor:`、`feat:` 等
- 必须先显式 `git add` 暂存文件，再执行 `just c <type> <msg>`（否则 `just c` 报错退出）
- 禁止 direct-push main、force-push、amend-pushed（`git push --force` 在 OpenCode 权限配置中也默认拒绝）
- 提交前运行 `just verify` 执行完整验证
- **`AGENTS.md` 被 `.gitignore` 忽略，修改后必须 `git add -f AGENTS.md` 才能跟踪**

### 安全检查

- `.env`、凭证、token、私钥等敏感文件从不提交（`.gitignore` 覆盖 `**/.env*`、`auth.json`、`*.key`、`*.pem` 等）
- `Hosts.yml` 等机器相关凭证文件 gitignored，不入库
- Docker 服务端口仅绑定本机回环地址（`127.0.0.1`）
- 系统控制面脚本只做审计/生成，`cleanup` 为 dry-run，不直接删除
- API 密钥保存在 macOS Keychain，由 `load-keychain` 懒加载，不进配置文件

### OpenCode 运行时注意事项（opencode.jsonc）

- `formatter: false` 和 `lsp: false` — 不要假设 LSP/工具可用
- 默认模型：`zen-proxy/deepseek-v4-flash-free`（本地 Zen Proxy 127.0.0.1:8123）
- MCP 已启用：GitHub、filesystem（限定到 dotfiles 目录）、Context7、excalidraw、Cloudflare 远程服务族（mcp/docs/bindings/builds/observability）
- MCP 未启用：sequential-thinking、playwright、postgres
- 权限默认 `ask`，敏感命令（rm -rf, sudo, chmod 777, git push --force 等）拒绝
- 插件：`oh-my-openagent`（OMC 编排）、`@oh-my-kiro/oh-my-kiro`
- 输出截断：`tool_output.max_lines: 200`、`max_bytes: 8192`，`compaction.tail_turns: 15`

### Claude Code（claude/）

- `.claude/CLAUDE.md` — OMC（oh-my-claudecode v4.15.2）多智能体编排层系统提示词；修改它会影响所有 Agent 行为
- `rules/` — 30 个按路径匹配的规则文件（含 validate-rules.sh）
- `skills/` — 49 个 OMC 技能（`/oh-my-claudecode:<name>` 调用：autopilot, ultrawork, ralph, team, ralplan 等）
- `agents/` — 70 个子智能体定义（其中约 50 个为 pentest agent）
- 非便携运行时文件（cache/sessions/telemetry/plugins/`~/.claude.json`）未纳入 stow

## 测试与验证

- **symlink 健康检查**：`./configure doctor`（检测 `$HOME` 断链 + 源目录断链 + stow 模拟部署冲突）
- **完整验证**：`just verify`（lint + configure doctor + scripts/dotfiles doctor + 配置面审计 + brew + mise + docker compose）
- **brew 验证**：`brew bundle check --no-upgrade --file brew/.Brewfile`
- **mise 验证**：`mise current`
- **Docker Compose 验证**：`OPENROUTER_API_KEY=validation-only docker compose -f docker/docker-compose-ai.yml config --quiet`
- **Shell 语法**：`zsh -n`（入口文件 + 所有模块）、`bash -n`（控制面脚本）

## 新软件接入流程

1. 先加入 `manifests/software.tsv`，状态设为 `review`（写清来源、命令、配置路径和回滚方式）
2. 有持久配置时创建对应 stow 包（**不要手工复制文件到 `$HOME`**），运行 `./configure link`
3. 运行 `dotfiles config`、`dotfiles doctor`、`dotfiles docs` 确认状态
4. 验证完成后才改为 `active`
5. Python 项目依赖使用 `uv add` 并提交 uv.lock；全局 CLI 用 `uv tool install`，不要把全局 `pip freeze` 当系统配置

## 快速参考

```bash
# 想知道某个配置在哪？
ls -la ~/dotfiles/<包名>/

# 搜索配置内容
rg "关键字" ~/dotfiles/

# 查看已部署的 symlink
./configure doctor

# 包文件清单
./configure list

# 配置面完整地图
cat CONFIG_MAP.md
```

## 详细文档

每个 stow 包目录下都有 `AGENTS.md` 提供更具体的说明（仓库各层级的 AGENTS.md 是分层组织的，子目录的更具体说明优先级更高）。关键入口：

| 包 | 最佳入口 |
|----|---------|
| `git/AGENTS.md` | Git 配置细节、别名、SSH 映射 |
| `nvim/AGENTS.md` | 插件架构、init.lua、快捷键体系（含 `nvim/.config/nvim/lua/*/AGENTS.md`） |
| `opencode/AGENTS.md` | 模型路由、MCP 服务器、代理配置 |
| `docker/AGENTS.md` | AI 服务栈、Docker Compose profile |
| `zsh/AGENTS.md` | Shell 初始化流程、模块加载顺序 |
| `claude/AGENTS.md` | OMC 规则、技能、智能体、Hooks |
| `prox/AGENTS.md` | 系统代理 CLI 命令和设计 |
| `pentest/AGENTS.md` | 渗透测试三工具联动模式、agent 分类 |
| `auto-review/README.md` | 自动审查体系脚本说明与部署 |
| `manifests/README.md` | 软件治理清单规则 |
| `scripts/README.md` | 系统控制面 CLI 命令说明 |