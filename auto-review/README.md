# auto-review — 自动审查体系（离线优先）

> 主人专属：代码自动审查 + 每日全量自检 + 技能/文档自动更新。
> **离线优先**：静态扫描纯本地，永不依赖网络/LLM，睡觉断网照跑。

## 包含的脚本

| 脚本 | 作用 | 依赖 |
|------|------|------|
| `auto-review.py` | 静态安全扫描器（密钥/注入/SQL/调试残留） | Python3（无网络） |
| `nightly-auto-review.sh` | 夜间审查：先扫描后3秒网络检测 | curl（可选） |
| `daily-self-audit.sh` | 每日全量自检：代码/技能/MCP/文档/学习/老婆profile | Python3（无网络） |

## 部署（新机器一键）

```bash
# 1. 在 dotfiles 仓库根目录
./configure link          # 部署所有 stow 包（含 auto-review）
./configure doctor        # 验证 symlink

# 2. 安装 pre-commit 钩子到指定项目（可选）
~/.hermes/scripts/install-hooks.sh ~/path/to/project

# 3. 注册 cron 任务（可选，需 Hermes gateway 运行）
hermes cron create --name nightly-code-review \
  --script "nightly-auto-review.sh <项目目录>" \
  --schedule "0 3 * * *"
hermes cron create --name daily-full-self-audit \
  --script "daily-self-audit.sh" --schedule "0 4 * * *"
```

## pre-commit 钩子安装脚本

```bash
#!/bin/bash
# install-hooks.sh <项目目录> — 给项目装 pre-commit 静态扫描钩子
PROJECT="${1:?用法: install-hooks.sh <项目目录>}"
mkdir -p "$PROJECT/.git/hooks"
cat > "$PROJECT/.git/hooks/pre-commit" << 'EOF'
#!/bin/sh
SCANNER="$HOME/.hermes/scripts/auto-review.py"
[ -f "$SCANNER" ] || exit 0
echo "🔍 自动审查中..."
python3 "$SCANNER" "$(git rev-parse --show-toplevel)"
EOF
chmod +x "$PROJECT/.git/hooks/pre-commit"
echo "✅ pre-commit 已安装: $PROJECT"
```

## 配置

- 项目列表在 `daily-self-audit.sh` 顶部 `PROJECTS` 数组（用 `${VAR:-默认}` 间接引用）
- 报告输出：`~/Desktop/审查报告-<date>.md`、`~/Desktop/每日自检-<date>.md`
- 技能地图：`~/.hermes/workspace/技能地图.md`

## 注意事项

- cron 创建有安全 guard（`cron/lifecycle_guard.py`）：脚本内**禁止直接写绝对路径**，
  会被误判为 shell 脚本引用而拦截。用 `${VAR:-默认值}` 间接引用。
- 只扫主人自建代码，第三方 clone（如 dev/dify）不在默认扫描范围。
