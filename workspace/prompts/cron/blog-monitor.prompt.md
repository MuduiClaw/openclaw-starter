---
job_id: "3e9af55e-5be6-4869-b290-8c0b8838a541"
version: "v1.0.0"
name: "Blog Monitor"
model: "google/gemini-3-flash-preview"
thinking: "high"
timeout: 1800
schedule: "20 6,12,18,0 * * *"
schedule_tz: "Asia/Shanghai"
session_target: "isolated"
enabled: true
synced_at: "2026-03-01T07:56:54Z"
---

📋 **执行纪律**：开始任务前，先 `read ~/clawd/prompts/cron/_loop-discipline.md`，严格遵守其中的 Loop 规则。

⛔ 这不是心跳检查。禁止回复 HEARTBEAT_OK。

📰 Blog Monitor（v22 行动者模式）

强约束：
- 所有 `message(action=send)` 必须使用 `target` 字段，禁止用 `to`
- 只允许用数字 ID 执行 `blogwatcher read <ID>`，禁止标题当参数
- 所有 `sessions_spawn` 必须指定 `model: "sonnet"`

Step 0) 浏览器预检（可失败）
- `browser` status、若未就绪尝试 start，失败不阻断

Step 1) 扫描
- `exec`: `export PATH="$HOME/go/bin:$PATH"; blogwatcher scan -w 4 2>&1`
- `exec`: `export PATH="$HOME/go/bin:$PATH"; blogwatcher articles 2>&1`
- 若无 unread：输出 DONE（handled=0）

🔄 Step 2-3 主循环
一篇一篇处理，处理完一篇再处理下一篇，直到全部清完或接近超时（留 120s 缓冲）。
每处理 5 篇后，重新执行 `blogwatcher articles` 刷新未读列表。

  对每篇：
  1. URL 去重：检查 `$HOME/clawd/.state/blog-monitor-sent-urls.txt`
     - 若文件不存在，先创建
     - URL 已存在：`skipped += 1`，`blogwatcher read <ID>` 标记已读，跳过
  2. 标题级过滤噪音（活动/招聘/纯前端实现细节）
  3. 路由：
     - source=OpenClaw/openclaw → `channel:1468286777419890804`
     - 其他 → `channel:1468502290896912414`
  4. 抓取正文（降级链）：`web_fetch`(12000) → `browser snapshot`(10000) → `exec crawl4ai`(10000)
  5. 判断输出策略：
     - 快报级：直接发 2-3 句中文摘要到 Discord
     - 深度级：分两阶段执行

       **阶段 A：Subagent 翻译**（`sessions_spawn`，model: "sonnet"）
       subagent 只负责翻译+图片抓取+写文件，不负责发送。
       task 必含翻译规则（参考 `$HOME/clawd/docs/blog-translation-spec.md`）：
       ▸ 全文翻译 + 核心要点(5-8条) + 深度解读(2-4段经营者视角)
       ▸ 人名/公司名/产品名翻译前查证，不靠音译猜
       ▸ 外文引用只保留中文翻译，不搞中英对照
       ▸ 技术术语(MoE/RAG等)保留英文不强翻
       ▸ title 用中文重写体现 用户视角，不是原标题直译
       ▸ frontmatter: title/author(user)/source/source_author/date/content_seed:true
       ▸ 📷 图片抓取（强制）：
         - 从抓取的原文 HTML 中提取所有 img src URL
         - `exec`: `mkdir -p $HOME/clawd/output/blog-translations/images`
         - 对每张图 `exec`: `curl -sL -o $HOME/clawd/output/blog-translations/images/{slug}-{序号}.{ext} "{图片URL}" 2>&1`
         - 在 markdown 中用相对路径引用: `![描述](images/{slug}-{序号}.{ext})`
         - 下载失败时保留原始 URL 作为 fallback，不阻断
       ▸ 写入 `$HOME/clawd/output/blog-translations/YYYY-MM-DD-slug.md`
       ▸ subagent 完成后返回：文件路径 + 中文标题 + slug

       **阶段 B：主 session 后处理**（subagent 返回后由 Blog Monitor 主 session 执行）
       ▸ 📊 信息图生成（强制，深度级必做）：
         1. `exec`: `cd $HOME/clawd/skills/blueprint-infographic && node scripts/generate.mjs "{中文标题}" --output $HOME/.openclaw/media/outgoing/general/{slug}-infographic.png 2>&1`
            - 超时 120s，失败不阻断
         2. infographics 计数 +1
       ▸ 📤 上传图片到 R2 图床：
         对每张 `$HOME/clawd/output/blog-translations/images/{slug}-*` 的图片：
         `exec`: `source ~/.config/openclaw/cloudflare-r2.env && node /opt/homebrew/lib/node_modules/wrangler/bin/wrangler.js r2 object put "YOUR_R2_BUCKET/blog/2026/{slug}/{filename}" --file "{本地图片路径}" --remote 2>&1`
         URL 格式：`https://YOUR_IMAGE_CDN/blog/2026/{slug}/{filename}`
       ▸ 发 Discord 全文（翻译+信息图+R2 上传全部完成后统一发）：
         **必须把全文翻译+核心要点+深度解读的完整内容分段发到 Discord 消息中，含图片。**
         步骤：
         1. 读取翻译 .md 文件内容（去掉 frontmatter）
         2. **图文分离**：从文本中移除所有图片引用 `![desc](images/xxx)`，记录每张图片在哪个章节后出现
         3. 按 ### 章节拆分纯文字内容，每条 Discord 消息 ≤1900 字符
         4. 第一条消息加标题头：`📚 **深度翻译全文 | {中文标题}**\n原文：<{URL}>\n**（1/N）...**`
         5. 后续消息加编号：`**（2/N）章节名**`
         6. **发完每段文字后，紧接着发该段对应的图片**：每张图片单独一条消息，内容只有 R2 裸 URL（如 `https://YOUR_IMAGE_CDN/blog/2026/{slug}/{filename}`），Discord 会自动嵌入图片。一条消息可放多个 URL（每个 URL 独占一行，最多 4 个）
         7. 所有消息发到：`message`(action: send, channel: discord, target: "channel:1468502290896912414")
         8. 最后发信息图（如果生成成功）：`message`(action: send, channel: discord, target: "channel:1468502290896912414", message: "📊 信息图 ↑", filePath: "$HOME/.openclaw/media/outgoing/general/{slug}-infographic.png")
         **禁止只发摘要。禁止只发文件附件。必须把全文+图片直接发成 Discord 消息。**
       ▸ 同步到 Google Drive（博客译文文件夹 ID: `1cM92zayQtXiHifOCuR323SHheluy1Mct`）：
         1. `exec`: `pandoc {文件路径} -o /tmp/{slug}.docx --from markdown --to docx --resource-path=$HOME/clawd/output/blog-translations/ 2>&1`
            ⚠️ --resource-path 确保 pandoc 找到 images/ 子目录中的图片并嵌入 docx
         2. `exec`: `GOG_KEYRING_BACKEND=file GOG_KEYRING_PASSWORD=REDACTED_GOG_PASSWORD gog drive upload /tmp/{slug}.docx --parent 1cM92zayQtXiHifOCuR323SHheluy1Mct --convert --name "{title}" 2>&1`
         3. 上传失败不阻断流程，记录错误继续
       ▸ ⚡ 原创价值评估：
         - 评估标准：是否触及 用户关注的核心领域 + 独特视角 + 具体数据/案例
         - 如果值得：追加到 `content-pipeline/captures/YYYY-MM-DD.md`
         - 如果不值得：跳过，不强凑
  7. 成功后 `blogwatcher read <ID>` + URL 追加去重文件
  8. 失败则发错误到 `channel:1468286777419890804`，继续下一篇

Step 4) 结束汇总（必须）
`BLOG_MONITOR_DONE total_start=<初始未读> handled=<处理> skipped=<跳过> deep=<spawn数> infographics=<信息图数> seeds=<内容种子数> remaining=<剩余> error=<0|1>`