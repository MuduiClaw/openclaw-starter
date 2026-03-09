---
job_id: "a7b37986-c16c-4048-af99-de30f71b3c5e"
version: "v1.0.0"
name: "CF Blog Scanner"
model: "google/gemini-3-flash-preview"
thinking: "medium"
timeout: 420
schedule: "50 8,14,20,2 * * *"
schedule_tz: "Asia/Shanghai"
session_target: "isolated"
enabled: true
synced_at: "2026-03-01T07:56:54Z"
---

📋 **执行纪律**：开始任务前，先 `read ~/clawd/prompts/cron/_loop-discipline.md`，严格遵守其中的 Loop 规则。

⛔ 这不是心跳检查。禁止回复 HEARTBEAT_OK。

🔒 CF Blog Scanner（v5 自启浏览器 + 8 交易所）

强约束：
- 所有 `message(action=send)` 必须使用 `target` 字段（不是 `to`）
- 所有 `sessions_spawn` 必须指定 `model: "sonnet"`

Step 1) 扫描
- `exec`: `cd $HOME/clawd && python3 scripts/cf-blog-scanner.py --scan 2>&1`
- 解析 JSON 输出
- 检查 `blogs_error > 0` → 发告警到 `channel:1468286777419890804`：
  `⚠️ [CF Scanner] {N} 个博客扫描失败：{error_details}`
- `count=0`（无新文章）→ 输出 `CF_SCANNER_DONE new=0 sent=0 deep=0 skipped=0 errors={blogs_error}` 然后结束

Step 2) 过滤与路由
对每篇新文章：
- 过滤噪音：活动/招聘/常规公告/法律声明/SEO 入门/通用教程（What is Bitcoin 等）
- 路由规则：所有交易所文章 → `message`(target: "channel:1468502290896912414")

Step 3) 输出
- 普通价值：发快报（[博客名] 标题 + 链接 + 1-2 句中文摘要）
- 高价值（产品发布/战略级/AI 相关）：`sessions_spawn` 深度处理（必须传 model: "sonnet"）

注意：脚本自带 Playwright Chromium，不需要 openclaw browser。扫描 7 个源：BitMart Academy / Bitget / Binance / Phemex Blog + Academy / Gate / KuCoin。（OKX 2026-03-05 暂停：www.okx.com DNS 坏了，OKX 动态由 X watchlist + web search 覆盖）

最终仅输出 1 行：
`CF_SCANNER_DONE new=<数量> sent=<快报数> deep=<spawn数> skipped=<过滤数> errors=<报错博客数>`