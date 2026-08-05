#!/bin/bash
# =============================================================================
# nightly-auto-review.sh — 夜间自动审查（离线优先）
# 1. 纯本地静态扫描（永不依赖网络）→ 生成报告
# 2. 检测网络：有网则追加LLM深度审查提示，无网则仅静态报告
# 用法: nightly-auto-review.sh <项目目录>
# =============================================================================
set -u
PROJECT="${1:?用法: nightly-auto-review.sh <项目目录>}"
SCANNER="$HOME/.hermes/scripts/auto-review.py"
DATE=$(date +%Y-%m-%d)
REPORT="$HOME/Desktop/审查报告-$DATE.md"

echo "🌙 夜间自动审查 — $DATE"
echo "项目: $PROJECT"

# ── 1. 离线静态扫描（永远执行）──────────────────────────────
if [ -f "$SCANNER" ]; then
    echo ""
    echo "🔍 [第1步] 静态安全扫描（离线）..."
    python3 "$SCANNER" "$PROJECT" --report
    STATIC_EXIT=$?
else
    echo "❌ 找不到扫描器: $SCANNER"
    STATIC_EXIT=2
fi

# ── 2. 网络检测（3秒超时，不阻塞）───────────────────────────
NET_OK=0
if curl -s -m 3 -o /dev/null -w "%{http_code}" https://api.agnes-ai.cn/v1/models 2>/dev/null | grep -q "200\|401\|403"; then
    NET_OK=1
    echo ""
    echo "🌐 [第2步] 网络可用 — 可执行LLM深度审查"
    echo "  → 深度审查报告将由 Hermes 在下一轮对话中补充"
else
    echo ""
    echo "📴 [第2步] 网络不可用（睡觉/断网）— 跳过LLM深度审查"
    echo "  → 静态报告已保存，LLM深度审查将在网络恢复后补跑"
fi

echo ""
echo "📄 报告: $REPORT"
echo "🌐 网络状态: $([ $NET_OK -eq 1 ] && echo 可用 || echo 不可用)"

# 静默模式（no_agent cron）: 只有发现问题才输出，否则保持安静
if [ "$STATIC_EXIT" -ne 0 ]; then
    echo ""
    echo "⚠️  静态扫描发现问题 — 详情见 $REPORT"
    exit 0  # 正常退出，报告已生成；用stdout通知
fi
# 无问题且无网络 → 保持安静（watchdog模式）
exit 0
