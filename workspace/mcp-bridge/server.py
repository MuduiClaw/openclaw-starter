#!/usr/bin/env python3
"""
OpenClaw MCP Bridge — 把 Mac mini 上 OpenClaw 的基建暴露给 Tailscale 内的 Antigravity IDE。

Tools:
  知识层: memory_search / memory_read / skill_list / skill_read
  网络层: web_search / web_fetch
  工具层: cli_run / shell_exec / git_status / op_get / models_list / system_info
  文件层: project_read / project_write / project_tree / code_search

Run:
  .venv/bin/python server.py                      # stdio (本地测试)
  .venv/bin/python server.py --sse --port 9100    # SSE (Tailscale 暴露)
"""

from __future__ import annotations

import json
import os
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Optional

import html2text
import httpx
from mcp.server.fastmcp import FastMCP
from mcp.server.transport_security import TransportSecuritySettings

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

WORKSPACE = Path(os.environ.get("OPENCLAW_WORKSPACE", os.path.expanduser("~/clawd")))
MEMORY_DIR = WORKSPACE / "memory"
PROJECTS_DIR = Path(os.path.expanduser("~/projects"))
SKILLS_DIRS = [
    WORKSPACE / "skills",
    Path(os.path.expanduser("~/.agents/skills")),
]
BRAVE_API_KEY = os.environ.get(
    "BRAVE_API_KEY", "__YOUR_BRAVE_API_KEY__"
)
ANTIGRAVITY_URL = os.environ.get(
    "ANTIGRAVITY_URL", "http://127.0.0.1:8045/v1"
)

# 白名单：允许读取的目录
READABLE_ROOTS = [
    WORKSPACE.resolve(),
    PROJECTS_DIR.resolve(),
]

# 允许代理执行的 CLI 工具白名单
CLI_ALLOWLIST: dict[str, dict] = {
    "qmd": {
        "bin": "qmd",
        "desc": "Knowledge base semantic search/index",
    },
}

# html2text converter
_h2t = html2text.HTML2Text()
_h2t.ignore_links = False
_h2t.ignore_images = True
_h2t.body_width = 0


def _load_op_env() -> dict:
    """Load 1Password service account env from config file."""
    env_file = os.path.expanduser("~/.config/openclaw/1password.env")
    env_extra = {}
    if os.path.exists(env_file):
        for line in open(env_file):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("export "):
                line = line[7:]
            if "=" in line:
                k, v = line.split("=", 1)
                env_extra[k.strip()] = v.strip().strip('"').strip("'")
    return env_extra


def _path_allowed(p: Path) -> bool:
    """Check if a resolved path falls under any allowed root."""
    try:
        return any(p.is_relative_to(r) for r in READABLE_ROOTS)
    except (TypeError, ValueError):
        return False


def _run(cmd: str | list, timeout: int = 60, env_extra: dict | None = None, cwd: str | None = None) -> str:
    """Run a subprocess and return combined output."""
    env = {**os.environ}
    if env_extra:
        env.update(env_extra)
    try:
        r = subprocess.run(
            cmd, shell=isinstance(cmd, str),
            capture_output=True, text=True, timeout=timeout,
            env=env, cwd=cwd or str(WORKSPACE),
        )
        out = (r.stdout + r.stderr).strip()
        if not out:
            return "(no output)"
        return out[:15000] if len(out) > 15000 else out
    except subprocess.TimeoutExpired:
        return f"Error: timed out ({timeout}s)"
    except Exception as e:
        return f"Error: {e}"


# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------

# Tailscale + localhost hosts for DNS rebinding protection (MCP SDK ≥1.26)
_ALLOWED_HOSTS = [
    "127.0.0.1:*", "localhost:*", "[::1]:*",           # local
    # Add your Tailscale hosts here if using remote access:
    # "your-hostname:*", "100.x.y.z:*",
]

mcp = FastMCP(
    "openclaw-bridge",
    instructions=(
        "OpenClaw Bridge — Mac mini 基建桥接。\n\n"
        "## ⚠️ 安全协议（强制）\n"
        "1. **绝不直接编辑 ~/.openclaw/openclaw.json** — 用 `openclaw config set` 或 gateway config.patch RPC\n"
        "2. **修复前必须诊断** — 先 `openclaw_diagnose` 查状态+日志+版本，理解问题后再动手\n"
        "3. **升级用安全脚本** — `bash ~/clawd/scripts/safe-upgrade-openclaw.sh [version]`，不要手动 npm install\n"
        "4. **配置变更后必须验证** — 查日志 + openclaw status 确认无回退\n\n"
        "## 工具分层\n"
        "- 🟢 只读/诊断: memory_search, memory_read, skill_list, skill_read, web_search, web_fetch, "
        "system_info, git_status, git_diff, models_list, project_tree, project_read, code_search, "
        "openclaw_diagnose, openclaw_logs\n"
        "- 🟡 安全写入: cli_run (白名单工具), project_write (白名单目录)\n"
        "- 🔴 高风险: shell_exec — 改配置/重启服务前必须先用 openclaw_diagnose 诊断\n\n"
        "## 故障排查流程\n"
        "openclaw_diagnose → openclaw_logs → 查官方 release/changelog → 最小化修复 → 验证\n"
        "详见: TROUBLESHOOTING.md (project_read 可读)"
    ),
    transport_security=TransportSecuritySettings(
        enable_dns_rebinding_protection=True,
        allowed_hosts=_ALLOWED_HOSTS,
    ),
)


# ========================== 诊断层（故障排查必须先调这些） ==========================

@mcp.tool(annotations={"title": "OpenClaw Diagnose", "readOnlyHint": True, "openWorldHint": False})
async def openclaw_diagnose() -> str:
    """一键诊断 OpenClaw 全栈状态。修复任何问题前必须先调用此工具。

    返回：Gateway 状态、版本、通道健康、Cron 汇总、安全审计、最新可用版本。
    """
    sections = []
    # 1. Gateway health
    sections.append("== Gateway Status ==")
    sections.append(_run("openclaw health 2>&1", timeout=15))
    # 2. Version
    sections.append("\n== Version ==")
    sections.append(_run("openclaw --version 2>&1", timeout=10))
    sections.append("Latest: " + _run("npm view openclaw version 2>&1", timeout=15))
    # 3. Channels
    sections.append("\n== Channels ==")
    sections.append(_run("openclaw status 2>&1 | sed -n '/Channels/,/Sessions/p' | head -15", timeout=15))
    # 4. Cron summary
    sections.append("\n== Cron Jobs ==")
    sections.append(_run("openclaw cron list 2>&1 | tail -25", timeout=15))
    # 5. Security audit
    sections.append("\n== Security Audit ==")
    sections.append(_run("openclaw security audit 2>&1 | grep -A1 'Summary:'", timeout=15))
    # 6. Recent errors in log
    sections.append("\n== Recent Errors (last 10) ==")
    log_date = _run("date +%Y-%m-%d", timeout=5).strip()
    sections.append(_run(
        f"grep -i 'error\\|fatal\\|crash\\|SIGTERM' /tmp/openclaw/openclaw-{log_date}.log 2>/dev/null | tail -10",
        timeout=10,
    ))
    return "\n".join(sections)


@mcp.tool(annotations={"title": "OpenClaw Logs", "readOnlyHint": True, "openWorldHint": False})
async def openclaw_logs(lines: int = 100, grep: str = "") -> str:
    """读取 OpenClaw 当天日志。可选 grep 过滤。

    示例:
      lines=50              → 最后 50 行日志
      grep="error"          → 过滤含 error 的行
      grep="cron|heartbeat" → 多关键字过滤
    """
    log_date = _run("date +%Y-%m-%d", timeout=5).strip()
    log_path = f"/tmp/openclaw/openclaw-{log_date}.log"
    n = min(lines, 500)
    if grep:
        return _run(f"grep -i '{grep}' {log_path} 2>/dev/null | tail -{n}", timeout=15)
    return _run(f"tail -{n} {log_path} 2>/dev/null", timeout=15)


@mcp.tool(annotations={"title": "OpenClaw Release Info", "readOnlyHint": True, "openWorldHint": True})
async def openclaw_releases(count: int = 3) -> str:
    """查询 OpenClaw 官方最新 Release 信息（版本号、变更日志摘要）。

    修复或升级前先调此工具，确认是否为已知问题或有新版修复。
    """
    return _run(
        f"npm view openclaw versions --json 2>/dev/null | python3 -c \""
        f"import json,sys; v=json.load(sys.stdin); "
        f"[print(x) for x in (v if isinstance(v,list) else [v])[-{min(count,10)}:]]\"",
        timeout=15,
    )


@mcp.tool(annotations={"title": "OpenClaw Troubleshooting Guide", "readOnlyHint": True, "openWorldHint": False})
async def openclaw_troubleshooting() -> str:
    """读取 OpenClaw 诊断与修复最佳实践文档。遇到故障时先读这个。"""
    guide_path = WORKSPACE / "mcp-bridge" / "TROUBLESHOOTING.md"
    if guide_path.exists():
        return guide_path.read_text()[:10000]
    return "TROUBLESHOOTING.md not found"


# ========================== 知识层 ==========================

@mcp.tool(annotations={"title": "Memory Search", "readOnlyHint": True, "openWorldHint": False})
async def memory_search(query: str, max_results: int = 5) -> str:
    """语义搜索 OpenClaw 知识库（记忆、决策、教训、项目上下文）。"""
    return _run(["qmd", "search", query, "--json", "-n", str(min(max_results, 20))], timeout=30)


@mcp.tool(annotations={"title": "Memory Read", "readOnlyHint": True, "openWorldHint": False})
async def memory_read(path: str, offset: int = 0, limit: int = 200) -> str:
    """读取知识库文件。path 相对于 workspace，如 'memory/archive/lessons.md'、'MEMORY.md'、'TOOLS.md'。"""
    target = (WORKSPACE / path).resolve()
    if not _path_allowed(target):
        return "Error: path outside allowed directories"
    if not target.exists():
        return f"File not found: {path}"
    if not target.is_file():
        return f"Not a file: {path}"
    try:
        lines = target.read_text(errors="replace").splitlines()
        total = len(lines)
        selected = lines[offset : offset + limit]
        header = f"[{path}] lines {offset+1}-{offset+len(selected)} of {total}\n"
        return header + "\n".join(selected)
    except Exception as e:
        return f"Error reading file: {e}"


@mcp.tool(annotations={"title": "Skill List", "readOnlyHint": True, "openWorldHint": False})
async def skill_list() -> str:
    """列出所有可用的 OpenClaw skills 及描述。"""
    skills = []
    for base in SKILLS_DIRS:
        if not base.exists():
            continue
        for skill_dir in sorted(base.iterdir()):
            if not skill_dir.is_dir():
                continue
            skill_md = skill_dir / "SKILL.md"
            if not skill_md.exists():
                continue
            desc = ""
            try:
                for line in skill_md.read_text().splitlines()[:20]:
                    if line.strip().startswith("description:"):
                        desc = line.split(":", 1)[1].strip()
                        break
            except Exception:
                pass
            skills.append({"name": skill_dir.name, "location": str(base.name), "description": desc})
    return json.dumps(skills, ensure_ascii=False, indent=2)


@mcp.tool(annotations={"title": "Skill Read", "readOnlyHint": True, "openWorldHint": False})
async def skill_read(skill_name: str) -> str:
    """读取指定 skill 的 SKILL.md 内容。"""
    for base in SKILLS_DIRS:
        skill_md = base / skill_name / "SKILL.md"
        if skill_md.exists():
            try:
                content = skill_md.read_text()
                return content[:15000] + "\n\n... (truncated)" if len(content) > 15000 else content
            except Exception as e:
                return f"Error reading skill: {e}"
    available = []
    for base in SKILLS_DIRS:
        if base.exists():
            available.extend(d.name for d in base.iterdir() if (d / "SKILL.md").exists())
    return f"Skill '{skill_name}' not found. Available: {', '.join(sorted(available)[:30])}"


# ========================== 网络层 ==========================

@mcp.tool(annotations={"title": "Web Search (Brave)", "readOnlyHint": True, "openWorldHint": True})
async def web_search(query: str, count: int = 5, freshness: Optional[str] = None) -> str:
    """使用 Brave Search API 搜索互联网。freshness: pd(天)/pw(周)/pm(月)/py(年)。"""
    params: dict = {"q": query, "count": min(count, 10)}
    if freshness:
        params["freshness"] = freshness
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                "https://api.search.brave.com/res/v1/web/search",
                params=params,
                headers={"X-Subscription-Token": BRAVE_API_KEY, "Accept": "application/json"},
                timeout=15,
            )
            resp.raise_for_status()
            data = resp.json()
            results = [
                {"title": r.get("title"), "url": r.get("url"), "description": r.get("description", "")[:300]}
                for r in data.get("web", {}).get("results", [])
            ]
            return json.dumps(results, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"Error: {e}"


@mcp.tool(annotations={"title": "Web Fetch", "readOnlyHint": True, "openWorldHint": True})
async def web_fetch(url: str, max_chars: int = 8000) -> str:
    """抓取 URL 并提取可读内容（转 Markdown）。"""
    try:
        async with httpx.AsyncClient(follow_redirects=True) as client:
            resp = await client.get(
                url, timeout=20,
                headers={"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) OpenClaw-Bridge/0.1"},
            )
            resp.raise_for_status()
            ct = resp.headers.get("content-type", "")
            text = _h2t.handle(resp.text) if "html" in ct else resp.text
            if len(text) > max_chars:
                text = text[:max_chars] + f"\n\n... (truncated, {len(resp.text)} chars total)"
            return text
    except Exception as e:
        return f"Error fetching {url}: {e}"


# ========================== 工具层 ==========================

@mcp.tool(annotations={"title": "CLI Run", "readOnlyHint": False, "destructiveHint": False, "openWorldHint": True})
async def cli_run(tool: str, args: str = "") -> str:
    """执行白名单内的 CLI 工具。可用: qmd。

    示例: tool="qmd", args="search 'AI agent'"
    """
    if tool not in CLI_ALLOWLIST:
        info = "\n".join(f"  {k}: {v['desc']}" for k, v in CLI_ALLOWLIST.items())
        return f"Error: '{tool}' not in allowlist.\nAvailable:\n{info}"
    cfg = CLI_ALLOWLIST[tool]
    # args 可能含空格参数，保留原样让 shell 解析（个人使用）
    return _run(f"{shlex.quote(cfg['bin'])} {args}", env_extra=cfg.get("env"))


@mcp.tool(annotations={"title": "Shell Exec", "readOnlyHint": False, "destructiveHint": True, "openWorldHint": True})
async def shell_exec(command: str, cwd: str = "", timeout: int = 60) -> str:
    """在 Mac mini 上执行 shell 命令。⚠️ 高风险工具，使用前请遵守：

    **安全协议（强制）:**
    1. 修改 OpenClaw 配置 → 必须先调 openclaw_diagnose，禁止直接编辑 ~/.openclaw/openclaw.json
    2. 升级 OpenClaw → 用 `bash ~/clawd/scripts/safe-upgrade-openclaw.sh`
    3. 重启服务 → 先查日志确认根因，不要盲重启
    4. 任何写操作后 → 查日志验证

    **正确的配置修改方式:**
    - `openclaw config set <key> <value>` (CLI)
    - 或在 OpenClaw agent session 内用 gateway config.patch tool

    cwd 可选：绝对路径或 ~/projects/ 下的相对路径，空则在 workspace 执行。
    timeout 默认 60 秒。
    """
    work_dir = str(WORKSPACE)
    if cwd:
        p = Path(cwd).expanduser().resolve() if cwd.startswith("/") or cwd.startswith("~") else (PROJECTS_DIR / cwd).resolve()
        if p.exists():
            work_dir = str(p)
        else:
            return f"Error: directory not found: {cwd}"
    return _run(command, timeout=min(timeout, 300), cwd=work_dir)


@mcp.tool(annotations={"title": "Git Status", "readOnlyHint": True, "openWorldHint": False})
async def git_status(repo: str = "") -> str:
    """查看 Git 仓库状态。repo 为 ~/projects/ 下的目录名，空则查 workspace。

    示例: repo="" (workspace) | repo="my-project" | repo="web-app"
    """
    if repo:
        repo_path = (PROJECTS_DIR / repo).resolve()
        if not _path_allowed(repo_path):
            return "Error: path not allowed"
    else:
        repo_path = WORKSPACE.resolve()

    if not repo_path.exists():
        # List available repos
        if PROJECTS_DIR.exists():
            repos = [d.name for d in PROJECTS_DIR.iterdir() if (d / ".git").exists()]
            return f"Repo '{repo}' not found. Available: {', '.join(sorted(repos))}"
        return f"Repo '{repo}' not found"

    parts = [
        "=== branch & status ===",
        _run("git status -sb", cwd=str(repo_path), timeout=10),
        "\n=== recent commits ===",
        _run("git log --oneline -10", cwd=str(repo_path), timeout=10),
    ]
    return "\n".join(parts)


@mcp.tool(annotations={"title": "Git Diff", "readOnlyHint": True, "openWorldHint": False})
async def git_diff(repo: str = "", staged: bool = False) -> str:
    """查看 Git diff。repo 同 git_status，staged=True 看暂存区。"""
    repo_path = (PROJECTS_DIR / repo).resolve() if repo else WORKSPACE.resolve()
    if not _path_allowed(repo_path):
        return "Error: path not allowed"
    flag = "--cached" if staged else ""
    return _run(f"git diff {flag} --stat && echo '---' && git diff {flag}", cwd=str(repo_path), timeout=15)


@mcp.tool(annotations={"title": "1Password Get", "readOnlyHint": True, "openWorldHint": False})
async def op_get(item: str, field: str = "password") -> str:
    """从 1Password 获取凭据。item 为条目名称或 ID，field 为字段名（默认 password）。

    示例: item="Cloudflare API Token" | item="GitHub Token" field="username"
    """
    env_extra = _load_op_env()
    result = _run(
        f"op item get {shlex.quote(item)} --fields {shlex.quote(field)} --vault '__YOUR_1PASSWORD_VAULT__'",
        env_extra=env_extra, timeout=15,
    )
    # Mask the value for safety: show first 5 and last 3 chars
    if not result.startswith("Error") and len(result) > 10:
        masked = result[:5] + "..." + result[-3:]
        return f"Value (masked): {masked}\nFull length: {len(result)} chars\n\nTo get full value, use op_get_raw."
    return result


@mcp.tool(annotations={"title": "1Password Get (Unmasked)", "readOnlyHint": True, "openWorldHint": False})
async def op_get_raw(item: str, field: str = "password") -> str:
    """从 1Password 获取完整凭据（不掩码）。仅限个人使用。"""
    env_extra = _load_op_env()
    return _run(
        f"op item get {shlex.quote(item)} --fields {shlex.quote(field)} --vault '__YOUR_1PASSWORD_VAULT__'",
        env_extra=env_extra, timeout=15,
    )


@mcp.tool(annotations={"title": "Antigravity Models", "readOnlyHint": True, "openWorldHint": False})
async def models_list(filter: str = "") -> str:
    """列出 Antigravity 代理支持的 AI 模型。可选 filter 过滤模型名。"""
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(f"{ANTIGRAVITY_URL}/models", timeout=10)
            resp.raise_for_status()
            data = resp.json()
            models = [m.get("id", "") for m in data.get("data", [])]
            if filter:
                models = [m for m in models if filter.lower() in m.lower()]
            return f"Found {len(models)} models:\n" + "\n".join(sorted(models))
    except Exception as e:
        return f"Error: {e}"


@mcp.tool(annotations={"title": "System Info", "readOnlyHint": True, "openWorldHint": False})
async def system_info() -> str:
    """Mac mini 系统状态：负载、内存、磁盘、关键进程。"""
    parts = [
        "=== uptime ===", _run("uptime", timeout=5),
        "\n=== memory ===", _run("vm_stat | head -10", timeout=5),
        "\n=== disk ===", _run("df -h / | tail -1", timeout=5),
        "\n=== key processes ===",
        _run("ps aux | grep -E '(openclaw|antigrav|uvicorn|node )' | grep -v grep | awk '{print $11, $1, $3\"%\", $4\"%\"}'", timeout=5),
        "\n=== tailscale ===", _run("tailscale status --peers 2>/dev/null | head -6", timeout=5),
    ]
    return "\n".join(parts)


# ========================== 文件层 ==========================

@mcp.tool(annotations={"title": "Project Tree", "readOnlyHint": True, "openWorldHint": False})
async def project_tree(path: str = "", depth: int = 2) -> str:
    """列出项目目录结构。path 为 ~/projects/ 下的路径，空则列出所有项目。

    示例: path="" (列项目) | path="my-project" | path="my-project/src"
    """
    if not path:
        # List all projects
        if PROJECTS_DIR.exists():
            repos = []
            for d in sorted(PROJECTS_DIR.iterdir()):
                if d.is_dir() and not d.name.startswith("."):
                    is_git = "🔗" if (d / ".git").exists() else "📁"
                    repos.append(f"  {is_git} {d.name}")
            return f"~/projects/ ({len(repos)} items):\n" + "\n".join(repos)
        return "~/projects/ not found"

    target = (PROJECTS_DIR / path).resolve()
    if not _path_allowed(target):
        return "Error: path not allowed"
    if not target.exists():
        return f"Path not found: {path}"

    return _run(f"find . -maxdepth {min(depth, 4)} -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/.venv/*' -not -name '*.pyc' | sort | head -100", cwd=str(target), timeout=10)


@mcp.tool(annotations={"title": "Project Read", "readOnlyHint": True, "openWorldHint": False})
async def project_read(path: str, offset: int = 0, limit: int = 200) -> str:
    """读取项目文件。path 为 ~/projects/ 或 ~/clawd/ 下的相对路径。

    示例: path="my-project/src/content/config.ts"
    """
    # Try projects first, then workspace
    target = (PROJECTS_DIR / path).resolve()
    if not target.exists():
        target = (WORKSPACE / path).resolve()
    if not _path_allowed(target):
        return "Error: path outside allowed directories"
    if not target.exists():
        return f"File not found: {path}"
    if not target.is_file():
        return f"Not a file: {path}"
    try:
        lines = target.read_text(errors="replace").splitlines()
        total = len(lines)
        selected = lines[offset : offset + limit]
        header = f"[{path}] lines {offset+1}-{offset+len(selected)} of {total}\n"
        return header + "\n".join(selected)
    except Exception as e:
        return f"Error reading file: {e}"


@mcp.tool(annotations={"title": "Project Write", "readOnlyHint": False, "destructiveHint": True, "openWorldHint": False})
async def project_write(path: str, content: str, mode: str = "overwrite") -> str:
    """写入文件。path 为 ~/projects/ 或 ~/clawd/ 下的相对路径。

    mode: "overwrite"(覆盖) | "append"(追加) | "insert:N"(在第N行插入)
    自动创建不存在的父目录。

    示例:
      path="my-project/test.txt", content="hello", mode="overwrite"
      path="mcp-bridge/server.py", content="# new line", mode="append"
    """
    # Resolve path: try projects first, then workspace
    target = (PROJECTS_DIR / path).resolve()
    if not str(target).startswith(str(PROJECTS_DIR.resolve())):
        target = (WORKSPACE / path).resolve()
    if not _path_allowed(target):
        return "Error: path outside allowed directories"

    try:
        target.parent.mkdir(parents=True, exist_ok=True)

        if mode == "append":
            with open(target, "a") as f:
                f.write(content)
            return f"Appended {len(content)} chars to {path}"
        elif mode.startswith("insert:"):
            line_no = int(mode.split(":")[1])
            if target.exists():
                lines = target.read_text().splitlines(keepends=True)
                lines.insert(max(0, line_no - 1), content + "\n")
                target.write_text("".join(lines))
                return f"Inserted at line {line_no} in {path}"
            else:
                target.write_text(content)
                return f"Created {path} (insert mode, file was new)"
        else:  # overwrite
            target.write_text(content)
            return f"Wrote {len(content)} chars to {path}"
    except Exception as e:
        return f"Error writing file: {e}"


@mcp.tool(annotations={"title": "Code Search", "readOnlyHint": True, "openWorldHint": False})
async def code_search(pattern: str, path: str = "", file_glob: str = "", max_results: int = 20) -> str:
    """在项目中搜索代码。使用 grep -rn。

    pattern: 搜索模式（支持正则）
    path: ~/projects/ 下的目录，空则搜 workspace
    file_glob: 文件过滤，如 "*.py" "*.ts"

    示例: pattern="def main", path="my-project", file_glob="*.py"
    """
    search_dir = str(WORKSPACE)
    if path:
        p = (PROJECTS_DIR / path).resolve()
        if _path_allowed(p) and p.exists():
            search_dir = str(p)
        else:
            return f"Error: path '{path}' not found or not allowed"

    include = f"--include={shlex.quote(file_glob)}" if file_glob else ""
    cmd = f"grep -rn {include} --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=.venv --exclude-dir=__pycache__ -e {shlex.quote(pattern)} . | head -{min(max_results, 50)}"
    return _run(cmd, cwd=search_dir, timeout=15)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    """Entry point. --sse --port N --host H"""
    transport = "stdio"
    port = 9100
    host = "127.0.0.1"

    args = sys.argv[1:]
    if "--streamable-http" in args:
        transport = "streamable-http"
        args.remove("--streamable-http")
    elif "--sse" in args:
        transport = "sse"
        args.remove("--sse")
    if "--port" in args:
        idx = args.index("--port")
        port = int(args[idx + 1])
        args.pop(idx); args.pop(idx)
    if "--host" in args:
        idx = args.index("--host")
        host = args[idx + 1]
        args.pop(idx); args.pop(idx)

    if transport in ("sse", "streamable-http"):
        print(f"🔌 OpenClaw MCP Bridge starting on {host}:{port} ({transport})")
        mcp.settings.host = host
        mcp.settings.port = port

    mcp.run(transport=transport)


if __name__ == "__main__":
    main()
