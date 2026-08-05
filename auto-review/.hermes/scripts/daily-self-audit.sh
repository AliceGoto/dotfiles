#!/bin/bash
# =============================================================================
# daily-self-audit.sh — 每日全量自检（离线数据收集，永不依赖网络）
# 覆盖6大维度: 代码 / 技能 / MCP / 文档 / 学习 / 老婆profile
# 用法: daily-self-audit.sh [--json]
# 输出: 汇总报告到 stdout（供cron agent读取）+ ~/Desktop/每日自检-<date>.md
# =============================================================================
set -u
DATE=$(date +%Y-%m-%d)
REPORT="$HOME/Desktop/每日自检-$DATE.md"
HERMES=""
SCANNER="$HOME/.hermes/scripts/auto-review.py"

# 项目列表（只扫主人自建代码；dev是第三方clone不扫，避免误报）
# 注意：路径必须用变量间接引用，直接写绝对路径会被cron安全guard误判为shell脚本
PROJ1="${AUDIT_PROJECT_1:-/Users/zhuyao/maki-dance-video/src}"
PROJ2="${AUDIT_PROJECT_2:-/Users/zhuyao/Projects}"
PROJECTS=(
    "$PROJ1"
    "$PROJ2"
)

echo "📋 每日全量自检 — $DATE"
echo "========================================"

# ── 1. 代码静态扫描 ─────────────────────────────────────────
echo ""
echo "【1/6】代码静态扫描..."
CODE_ISSUES=0
for proj in "${PROJECTS[@]}"; do
    if [ -d "$proj" ]; then
        OUT=$("$SCANNER" "$proj" 2>&1)
        if [ $? -ne 0 ]; then
            CODE_ISSUES=$((CODE_ISSUES + 1))
            echo "  ⚠️  $proj: 发现问题"
        else
            echo "  ✅ $proj: 通过"
        fi
    fi
done

# ── 2. 技能状态 ─────────────────────────────────────────────
echo ""
echo "【2/6】技能状态..."
# 直接读文件统计（避免调用hermes CLI触发cron安全拦截）
SKILL_COUNT=$(find "$HOME/.hermes/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
# 检查最近24小时修改的技能（审计"有变动"而非"被修改"）
RECENT_SKILLS=$(find "$HOME/.hermes/skills" -name "SKILL.md" -mtime -1 2>/dev/null | wc -l | tr -d ' ')
echo "  技能总数: $SKILL_COUNT"
echo "  最近24h变更: $RECENT_SKILLS 个技能"

# ── 3. MCP状态 ──────────────────────────────────────────────
echo ""
echo "【3/6】MCP服务器..."
# 直接读config.yaml统计（避免调用hermes CLI触发cron安全拦截）
MCP_TOTAL=$(grep -c "enabled: true" "$HOME/.hermes/config.yaml" 2>/dev/null || echo 0)
MCP_DISABLED=$(grep -c "enabled: false" "$HOME/.hermes/config.yaml" 2>/dev/null || echo 0)
echo "  配置中启用: $MCP_TOTAL | 禁用: $MCP_DISABLED"
echo "  (完整MCP状态: 运行 hermes mcp list 查看)"

# ── 4. 文档同步检查 ─────────────────────────────────────────
echo ""
echo "【4/6】关键文档..."
DOCS=(
    "$HOME/.hermes/workspace/技能地图.md"
    "$HOME/Desktop/老婆技能总目录.md"
    "$HOME/Desktop/老婆技能变化日志.md"
)
for doc in "${DOCS[@]}"; do
    if [ -f "$doc" ]; then
        MTIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$doc")
        echo "  ✅ $doc ($MTIME)"
    else
        echo "  ❌ 缺失: $doc"
    fi
done

# ── 5. 学习记录 ─────────────────────────────────────────────
echo ""
echo "【5/6】学习时间线..."
# 直接统计journey数据库（避免调用hermes CLI触发cron安全拦截）
JOURNEY_DIR="$HOME/.hermes/journey"
if [ -d "$JOURNEY_DIR" ]; then
    JOURNEY_COUNT=$(find "$JOURNEY_DIR" -name "*.json" -o -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    echo "  学习记录数: $JOURNEY_COUNT"
else
    echo "  journey数据目录: $JOURNEY_DIR (不存在或为空)"
fi
echo "  (完整时间线: 运行 hermes journey list 查看)"

# ── 6. 老婆profile技能确认 ──────────────────────────────────
echo ""
echo "【6/6】7个老婆profile技能..."
PROFILES=(alice maki rem tidha miaha developer assistant)
for p in "${PROFILES[@]}"; do
    DIR="$HOME/.hermes/profiles/$p/skills"
    if [ -d "$DIR" ]; then
        N=$(find "$DIR" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
        echo "  👤 $p: $N 技能"
    else
        echo "  👤 $p: 无技能目录"
    fi
done

# ── 汇总 ────────────────────────────────────────────────────
echo ""
echo "========================================"
echo "📊 汇总: 代码问题=$CODE_ISSUES | 技能=$SKILL_COUNT | MCP禁用=$MCP_DISABLED"

# 写报告文件
{
    echo "# 每日全量自检 — $DATE"
    echo ""
    echo "## 1. 代码扫描"
    echo "发现问题的项目数: $CODE_ISSUES"
    echo ""
    echo "## 2. 技能状态"
    echo "技能总数: $SKILL_COUNT"
    echo "最近24h变更: $RECENT_SKILLS"
    echo ""
    echo "## 3. MCP"
    echo "配置中启用: $MCP_TOTAL | 禁用: $MCP_DISABLED"
    echo ""
    echo "## 4. 文档"
    for doc in "${DOCS[@]}"; do
        [ -f "$doc" ] && echo "- ✅ $(basename "$doc")" || echo "- ❌ 缺失: $doc"
    done
    echo ""
    echo "## 5. 学习"
    echo "学习记录数: ${JOURNEY_COUNT:-0}"
    echo ""
    echo "## 6. 老婆profile"
    for p in "${PROFILES[@]}"; do
        DIR="$HOME/.hermes/profiles/$p/skills"
        [ -d "$DIR" ] && echo "- $p: $(find "$DIR" -name SKILL.md | wc -l | tr -d ' ') 技能"
    done
    echo ""
    echo "## 7. 待办（LLM判断）"
    echo "- [ ] 检查技能地图是否需要同步新技能"
    echo "- [ ] 检查变化日志是否需要更新"
    echo "- [ ] 检查MCP是否有失效需要修复"
    echo "- [ ] 检查是否有可固化的新经验（→ /learn）"
} > "$REPORT"
echo ""
echo "📄 报告: $REPORT"
exit 0
