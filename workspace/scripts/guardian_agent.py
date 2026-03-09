#!/usr/bin/env python3
"""
OpenClaw Guardian Agent — 3层智能守护

Layer 1: 生存检查（进程/端口）→ 简单重启
Layer 1.5: openclaw doctor --fix
Layer 3: .bak / Git 回滚（确定性兜底）
Layer 4: Discord 通知人工介入
"""

import json
import logging
import os
import re
import shutil
import subprocess
import sys
import time
import argparse
from datetime import datetime
from logging.handlers import RotatingFileHandler
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

# ============================================================
# 配置常量
# ============================================================

HOME = os.path.expanduser("~")

HEALTH_URL = "http://127.0.0.1:18789/health"
HEALTH_TIMEOUT = 5
HEALTH_RETRIES = 3
HEALTH_RETRY_DELAY = 1.0

OPENCLAW_JSON = os.path.join(HOME, ".openclaw", "openclaw.json")
OPENCLAW_DIR = os.path.join(HOME, ".openclaw")
OPENCLAW_REPO = "https://github.com/openclaw/openclaw"  # openclaw 开源仓库
GATEWAY_ERR_LOG = os.path.join(HOME, ".openclaw", "logs", "gateway.err.log")
GATEWAY_LOG = os.path.join(HOME, ".openclaw", "logs", "gateway.log")
GUARDIAN_LOG = os.path.join(HOME, ".openclaw", "logs", "guardian.log")
STATE_FILE = os.path.join(HOME, ".openclaw", "logs", "guardian_state.json")

LAUNCHD_LABEL = "ai.openclaw.gateway"
SAFE_RESTART_SCRIPT = os.path.join(HOME, "clawd", "scripts", "safe-gateway-restart.sh")

BAK_FILES = [
    OPENCLAW_JSON + ".bak",
    OPENCLAW_JSON + ".bak.1",
    OPENCLAW_JSON + ".bak.2",
    OPENCLAW_JSON + ".bak.3",
    OPENCLAW_JSON + ".bak.4",
]

# Discord 直连（不依赖 gateway，token 从 config 动态读取）
def _load_discord_token():
    """从 openclaw.json 读取 Discord bot token，避免硬编码过期"""
    try:
        with open(OPENCLAW_JSON, "r") as f:
            cfg = json.load(f)
        return cfg.get("channels", {}).get("discord", {}).get("token", "")
    except Exception:
        return ""

DISCORD_BOT_TOKEN = _load_discord_token()
DISCORD_LOG_CHANNEL = ""  # Set your Discord channel ID for alerts
DISCORD_DM_USERS = []  # Set Discord user IDs for DM alerts

CHECK_INTERVAL = 60
MAX_FAILURES = 3
HEARTBEAT_INTERVAL_CYCLES = 10

DISK_FREE_ALERT_BYTES = 1 * 1024 * 1024 * 1024   # < 1GB 告警
RSS_ALERT_BYTES = 2 * 1024 * 1024 * 1024         # > 2GB 告警
UPTIME_CRASH_LOOP_SECONDS = 30                    # < 30s 视为重启抖动

# 冷却时间（秒）
COOLDOWNS = {
    "simple_restart": 30,     # 检查间隔60s，冷却要短于检查间隔才能每轮都重启
    "doctor_fix": 180,        # doctor --fix 冷却
    "git_rollback": 600,
    "discord_notify": 300,
}

# 安全开关：细粒度控制 Guardian 配置改写能力
# 目标：保留 doctor 修复能力，禁止 Layer3 回滚覆盖业务配置。
GUARDIAN_ALLOW_DOCTOR_FIX = True
GUARDIAN_ALLOW_LAYER3_ROLLBACK = False


# ============================================================
# 日志
# ============================================================

def setup_logger() -> logging.Logger:
    """配置日志轮转: 5MB，保留3个历史文件"""
    logger = logging.getLogger("guardian")
    logger.setLevel(logging.DEBUG)

    os.makedirs(os.path.dirname(GUARDIAN_LOG), exist_ok=True)

    fh = RotatingFileHandler(
        GUARDIAN_LOG, maxBytes=5 * 1024 * 1024, backupCount=3, encoding="utf-8"
    )
    fh.setLevel(logging.DEBUG)
    fh.setFormatter(logging.Formatter(
        "[%(asctime)s] %(levelname)s %(message)s", datefmt="%Y-%m-%d %H:%M:%S"
    ))

    sh = logging.StreamHandler()
    sh.setLevel(logging.INFO)
    sh.setFormatter(logging.Formatter("%(levelname)s %(message)s"))

    logger.addHandler(fh)
    logger.addHandler(sh)
    return logger


log = setup_logger()


# ============================================================
# 工具函数
# ============================================================

def run_cmd(cmd, timeout=30, cwd=None):
    """执行命令，返回 (returncode, stdout, stderr)"""
    try:
        r = subprocess.run(
            cmd, shell=isinstance(cmd, str), capture_output=True,
            text=True, timeout=timeout, cwd=cwd,
        )
        return r.returncode, r.stdout.strip(), r.stderr.strip()
    except subprocess.TimeoutExpired:
        return -1, "", "命令超时"
    except Exception as e:
        return -1, "", str(e)


def kill_port_zombies(port=18789):
    """清理端口占用残留进程（防止旧进程影响重启）"""
    rc, port_pids, _ = run_cmd(f"/usr/sbin/lsof -ti :{port}", timeout=5)
    if rc == 0 and port_pids.strip():
        for pid in port_pids.strip().split("\n"):
            pid = pid.strip()
            if pid:
                log.info(f"清理端口{port}残留进程 PID={pid}")
                run_cmd(f"kill -9 {pid}", timeout=5)
        time.sleep(2)


def read_tail(filepath, lines=50):
    """读取文件最后N行"""
    try:
        with open(filepath, "rb") as f:
            f.seek(0, 2)
            size = f.tell()
            # 估算每行200字节
            chunk = min(size, lines * 200)
            f.seek(max(0, size - chunk))
            data = f.read().decode("utf-8", errors="replace")
            return "\n".join(data.splitlines()[-lines:])
    except Exception:
        return ""


def http_request(url, data=None, headers=None, timeout=15, parse_json=True):
    """简单 HTTP 请求（不依赖 requests 库）"""
    headers = headers or {}
    headers.setdefault("User-Agent", "OpenClaw-Guardian/1.0")
    body = json.dumps(data).encode("utf-8") if data else None
    if body:
        headers.setdefault("Content-Type", "application/json")
    req = Request(url, data=body, headers=headers, method="POST" if body else "GET")
    try:
        with urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            if parse_json:
                try:
                    return resp.status, json.loads(raw)
                except json.JSONDecodeError:
                    return resp.status, {"raw": raw[:500]}
            return resp.status, {"raw": raw[:500]}
    except HTTPError as e:
        body_text = e.read().decode("utf-8", errors="replace") if e.fp else ""
        return e.code, {"error": body_text}
    except (URLError, Exception) as e:
        return 0, {"error": str(e)}


def validate_config(path):
    """验证 openclaw.json 有效性，返回 (valid, error_msg)"""
    try:
        size = os.path.getsize(path)
        if size < 100:
            return False, f"文件过小({size}B)"
        if size > 1024 * 1024:
            return False, f"文件过大({size}B)"
        with open(path, "r") as f:
            cfg = json.load(f)
        if not isinstance(cfg.get("gateway", {}).get("port"), int):
            return False, "gateway.port 缺失"
        if not cfg.get("models", {}).get("providers"):
            return False, "models.providers 为空"
        return True, "有效"
    except json.JSONDecodeError as e:
        return False, f"JSON语法错误: {e}"
    except Exception as e:
        return False, str(e)


def atomic_write_json(path, data):
    """原子写入 JSON（写临时文件再 rename）"""
    tmp = path + ".guardian_tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    os.rename(tmp, path)


# ============================================================
# CooldownManager
# ============================================================

class CooldownManager:
    def __init__(self, state):
        self._last = state.get("cooldowns", {})

    def can(self, action):
        last = self._last.get(action, 0)
        cd = COOLDOWNS.get(action, 60)
        return (time.time() - last) >= cd

    def record(self, action):
        self._last[action] = time.time()

    def to_dict(self):
        return dict(self._last)


# ============================================================
# Layer 1: HealthChecker
# ============================================================

class HealthChecker:
    @staticmethod
    def _format_bytes(num_bytes):
        if num_bytes is None:
            return "未知"
        return f"{num_bytes / (1024 * 1024 * 1024):.2f}GB"

    @staticmethod
    def _parse_etime_to_seconds(etime_text):
        """
        解析 ps etime:
        - Linux 可能是 etimes(秒)
        - etime 可能是 [[dd-]hh:]mm:ss
        """
        value = (etime_text or "").strip()
        if not value:
            return None

        if value.isdigit():
            return int(value)

        day_part = 0
        time_part = value
        if "-" in value:
            day_str, time_part = value.split("-", 1)
            if day_str.isdigit():
                day_part = int(day_str)

        parts = time_part.split(":")
        try:
            if len(parts) == 3:
                hours, minutes, seconds = map(int, parts)
            elif len(parts) == 2:
                hours = 0
                minutes, seconds = map(int, parts)
            else:
                return None
        except ValueError:
            return None

        return day_part * 86400 + hours * 3600 + minutes * 60 + seconds

    def _get_process_rss_bytes(self, pid):
        rc, stdout, _ = run_cmd(f"ps -o rss= -p {pid}", timeout=5)
        if rc != 0 or not stdout.strip():
            return None
        token = stdout.strip().splitlines()[0].strip()
        m = re.search(r"\d+", token)
        if not m:
            return None
        return int(m.group()) * 1024

    def _get_process_uptime_seconds(self, pid):
        # Linux: etimes 直接是秒
        rc, stdout, _ = run_cmd(f"ps -o etimes= -p {pid}", timeout=5)
        if rc == 0 and stdout.strip():
            parsed = self._parse_etime_to_seconds(stdout.strip().splitlines()[0])
            if parsed is not None:
                return parsed

        # macOS: etime 是 [[dd-]hh:]mm:ss
        rc, stdout, _ = run_cmd(f"ps -o etime= -p {pid}", timeout=5)
        if rc == 0 and stdout.strip():
            return self._parse_etime_to_seconds(stdout.strip().splitlines()[0])
        return None

    def check(self):
        """
        返回健康状态:
        {
          "healthy": bool,
          "process_alive": bool,
          "pid": int|None,
          "error": str,
          "alerts": list[str],
          "disk_free_bytes": int|None,
          "gateway_rss_bytes": int|None,
          "gateway_uptime_seconds": int|None
        }
        """
        result = {
            "healthy": False,
            "process_alive": False,
            "pid": None,
            "error": "",
            "alerts": [],
            "disk_free_bytes": None,
            "gateway_rss_bytes": None,
            "gateway_uptime_seconds": None,
            "crash_loop_suspected": False,
        }

        # 检查进程
        rc, stdout, _ = run_cmd("pgrep -f 'openclaw-gateway|openclaw.*gateway'", timeout=5)
        if rc == 0 and stdout:
            result["process_alive"] = True
            try:
                result["pid"] = int(stdout.splitlines()[0])
            except ValueError:
                pass

        # 额外健康检测: 磁盘空间 / RSS / uptime
        disk_base = OPENCLAW_DIR if os.path.isdir(OPENCLAW_DIR) else HOME
        try:
            free_bytes = shutil.disk_usage(disk_base).free
            result["disk_free_bytes"] = free_bytes
            if free_bytes < DISK_FREE_ALERT_BYTES:
                result["alerts"].append(
                    f"磁盘可用空间过低: {self._format_bytes(free_bytes)} (< 1.00GB)"
                )
        except Exception as e:
            log.warning("Layer 1: 磁盘空间检测失败: %s", e)

        pid = result.get("pid")
        if pid:
            rss_bytes = self._get_process_rss_bytes(pid)
            result["gateway_rss_bytes"] = rss_bytes
            if rss_bytes is not None and rss_bytes > RSS_ALERT_BYTES:
                result["alerts"].append(
                    f"Gateway RSS 过高: {self._format_bytes(rss_bytes)} (> 2.00GB)"
                )

            uptime_seconds = self._get_process_uptime_seconds(pid)
            result["gateway_uptime_seconds"] = uptime_seconds
            if uptime_seconds is not None and uptime_seconds < UPTIME_CRASH_LOOP_SECONDS:
                result["alerts"].append(
                    f"Gateway 存活时间过短: {uptime_seconds}s (< {UPTIME_CRASH_LOOP_SECONDS}s)，疑似反复崩溃重启"
                )
                result["crash_loop_suspected"] = True

        # 健康检查（带重试，避免瞬时抖动导致误判）
        last_status = 0
        for attempt in range(HEALTH_RETRIES):
            try:
                status, _ = http_request(HEALTH_URL, timeout=HEALTH_TIMEOUT)
                last_status = status
                if status == 200:
                    result["healthy"] = True
                    break
            except Exception:
                pass
            if attempt < HEALTH_RETRIES - 1:
                time.sleep(HEALTH_RETRY_DELAY)

        if not result["healthy"]:
            result["error"] = f"健康检查失败(status={last_status})"

        # uptime 异常优先判定为不健康（即使 HTTP 暂时可用，也视为崩溃抖动）
        if result["crash_loop_suspected"]:
            result["healthy"] = False
            if result["error"]:
                result["error"] += "; "
            result["error"] += (
                f"Gateway uptime < {UPTIME_CRASH_LOOP_SECONDS}s，疑似反复崩溃重启"
            )

        for alert in result["alerts"]:
            log.warning("Layer 1: 健康告警: %s", alert)

        return result

    def _is_service_loaded(self):
        """检查 LaunchAgent 服务是否存在于 launchd 域"""
        uid = os.getuid()
        rc, _, _ = run_cmd(f"launchctl print gui/{uid}/{LAUNCHD_LABEL}", timeout=10)
        return rc == 0

    def _ensure_service_installed(self):
        """确保 LaunchAgent 在 launchd 域里（不在就 install --force）"""
        if self._is_service_loaded():
            return True
        log.warning("Layer 1: 服务 %s 不在 launchd 域中，执行 gateway install --force", LAUNCHD_LABEL)
        rc, stdout, stderr = run_cmd("openclaw gateway install --force", timeout=30)
        if rc != 0:
            log.error("Layer 1: gateway install --force 失败: rc=%d stderr=%s", rc, stderr[:200] if stderr else "")
            return False
        log.info("Layer 1: gateway install --force 成功")
        time.sleep(3)
        return self._is_service_loaded()

    def simple_restart(self):
        """Layer 1 简单重启 — 走统一入口脚本（需 Mudui DM 确认）"""
        log.info("Layer 1: 提交重启请求 (via safe-gateway-restart.sh)")

        # 关键：先确保服务在 launchd 里，不在就 re-install
        self._ensure_service_installed()

        rc, stdout, stderr = run_cmd(
            f"bash {SAFE_RESTART_SCRIPT} --caller guardian --reason 'L1 health check failed'",
            timeout=30
        )
        if rc == 0:
            # Request already pending
            log.info("Layer 1: 重启请求已存在，等待 Mudui 确认")
            return False  # 不算成功（还没重启），但也不升级
        elif rc == 3:
            # Request filed, waiting for approval
            log.info("Layer 1: 重启请求已提交，等待 Mudui DM 确认")
            return False  # 不升级到下一 Layer，等待人工确认
        elif rc == 1:
            log.warning("Layer 1: 重启请求被拒（config invalid）: %s", stdout[:200] if stdout else "")
            return False
        else:
            log.error("Layer 1: 重启请求失败: rc=%d %s", rc, stderr[:200] if stderr else "")
            return False

    def collect_context(self):
        """收集诊断上下文"""
        ctx = {}
        ctx["err_log"] = read_tail(GATEWAY_ERR_LOG, 80)
        ctx["gateway_log"] = read_tail(GATEWAY_LOG, 30)

        # 读配置文件
        try:
            with open(OPENCLAW_JSON, "r") as f:
                ctx["config"] = f.read()
        except Exception as e:
            ctx["config"] = f"[读取失败: {e}]"

        # 进程状态
        health = self.check()
        ctx["process_alive"] = health["process_alive"]
        ctx["pid"] = health["pid"]
        ctx["healthy"] = health["healthy"]
        ctx["health_error"] = health.get("error", "")
        ctx["health_alerts"] = health.get("alerts", [])
        ctx["disk_free_bytes"] = health.get("disk_free_bytes")
        ctx["gateway_rss_bytes"] = health.get("gateway_rss_bytes")
        ctx["gateway_uptime_seconds"] = health.get("gateway_uptime_seconds")

        # 端口占用
        rc, stdout, _ = run_cmd("/usr/sbin/lsof -ti :18789", timeout=5)
        ctx["port_pids"] = stdout if rc == 0 else "无"

        return ctx




# ============================================================
# Layer 3: RollbackManager
# ============================================================

class RollbackManager:
    def __init__(self, cooldown):
        self.cooldown = cooldown

    def rollback(self):
        """按优先级尝试所有回滚策略"""
        if not self.cooldown.can("git_rollback"):
            log.info("Layer 3: 回滚冷却中")
            return False, "冷却中"

        self.cooldown.record("git_rollback")

        # Step 1: .bak 文件
        result = self._try_bak_files()
        if result[0]:
            return result

        # Step 2: git 本地历史
        result = self._try_git_local()
        if result[0]:
            return result

        # Step 3: GitHub 远程
        result = self._try_git_remote()
        if result[0]:
            return result

        return False, "所有回滚策略失败"

    def _try_bak_files(self):
        for bak in BAK_FILES:
            if not os.path.exists(bak):
                continue
            valid, err = validate_config(bak)
            if not valid:
                continue

            shutil.copy2(OPENCLAW_JSON, OPENCLAW_JSON + ".pre-rollback")
            shutil.copy2(bak, OPENCLAW_JSON)
            log.info(f"Layer 3: 从 {os.path.basename(bak)} 恢复")

            if self._restart_and_verify():
                return True, f"从 {os.path.basename(bak)} 恢复成功"
            else:
                # 这个备份不行，恢复
                shutil.copy2(OPENCLAW_JSON + ".pre-rollback", OPENCLAW_JSON)
                log.warning(f"Layer 3: {os.path.basename(bak)} 恢复后仍不健康")

        return False, "所有 .bak 文件无效"

    def _try_git_local(self):
        rc, stdout, _ = run_cmd(
            "git log --format=%H -5 -- openclaw.json",
            cwd=OPENCLAW_DIR, timeout=10,
        )
        if rc != 0 or not stdout.strip():
            return False, "无 git 历史"

        for commit in stdout.strip().splitlines():
            rc, content, _ = run_cmd(
                f"git show {commit}:openclaw.json",
                cwd=OPENCLAW_DIR, timeout=10,
            )
            if rc != 0:
                continue

            tmp = "/tmp/guardian_recovery.json"
            with open(tmp, "w") as f:
                f.write(content)

            valid, _ = validate_config(tmp)
            if not valid:
                continue

            shutil.copy2(OPENCLAW_JSON, OPENCLAW_JSON + ".pre-rollback")
            shutil.copy2(tmp, OPENCLAW_JSON)
            log.info(f"Layer 3: 从 git commit {commit[:8]} 恢复")

            if self._restart_and_verify():
                return True, f"从 git commit {commit[:8]} 恢复成功"
            else:
                shutil.copy2(OPENCLAW_JSON + ".pre-rollback", OPENCLAW_JSON)

        return False, "git 本地历史中无有效配置"

    def _try_git_remote(self):
        rc, _, _ = run_cmd("git fetch origin", cwd=OPENCLAW_DIR, timeout=30)
        if rc != 0:
            return False, "git fetch 失败"

        rc, content, _ = run_cmd(
            "git show origin/main:openclaw.json",
            cwd=OPENCLAW_DIR, timeout=10,
        )
        if rc != 0:
            return False, "git show origin/main 失败"

        tmp = "/tmp/guardian_recovery.json"
        with open(tmp, "w") as f:
            f.write(content)

        valid, _ = validate_config(tmp)
        if not valid:
            return False, "GitHub 远程配置无效"

        shutil.copy2(OPENCLAW_JSON, OPENCLAW_JSON + ".pre-rollback")
        shutil.copy2(tmp, OPENCLAW_JSON)
        log.info("Layer 3: 从 GitHub 远程恢复")

        if self._restart_and_verify():
            return True, "从 GitHub 远程恢复成功"
        else:
            shutil.copy2(OPENCLAW_JSON + ".pre-rollback", OPENCLAW_JSON)
            return False, "GitHub 远程配置恢复后仍不健康"

    def _restart_and_verify(self):
        """Layer 3 重启请求 — 走统一入口（需 Mudui 确认）"""
        rc, stdout, stderr = run_cmd(
            f"bash {SAFE_RESTART_SCRIPT} --caller guardian --reason 'L3 config rollback verify'",
            timeout=30
        )
        # rc=3 means request filed (pending approval), rc=0 means already pending
        # Either way, Guardian can't restart without Mudui approval
        if rc in (0, 3):
            log.info("Layer 3: 重启请求已提交，等待 Mudui 确认")
        return False  # Always false — actual restart happens after human approval


# ============================================================
# Layer 4: Notifier
# ============================================================

class Notifier:
    def notify_channel(self, message):
        """发送到 #clawd-日志"""
        return self._send_message(DISCORD_LOG_CHANNEL, message[:2000])

    def notify_dm(self, message):
        """DM 通知管理员"""
        for user_id in DISCORD_DM_USERS:
            # 创建 DM channel
            status, resp = http_request(
                "https://discord.com/api/v10/users/@me/channels",
                data={"recipient_id": user_id},
                headers=self._headers(),
                timeout=10,
            )
            if status == 200 and "id" in resp:
                self._send_message(resp["id"], message[:2000])

    def _send_message(self, channel_id, content):
        url = f"https://discord.com/api/v10/channels/{channel_id}/messages"
        status, _ = http_request(
            url, data={"content": content}, headers=self._headers(), timeout=10,
        )
        return status in (200, 201)

    def _headers(self):
        # 每次重新读取 token（config 回滚后 token 可能变化）
        token = _load_discord_token() or DISCORD_BOT_TOKEN
        return {
            "Authorization": f"Bot {token}",
            "Content-Type": "application/json",
        }


# ============================================================
# 状态管理
# ============================================================

def load_state():
    try:
        with open(STATE_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return {}


def save_state(state):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    atomic_write_json(STATE_FILE, state)


# ============================================================
# GuardianAgent 主控制器
# ============================================================

class GuardianAgent:
    def __init__(self, dry_run=False):
        self.dry_run = dry_run
        self.state = load_state()
        self.cooldown = CooldownManager(self.state)
        self.health = HealthChecker()
        self.rollback = RollbackManager(self.cooldown)
        self.notifier = Notifier()
        self.consecutive_failures = self.state.get("consecutive_failures", 0)
        self.last_healthy = self.state.get("last_healthy", None)
        self.cycle_count = 0
        log.info("Guardian 启动 | python=%s | pid=%d", sys.version.split()[0], os.getpid())

    def run_loop(self):
        log.info("Guardian Agent 循环启动 (间隔=%ds)", CHECK_INTERVAL)
        while True:
            try:
                self.run_once()
            except Exception as e:
                log.error(f"Guardian 自身异常: {e}", exc_info=True)
            time.sleep(CHECK_INTERVAL)

    def run_once(self):
        """单次检查与修复"""
        self.cycle_count += 1
        if self.cycle_count % HEARTBEAT_INTERVAL_CYCLES == 0:
            log.info(
                "Guardian 心跳 | cycle=%d | failures=%d | last_healthy=%s",
                self.cycle_count,
                self.consecutive_failures,
                self.last_healthy or "未知",
            )

        result = self.health.check()

        if result["healthy"]:
            if self.consecutive_failures > 0:
                log.info("恢复健康 (之前连续失败 %d 次)", self.consecutive_failures)
            self.consecutive_failures = 0
            self.last_healthy = datetime.now().isoformat()
            self._save()
            return

        self.consecutive_failures += 1
        log.warning(
            "健康检查失败 (%d/%d) process=%s pid=%s",
            self.consecutive_failures, MAX_FAILURES,
            result["process_alive"], result["pid"],
        )

        # 连续失败未达到阈值：仅累计，不做重启（避免瞬时抖动导致网关反复被 SIGTERM）
        if self.consecutive_failures < MAX_FAILURES:
            self._save()
            return

        # 如果重启请求已提交（等待 Mudui 确认），不再升级
        restart_request = os.path.join(OPENCLAW_DIR, "state", "gateway-restart-request.json")
        if os.path.exists(restart_request):
            log.info("重启请求已待审批，等待 Mudui DM 确认，不升级")
            self._save()
            return

        # 连续失败达到阈值，先做一次轻量重启，失败再升级
        log.warning("连续失败 %d 次，开始逐层升级修复", self.consecutive_failures)

        if self.cooldown.can("simple_restart") and not self.dry_run:
            log.info("Layer 1: 连续失败达阈值，执行简单重启")
            recovered = self.health.simple_restart()
            self.cooldown.record("simple_restart")
            if recovered:
                self.consecutive_failures = 0
                self.last_healthy = datetime.now().isoformat()
                log.info("Layer 1: 重启后恢复")
                self._save()
                return
            log.warning("Layer 1: 重启后仍不健康，升级到深度修复")

        if self.dry_run:
            ctx = self.health.collect_context()
            log.info("[DRY RUN] 诊断上下文已收集，不执行修复")
            log.info("[DRY RUN] err_log 尾部: %s", ctx["err_log"][-200:])
            self._save()
            return

        # Layer 1.5: openclaw doctor --fix（可配置）
        if GUARDIAN_ALLOW_DOCTOR_FIX and self.cooldown.can("doctor_fix"):
            log.info("Layer 1.5: 尝试 openclaw doctor --fix")
            rc, stdout, stderr = run_cmd("openclaw doctor --fix --non-interactive", timeout=120)
            self.cooldown.record("doctor_fix")
            log.info("doctor 结果: rc=%d, stdout=%s", rc, stdout[:200] if stdout else "")
            if stderr:
                log.warning("doctor stderr: %s", stderr[:200])

            # doctor 后重启请求 — 走统一入口（需 Mudui 确认）
            self.health._ensure_service_installed()
            rc_restart, _, _ = run_cmd(
                f"bash {SAFE_RESTART_SCRIPT} --caller guardian --reason 'L1.5 doctor fix verify'",
                timeout=30
            )
            if rc_restart in (0, 3):
                log.info("Layer 1.5: doctor 完成，重启请求已提交，等待 Mudui 确认")
                # 不立即标记为成功——等 Mudui 确认重启后才算
                return
            log.warning("Layer 1.5: doctor --fix 后仍不健康，升级到 Layer 3")
        elif not GUARDIAN_ALLOW_DOCTOR_FIX:
            log.warning("Guardian 配置保护：Layer 1.5(doctor) 已禁用")

        # Layer 2 (LLM/Codex) 已移除 — 太慢，不适合守护进程实时恢复

        # Layer 3: .bak 回滚（默认禁用，防止覆盖业务配置）
        if GUARDIAN_ALLOW_LAYER3_ROLLBACK:
            success, desc = self.rollback.rollback()
            if success:
                self.consecutive_failures = 0
                self.last_healthy = datetime.now().isoformat()
                self._save()
                self._notify_success("Layer 3 (回滚)", desc)
                return
            log.error("Layer 3 未能修复: %s", desc)
        else:
            log.warning("Guardian 配置保护：Layer 3(回滚) 已禁用")

        # Layer 4: 通知人工
        if self.cooldown.can("discord_notify"):
            ctx = self.health.collect_context()
            self._notify_failure(ctx)
            self.cooldown.record("discord_notify")

        self._save()

    def _notify_success(self, layer, desc):
        msg = (
            f"**Guardian 自动修复成功**\n"
            f"层级: {layer}\n"
            f"时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
            f"操作: {desc}\n"
            f"结果: Gateway 已恢复正常"
        )
        log.info(msg.replace("\n", " | "))
        self.notifier.notify_channel(msg)

    def _notify_failure(self, ctx):
        err_tail = ctx.get("err_log", "")[-500:]
        health_alerts = ctx.get("health_alerts", [])
        alert_text = "\n".join([f"- {line}" for line in health_alerts]) if health_alerts else "- 无"
        disk_free = HealthChecker._format_bytes(ctx.get("disk_free_bytes"))
        gateway_rss = HealthChecker._format_bytes(ctx.get("gateway_rss_bytes"))
        gateway_uptime = ctx.get("gateway_uptime_seconds")
        gateway_uptime_text = f"{gateway_uptime}s" if gateway_uptime is not None else "未知"
        attempted = "Layer 1(重启)"
        attempted += " → Layer 1.5(doctor)" if GUARDIAN_ALLOW_DOCTOR_FIX else "（doctor 已禁用）"
        attempted += " → Layer 3(回滚)" if GUARDIAN_ALLOW_LAYER3_ROLLBACK else "（回滚已禁用）"
        msg = (
            f"**Guardian 紧急报告 — 需要人工介入**\n"
            f"状态: Gateway 不可用\n"
            f"连续失败: {self.consecutive_failures}次\n"
            f"上次健康: {self.last_healthy or '未知'}\n\n"
            f"额外健康告警:\n{alert_text}\n"
            f"磁盘剩余: {disk_free}\n"
            f"Gateway RSS: {gateway_rss}\n"
            f"Gateway uptime: {gateway_uptime_text}\n\n"
            f"已尝试: {attempted}\n\n"
            f"最近错误:\n```\n{err_tail}\n```\n\n"
            f"建议:\n"
            f"1. `tail -50 ~/.openclaw/logs/gateway.err.log`\n"
            f"2. `openclaw doctor --fix`\n"
            f"3. `cat ~/.openclaw/logs/guardian.log`"
        )
        log.error("Layer 4: 通知人工介入")
        self.notifier.notify_channel(msg[:2000])
        self.notifier.notify_dm(
            f"OpenClaw Gateway 自动修复全部失败，已停机{self.consecutive_failures}轮。"
            f"请查看 #clawd-日志。"
        )

    def _save(self):
        self.state["consecutive_failures"] = self.consecutive_failures
        self.state["last_healthy"] = self.last_healthy
        self.state["cooldowns"] = self.cooldown.to_dict()
        self.state["last_check"] = datetime.now().isoformat()
        save_state(self.state)


# ============================================================
# 入口
# ============================================================

def main():
    # Guardian 必须绕过代理直连（Surge FakeIP 会干扰 health check 和 Discord API）
    for var in ("HTTP_PROXY", "HTTPS_PROXY", "http_proxy", "https_proxy"):
        os.environ.pop(var, None)

    parser = argparse.ArgumentParser(description="OpenClaw Guardian Agent")
    parser.add_argument("--once", action="store_true", help="执行一次检查后退出")
    parser.add_argument("--dry-run", action="store_true", help="只诊断不修复")
    parser.add_argument("--test-notify", action="store_true", help="发送测试通知")
    args = parser.parse_args()

    if args.test_notify:
        n = Notifier()
        ok = n.notify_channel(
            f"**Guardian Agent 测试通知**\n"
            f"时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
            f"状态: 通知系统正常"
        )
        print(f"Discord 通知: {'成功' if ok else '失败'}")
        return

    agent = GuardianAgent(dry_run=args.dry_run)

    if args.once or args.dry_run:
        agent.run_once()
    else:
        agent.run_loop()


if __name__ == "__main__":
    main()
