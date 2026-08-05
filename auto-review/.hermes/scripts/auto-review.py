#!/usr/bin/env python3
"""
auto-review.py — 离线静态安全扫描（纯本地，永不依赖网络/LLM）
用法:
  auto-review.py <项目目录>            # pre-commit模式: 发现问题 exit 1
  auto-review.py <项目目录> --report   # 报告模式: 输出 ~/Desktop/审查报告-<date>.md
"""
import os
import re
import sys
import datetime

PROJECT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
REPORT_MODE = "--report" in sys.argv

SKIP_DIRS = {
    "node_modules", ".git", "dist", "build", ".next", "vendor",
    "__pycache__", ".venv", "venv", "Pods", ".cache", "coverage",
    ".idea", ".vscode", "target", ".pytest_cache", ".mypy_cache",
}
MAX_FILE_SIZE = 2 * 1024 * 1024  # 跳过>2MB的文件(构建产物/锁文件)

# 规则: (扩展名集合, 严重级别, 描述, 正则)
RULES = [
    # 硬编码密钥
    ({".py", ".go", ".js", ".ts", ".jsx", ".tsx", ".rb", ".php", ".java", ".kt", ".swift"},
     "CRITICAL", "硬编码密钥",
     r"(api_key|secret|password|passwd|token|apikey)\s*[=:]\s*['\"][^'\"]{6,}['\"]"),
    ({".env", ".env.local", ".env.production", ".env.development"},
     "CRITICAL", "环境文件含密钥",
     r"^[A-Z_]+=.{8,}"),
    # 注入
    ({".py"}, "CRITICAL", "shell注入",
     r"os\.system\(|subprocess\.[A-Za-z]+\(.*shell\s*=\s*True"),
    ({".py"}, "CRITICAL", "危险eval/exec",
     r"\beval\(|\bexec\("),
    ({".js", ".ts", ".jsx", ".tsx"}, "CRITICAL", "危险eval/Function",
     r"\beval\(|\bnew Function\("),
    # 反序列化
    ({".py"}, "CRITICAL", "pickle反序列化",
     r"pickle\.loads?\("),
    # SQL注入
    ({".py"}, "CRITICAL", "SQL注入风险",
     r"execute\(\s*f['\"]|\.format\(.*\b(SELECT|INSERT|DELETE|UPDATE)\b"),
    ({".go"}, "CRITICAL", "SQL注入风险",
     r"fmt\.Sprintf\(.*\b(SELECT|INSERT|DELETE|UPDATE)\b"),
    ({".py"}, "WARNING", "sqlite3字符串拼接",
     r"execute\(\s*['\"]\s*SELECT.*['\"]\s*%|execute\(\s*['\"]\s*SELECT.*['\"]\.format"),
    # 危险权限
    ({".sh", ".bash"}, "WARNING", "危险chmod 777",
     r"chmod\s+777"),
    ({".sh", ".bash"}, "CRITICAL", "curl管道执行",
     r"curl.*\|\s*(sudo\s+)?(ba)?sh"),
    # 调试残留
    ({".py"}, "SUGGESTION", "调试print残留",
     r"^\s*print\("),
    ({".js", ".ts", ".jsx", ".tsx"}, "SUGGESTION", "调试console.log",
     r"console\.log\("),
    ({".go"}, "SUGGESTION", "调试fmt.Println",
     r"fmt\.Println\("),
    # TODO
    ({".py", ".go", ".js", ".ts", ".java"}, "SUGGESTION", "TODO/FIXME遗留",
     r"TODO|FIXME|HACK"),
]


def iter_files(root):
    total = 0
    for dirpath, dirnames, filenames in os.walk(root):
        # 原地剪枝跳过目录
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")]
        for fn in filenames:
            p = os.path.join(dirpath, fn)
            try:
                if os.path.getsize(p) > MAX_FILE_SIZE:
                    continue
                yield p
                total += 1
                if total > 5000:  # 安全上限：最多扫5000个文件，防止意外卡死
                    print("⚠️  文件数超5000，提前停止（项目过大，建议分目录扫描）")
                    return
            except OSError:
                continue


def main():
    issues = []
    scanned = 0
    for path in iter_files(PROJECT):
        ext = os.path.splitext(path)[1].lower()
        rel = os.path.relpath(path, PROJECT)
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                lines = f.readlines()
        except OSError:
            continue
        for lineno, line in enumerate(lines, 1):
            for exts, sev, desc, pattern in RULES:
                if ext in exts or os.path.basename(path) in exts:
                    if re.search(pattern, line, re.IGNORECASE):
                        content = line.strip()[:80]
                        issues.append((sev, rel, lineno, desc, content))
        scanned += 1

    if REPORT_MODE:
        date = datetime.date.today().isoformat()
        report = os.path.expanduser(f"~/Desktop/审查报告-{date}.md")
        critical = sum(1 for i in issues if i[0] == "CRITICAL")
        warning = sum(1 for i in issues if i[0] == "WARNING")
        suggestion = sum(1 for i in issues if i[0] == "SUGGESTION")
        verdict = "NEEDS_CHANGE" if issues else "APPROVED"
        with open(report, "w", encoding="utf-8") as f:
            f.write(f"# 自动审查报告 — {date}\n\n")
            f.write("> 扫描方式：离线静态扫描（auto-review.py，纯本地无网络依赖）\n")
            f.write(f"> 项目：{PROJECT}\n\n")
            f.write("## 概览\n")
            f.write(f"- 扫描文件数: {scanned}\n")
            f.write(f"- 发现问题: {len(issues)}（CRITICAL {critical} / WARNING {warning} / SUGGESTION {suggestion}）\n")
            f.write(f"- 结论: {verdict}\n\n")
            f.write("## 问题列表\n\n| 严重程度 | 文件 | 行号 | 描述 | 内容 |\n")
            f.write("|----------|------|------|------|------|\n")
            for sev, rel, ln, desc, content in issues:
                content = content.replace("|", "\\|")
                f.write(f"| {sev} | {rel} | L{ln} | {desc} | `{content}` |\n")
            f.write("\n## 说明\n")
            f.write("- CRITICAL: 必须修复（密钥泄露/注入/反序列化）\n")
            f.write("- WARNING: 建议修复\n")
            f.write("- SUGGESTION: 可选优化\n")
            f.write("- 深度LLM审查将在有网络时补充执行\n")
        print(f"✅ 报告已生成: {report} ({len(issues)} issues)")
        return 0

    if issues:
        print(f"⚠️  发现 {len(issues)} 个问题:")
        for sev, rel, ln, desc, content in issues:
            print(f"  [{sev}] {rel}:L{ln} — {desc}: {content}")
        print("\n❌ 提交被阻止 — 请先修复 CRITICAL 问题（或确认后 git commit --no-verify）")
        return 1
    print(f"✅ 扫描通过（{scanned} 个文件，无问题）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
