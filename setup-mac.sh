#!/bin/bash
# ==============================================================================
#  setup-mac.sh — macOS 全新机器一键安装脚本（幂等，可反复重跑）
#  用法: bash setup-mac.sh [--force] [--dry-run] [--yes]
#
#  参数:
#    --force    跳过"已存在"检查，强制重装/更新
#               （uv tool install --force、mise install --force、git pull 更新 ~/dotfiles 等）
#    --dry-run  只打印将要执行的命令，不执行任何修改（零副作用）
#    --yes      全程自动确认，不询问
#    -h, --help 显示帮助
#
#  运行前提: 必须在 dotfiles 仓库根目录运行（脚本需读取 brew/.Brewfile、
#            mise/.config/mise/config.toml 等清单文件）；尚未克隆时请先:
#            git clone https://github.com/1764712542/dotfiles.git ~/dotfiles
#            cd ~/dotfiles && bash setup-mac.sh
#
#  阶段划分 (9 阶段):
#    前置检查  macOS / Apple Silicon (arm64) / Command Line Tools / 网络连通
#    [1/9] Homebrew 安装（官方 NONINTERACTIVE=1 脚本）并加载 shellenv
#    [2/9] brew bundle --file brew/.Brewfile（幂等，已装包自动跳过）
#    [3/9] mise install（按 mise/.config/mise/config.toml 锁定 Node 22.23.0 + Python 3.12.13）
#    [4/9] uv 安装 + uv tool install（aider-chat / huggingface-hub / jupyterlab /
#          mcp-server-qdrant / nano-pdf，已装则跳过）
#    [5/9] 部署 dotfiles（复用或克隆 ~/dotfiles，然后 ./configure link 部署 stow symlink）
#    [6/9] zimfw install（Zim 模块）
#    [7/9] nvim --headless "+Lazy! sync" +qa（300s 超时，失败仅警告不致命）
#    [8/9] 验证: ./configure doctor + scripts/dotfiles doctor
#    [9/9] 输出手动配置清单（gh auth login / Keychain API 密钥 / claude login /
#          docker compose up 启动 Qdrant / 可选 just ollama）
#
#  隐私边界（脚本承诺）:
#    - 不写入、不读取任何 API 密钥 / token / 私钥；密钥仅由用户手动放入
#      macOS Keychain（load-keychain 按需懒加载），脚本只做提示引导；
#    - 不触碰 gh/.config/gh/hosts.yml、opencode/.claude.json、
#      claude/.claude/CLAUDE.md 与 claude/.claude/settings.json（OMC/机器相关生成物，
#      且 configure 的 STOW_ARGS 已显式忽略这些文件，./configure link 不会部署它们）；
#    - 只读取 brew/.Brewfile、mise/.config/mise/config.toml 等清单，不修改；
#    - 写入痕迹仅限 /tmp 临时文件（nvim 同步日志），结束即删除。
# ==============================================================================

set -euo pipefail

# ---- 全局状态与日志封装 -----------------------------------------------------

STAGE=0
DOTFILES_DIR=""
PHASE_LABEL="前置检查"

step() {
    STAGE=$((STAGE + 1))
    PHASE_LABEL="阶段 $STAGE/9"
    echo ""
    echo "================ [阶段 $STAGE/9] $* ================"
}

info()  { echo "  [$PHASE_LABEL] info:  $*"; }
ok()    { echo "  [$PHASE_LABEL] ok:    $*"; }
warn()  { echo "  [$PHASE_LABEL] warn:  $*"; }
dry()   { echo "  [$PHASE_LABEL] dry:   $*"; }
fail()  { echo "  [$PHASE_LABEL] fail:  $*" >&2; exit 1; }

require() {
    local cmd="$1"
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi
    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry "require: 执行时将检测命令 $cmd"
        return 0
    fi
    fail "缺少必要命令: $cmd"
}

usage() {
    cat <<'EOF'
用法: bash setup-mac.sh [--force] [--dry-run] [--yes]

  --force    跳过"已存在"检查，强制重装/更新
  --dry-run  只打印将要执行的命令，不执行任何修改
  --yes      全程自动确认，不询问
  -h, --help 显示本帮助
EOF
}

# ---- 参数解析 ---------------------------------------------------------------

FORCE=0
DRY_RUN=0
ASSUME_YES=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)   FORCE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --yes|-y)  ASSUME_YES=1 ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "未知参数: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

# ---- 定位 dotfiles 仓库 -----------------------------------------------------

resolve_dotfiles_dir() {
    local cand
    cand="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$cand/brew/.Brewfile" ]]; then
        DOTFILES_DIR="$cand"
    elif [[ -f "$HOME/dotfiles/brew/.Brewfile" ]]; then
        DOTFILES_DIR="$HOME/dotfiles"
    else
        fail "未找到 dotfiles 仓库（需要 brew/.Brewfile）。请先克隆: git clone https://github.com/1764712542/dotfiles.git ~/dotfiles && cd ~/dotfiles && bash setup-mac.sh"
    fi
    info "dotfiles 仓库: $DOTFILES_DIR"
}

# ---- 前置检查（阶段 0）-----------------------------------------------------

precheck() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"

    info "系统平台: $os / $arch"
    if [[ "$os" != "Darwin" ]]; then
        fail "本脚本仅支持 macOS（当前 ${os}），Abort"
    fi
    ok "macOS 确认"

    if [[ "$arch" != "arm64" ]]; then
        fail "本脚本仅支持 Apple Silicon (arm64，当前 $arch)。Intel / 其它架构请另用手动流程"
    fi
    ok "Apple Silicon (arm64) 确认"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry "检查 Command Line Tools: xcode-select -p"
        dry "检查网络连通: curl -fsSIL --max-time 10 https://raw.githubusercontent.com"
        return 0
    fi

    if xcode-select -p >/dev/null 2>&1; then
        ok "Command Line Tools 已安装: $(xcode-select -p)"
    else
        warn "未检测到 Command Line Tools"
        info "请先手动安装（弹窗点安装或执行）: xcode-select --install"
        fail "必须安装 Command Line Tools 后才能继续"
    fi

    if curl -fsSIL --max-time 10 https://raw.githubusercontent.com >/dev/null 2>&1; then
        ok "网络连通正常 (raw.githubusercontent.com)"
    else
        fail "网络不可达，请检查网络/代理后重试"
    fi
}

# ---- 交互确认 ---------------------------------------------------------------

confirm() {
    local ans
    if [[ "$DRY_RUN" -eq 1 || "$ASSUME_YES" -eq 1 ]]; then
        return 0
    fi
    echo ""
    read -r -p "  [确认] 本脚本将安装 Homebrew / mise / uv / nvim 插件并部署 dotfiles，继续? [y/N] " ans
    case "$ans" in
        y|Y) ;;
        *) info "已取消（可加 --yes 跳过确认）"; exit 0 ;;
    esac
}

# ---- [1/9] Homebrew ---------------------------------------------------------

phase1_homebrew() {
    step "Homebrew 安装"
    local installer
    if [[ "$DRY_RUN" -eq 1 ]]; then
        if command -v brew >/dev/null 2>&1; then
            dry "Homebrew 已存在，跳过安装"
        else
            dry '安装 Homebrew: NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        fi
        dry '加载 Homebrew 环境: eval "$(/opt/homebrew/bin/brew shellenv)"'
        return 0
    fi

    if command -v brew >/dev/null 2>&1; then
        ok "Homebrew 已存在: $(brew --version | head -n1)"
    else
        info "开始安装 Homebrew（官方非交互安装脚本，可能需要数分钟）..."
        installer="$(mktemp /tmp/homebrew-install.XXXXXX)"
        if ! curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"; then
            rm -f "$installer"
            fail "下载 Homebrew 安装脚本失败，请检查网络后重试"
        fi
        NONINTERACTIVE=1 /bin/bash "$installer"
        rm -f "$installer"
        ok "Homebrew 安装完成"
    fi

    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    else
        fail "找不到 brew 可执行文件，Homebrew 安装可能失败"
    fi
    ok "Homebrew 环境已加载: $(command -v brew)"
}

# ---- [2/9] brew bundle ------------------------------------------------------

phase2_bundle() {
    step "Homebrew Bundle（brew/.Brewfile）"
    local brewfile="$DOTFILES_DIR/brew/.Brewfile"
    if [[ ! -f "$brewfile" ]]; then
        fail "缺少清单文件: ${brewfile}（请从 dotfiles 仓库根目录运行本脚本）"
    fi
    info "清单: ${brewfile}（脚本运行时实时读取，Brewfile 的增补自动生效；本脚本不修改它）"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry "brew bundle --file $brewfile"
        dry "说明: 幂等安装，已装包自动跳过；需要清理清单外包时可手动加 --cleanup"
        return 0
    fi
    if brew bundle --file "$brewfile"; then
        ok "brew bundle 完成"
    else
        fail "brew bundle 失败（部分包未能安装，可修复后重新运行本脚本）"
    fi
}

# ---- [3/9] mise -------------------------------------------------------------

phase3_mise() {
    step "mise 运行时安装（Node 22.23.0 + Python 3.12.13）"
    local cfg="$DOTFILES_DIR/mise/.config/mise/config.toml"
    local -a args=()
    local node_ver py_ver

    if [[ "$DRY_RUN" -eq 1 ]]; then
        require "mise"
        dry "解析 $cfg 中锁定版本并执行: mise install node@<version> python@<version>"
        return 0
    fi

    require "mise"
    if [[ -f "$cfg" ]]; then
        node_ver="$(sed -n 's/^node[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$cfg" | head -n1)"
        py_ver="$(sed -n 's/^python[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$cfg" | head -n1)"
        [[ -n "$node_ver" ]] && args+=("node@$node_ver")
        [[ -n "$py_ver" ]] && args+=("python@$py_ver")
        info "版本来自 config.toml: ${args[*]:-（未解析到版本行）}"
    else
        warn "缺少 config.toml: $cfg"
    fi

    if [[ "${#args[@]}" -eq 0 ]]; then
        warn "未解析到锁定版本，执行裸 mise install（可能无操作）"
        mise install
    elif [[ "$FORCE" -eq 1 ]]; then
        info "强制模式: mise install --force ${args[*]}"
        mise install --force "${args[@]}"
    else
        info "执行: mise install ${args[*]}"
        mise install "${args[@]}"
    fi
    ok "mise install 完成"
}

# ---- [4/9] uv 与 Python CLI -------------------------------------------------

phase4_uv() {
    step "uv 与 Python CLI 工具"
    local -a uv_tools=(aider-chat huggingface-hub jupyterlab mcp-server-qdrant nano-pdf)
    local tool uv_installer force_note
    if [[ "$FORCE" -eq 1 ]]; then
        force_note="--force 强制重装"
    else
        force_note="已安装则跳过"
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        if command -v uv >/dev/null 2>&1; then
            dry "uv 已存在: $(command -v uv)"
        else
            dry '安装 uv（下载官方脚本到临时文件后执行）: https://astral.sh/uv/install.sh'
            dry 'export PATH="$HOME/.local/bin:$PATH"'
        fi
        for tool in "${uv_tools[@]}"; do
            dry "uv tool install ${tool}（${force_note}）"
        done
        return 0
    fi

    if command -v uv >/dev/null 2>&1; then
        ok "uv 已存在: $(uv --version 2>/dev/null)"
    else
        info "安装 uv（官方安装脚本）..."
        uv_installer="$(mktemp /tmp/uv-install.XXXXXX)"
        if ! curl -LsSf https://astral.sh/uv/install.sh -o "$uv_installer"; then
            rm -f "$uv_installer"
            fail "下载 uv 安装脚本失败"
        fi
        bash "$uv_installer"
        rm -f "$uv_installer"
        export PATH="$HOME/.local/bin:$PATH"
        ok "uv 安装完成: $(uv --version 2>/dev/null)"
    fi

    for tool in "${uv_tools[@]}"; do
        if [[ "$FORCE" -eq 1 ]]; then
            info "强制重装: $tool"
            uv tool install --force "$tool" || warn "uv tool install $tool 失败（非致命）"
        elif [[ -d "$(uv tool dir)/$tool" ]]; then
            ok "已安装，跳过: $tool"
        else
            info "安装: $tool"
            uv tool install "$tool" || warn "uv tool install $tool 失败（非致命）"
        fi
    done
    ok "uv 工具就绪"
}

# ---- [5/9] 部署 dotfiles ----------------------------------------------------

phase5_dotfiles() {
    step "部署 dotfiles（clone + stow link）"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        if [[ -d "$HOME/dotfiles" ]]; then
            dry "复用已存在的 ~/dotfiles（--force 时额外执行 git pull --ff-only 更新）"
        else
            dry "git clone https://github.com/1764712542/dotfiles.git $HOME/dotfiles"
            dry "DOTFILES_DIR=\$HOME/dotfiles"
        fi
        dry "$DOTFILES_DIR/configure link"
        return 0
    fi

    if [[ -d "$HOME/dotfiles" ]]; then
        ok "复用 ~/dotfiles"
        if [[ "$FORCE" -eq 1 ]]; then
            info "git pull --ff-only 更新仓库 ..."
            (cd "$HOME/dotfiles" && git pull --ff-only)
        fi
    else
        info "克隆 dotfiles 仓库 ..."
        if ! git clone https://github.com/1764712542/dotfiles.git "$HOME/dotfiles"; then
            fail "克隆失败，请检查网络与仓库访问权限"
        fi
        ok "克隆完成: $HOME/dotfiles"
        DOTFILES_DIR="$HOME/dotfiles"
    fi

    require "stow"
    info "运行 ./configure link（stow 部署 symlink）..."
    if (cd "$DOTFILES_DIR" && ./configure link); then
        ok "dotfiles 部署完成"
    else
        fail "./configure link 失败（可能存在文件冲突或不存在的包），请修复后重跑"
    fi
}

# ---- [6/9] Zim (zimfw) ------------------------------------------------------

phase6_zim() {
    step "Zim (zimfw) 模块安装"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry "zimfw install（按 ~/.zimrc 模块清单初始化 ~/.zim）"
        return 0
    fi
    if command -v zimfw >/dev/null 2>&1; then
        if zimfw install; then
            ok "zimfw install 完成"
        else
            fail "zimfw install 失败"
        fi
    elif [[ -s "$HOME/.zim/init.zsh" ]]; then
        ok "检测到已初始化的 ~/.zim/init.zsh，跳过"
    else
        warn "zimfw 命令不可用，跳过本阶段（可稍后手动执行: zimfw install）"
    fi
}

# ---- [7/9] Neovim 插件 ------------------------------------------------------

phase7_nvim() {
    step "Neovim 插件安装（Lazy.nvim）"
    local log_file="/tmp/setup-mac-nvim-lazy.log"
    local pid waited rc=0
    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry 'nvim --headless "+Lazy! sync" +qa（最多等待 300 秒，失败仅警告不致命）'
        return 0
    fi
    require "nvim"
    info "同步 Lazy 插件（最多 300 秒）..."
    nvim --headless "+Lazy! sync" +qa >"$log_file" 2>&1 &
    pid=$!
    waited=0
    while kill -0 "$pid" 2>/dev/null && (( waited < 300 )); do
        sleep 5
        waited=$((waited + 5))
    done
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        rm -f "$log_file"
        warn "nvim 插件同步超时（300s），已终止。可稍后重试: nvim --headless \"+Lazy! sync\" +qa"
        return 0
    fi
    wait "$pid" || rc=$?
    if [[ "$rc" -eq 0 ]] && [[ -s "$log_file" ]]; then
        tail -n5 "$log_file" | sed 's/^/  /'
    fi
    rm -f "$log_file"
    if [[ "$rc" -eq 0 ]]; then
        ok "nvim 插件同步完成"
    else
        warn "nvim 插件同步退出码 ${rc}（非致命，可稍后重试）"
    fi
}

# ---- [8/9] 验证 -------------------------------------------------------------

phase8_verify() {
    step "验证（configure doctor + dotfiles doctor）"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry "cd $DOTFILES_DIR && ./configure doctor"
        dry "cd $DOTFILES_DIR && scripts/dotfiles doctor（含 OrbStack/Docker/Compose/mise/hermes 检查）"
        return 0
    fi
    if (cd "$DOTFILES_DIR" && ./configure doctor); then
        ok "configure doctor 通过"
    else
        fail "configure doctor 检测到异常，请修复后重新运行本脚本"
    fi
    if (cd "$DOTFILES_DIR" && scripts/dotfiles doctor); then
        ok "scripts/dotfiles doctor 通过"
    else
        warn "scripts/dotfiles doctor 报错（新机器上 hermes/mise 等可能尚未配置，属预期，可稍后运行 dotfiles doctor 复查）"
    fi
}

# ---- [9/9] 手动配置清单 -----------------------------------------------------

phase9_manual() {
    step "手动配置清单"
    cat <<'EOF'

  以下事项涉及认证与密钥，脚本不会代为完成（隐私边界）:

  [1] GitHub 认证
      gh auth login          # 选择 SSH 协议

  [2] API 密钥写入 macOS Keychain（load-keychain 按需懒加载，绝不写入配置文件）
      示例:
        security add-generic-password -s OPENROUTER_API_KEY -w '你的密钥' -U
      脚本懒加载读取的密钥名:
        OPENROUTER_API_KEY  CLOUDFLARE_AI_TOKEN  ZEN_API_KEY_1  ZEN_API_KEY_2
        DEEPSEEK_API_KEY    AGNES_API_KEY        FOX_API_KEY    ANTHROPIC_AUTH_TOKEN
        SHAREDCHAT_API_KEY  CLOUD_AI_API_KEY     OPENCODE_GO_API_KEY  ASL_API_KEY

  [3] Claude Code 认证
      claude login

  [4] OpenRouter / 代理密钥
      务必先添加 OPENROUTER_API_KEY（docker/litellm 配置引用）再启动容器服务

  [5] Docker 服务（Qdrant 默认向量库，LiteLLM 可选）
      启动 OrbStack 后执行:
        docker compose -f docker/docker-compose-ai.yml up -d                # Qdrant
        docker compose -f docker/docker-compose-ai.yml up -d --profile llm  # + LiteLLM

  [6] 可选: 本地模型服务
      just ollama

  [7] 通用
      切换默认 shell:  chsh -s "$(command -v zsh)"
      重开终端:        exec zsh
EOF
}

# ---- 汇总 ---------------------------------------------------------------

summary() {
    echo ""
    echo "================================================================"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  dry-run 结束：以上为将要执行的命令，未对系统做任何修改"
    else
        echo "  setup-mac.sh 完成（全流程幂等，中途失败可直接重跑）"
    fi
    echo "================================================================"
}

main() {
    resolve_dotfiles_dir
    precheck
    confirm
    phase1_homebrew
    phase2_bundle
    phase3_mise
    phase4_uv
    phase5_dotfiles
    phase6_zim
    phase7_nvim
    phase8_verify
    phase9_manual
    summary
}

main