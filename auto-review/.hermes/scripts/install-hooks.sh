#!/bin/bash
# =============================================================================
# install-hooks.sh — 给任意项目安装 pre-commit 静态安全扫描钩子
# 用法: install-hooks.sh <项目目录> [更多项目目录...]
# 效果: 每次 git commit 自动跑 auto-review.py，发现问题阻止提交
#       （确认可绕过: git commit --no-verify）
# =============================================================================
set -u

if [ "$#" -lt 1 ]; then
    echo "用法: install-hooks.sh <项目目录> [更多项目目录...]"
    echo "示例: install-hooks.sh ~/maki-dance-video ~/my-server"
    exit 1
fi

SCANNER="$HOME/.hermes/scripts/auto-review.py"
if [ ! -f "$SCANNER" ]; then
    echo "❌ 找不到扫描器: $SCANNER"
    echo "   请先部署 auto-review 包: cd ~/dotfiles && ./configure link"
    exit 1
fi

for project in "$@"; do
    project="${project%/}"
    if [ ! -d "$project/.git" ]; then
        echo "⚠️  跳过（非git仓库）: $project"
        continue
    fi
    hooks_dir="$project/.git/hooks"
    mkdir -p "$hooks_dir"
    cat > "$hooks_dir/pre-commit" << 'EOF'
#!/bin/sh
# auto-review pre-commit hook — 离线静态安全扫描
SCANNER="$HOME/.hermes/scripts/auto-review.py"
PROJECT="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
if [ ! -f "$SCANNER" ]; then
    echo "⚠️  auto-review.py 不存在，跳过审查"
    exit 0
fi
echo "🔍 自动审查中..."
python3 "$SCANNER" "$PROJECT"
exit $?
EOF
    chmod +x "$hooks_dir/pre-commit"
    echo "✅ pre-commit 已安装: $project"
done
echo ""
echo "测试: 在项目内 git commit 即可看到审查输出"
