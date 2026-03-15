# 更新日志

> ClawKing 🦞 — OpenClaw 开箱即用精装版

---

## [Unreleased]


### 🐛 修复（自动记录）

- dashboard download uses tag-based URL with dual-repo fallback, bump version display to v1.4.0


### 🐛 修复（自动记录）

- mixed task log mentions showboat report

---

## [1.4.0] - 2026-03-15

> 门禁体系大升级 + 品牌重塑 + 自动化测试全覆盖

### ✨ 新功能

- **正式更名 ClawKing 🦞**：独立品牌，不再叫 openclaw-starter
- **19 层质量门禁可移植**：门禁脚本不依赖特定机器，任何 ClawKing 安装都能用
- **Gate 6 E2E 感知**：自动检测是否有 Playwright 测试覆盖
- **12 项行为测试 (bats)**：门禁行为在沙盒 git 仓库中真实执行验证
- **ACP 认证引导**：安装时自动检查 ACP 配置，新手不会漏配
- **基建审计工具**：`infra-audit.sh` 一键检查系统健康
- **Gateway 自保护**：防止误操作导致 Gateway 意外停止，内建看门狗自动恢复
- **更新日志自动生成**：commit 后自动同步到 CHANGELOG
- **CI 自动化**：GitHub Actions 持续集成，提交自动跑检查
- **可选 CLI 工具安装**：himalaya、gog、bird、blogwatcher 按需装

### 🐛 修复

- Oracle 审计：修复 3 个 Critical + 2 个 Medium 门禁漏洞
- Guardian 守护进程更稳定，僵尸进程自动清理
- 测试套件全部修复通过（15 项）
- 同步脚本权限修复 + 私有引用清理
- CI 测试 shellcheck 兼容 + git init 分支名修复
- changelog 自动生成改 commit-msg hook，消除 amend 反模式

### 📖 文档

- README 全面重写，面向普通用户，讲人话
- 12 篇工具实战指南：从零开始手把手教你用每个工具
- 三道防线说明：自愈 → Claude 急救 → GitHub 备份
- 最佳模型搭配推荐


### ✨ 新功能（自动记录）

- screenshot dedup — block identical screenshots in spec delivery
- add Gate 6 E2E awareness + 4 bats behavioral tests
- add 12 behavioral hook tests (sandbox git repo execution)

### 🐛 修复（自动记录）

- Oracle R1 — Gate 6 vitest detection + Gate 7 simplify + deep-status bats test
- Oracle audit — close 3 critical + 2 medium gate vulnerabilities
- chmod +x sync-to-template.sh + sanitize private ref
- remove redundant brew install + fix plist glob
- CI shellcheck + macOS pinning + acceptance dir
- repair all 15 bats failures + add CI

### 📖 文档（自动记录）

- 重写更新日志 — 全中文、用户友好、讲人话
- AGENTS.md 自动教训沉淀

### 🔧 维护（自动记录）

- add 3 behavioral tests for screenshot verification gate


### ✨ 新功能（自动记录）

- visual similarity check — ImageMagick RMSE dedup


### 🐛 修复（自动记录）

- Oracle R1 — awk replaces bc, cap 10 images


### 🔧 维护（自动记录）

- auto-generated tests (TDD gate remediation)

---

## [1.3.1] - 2026-03-11

> 首次公开发布，全面清理 + Node v25 升级

### ✨ 新功能

- **一键升级监控面板**：`--update-dashboard` 自动备份、下载、重建、重启
- **代码质量检查**：提交时自动检查语法和格式
- 监控面板和控制台截图加入文档

### 🐛 修复

- Node.js 升级到 v25，性能和兼容性更好
- 监控面板原生模块兼容 M 系列芯片
- 精简默认显示模块，界面更清爽

### 🔒 安全

- 清理所有私有信息，代码库可以安全公开使用
- 技能包脱敏，移除内部引用
- 添加 MIT 开源协议

---

## [1.3.1-rc] - 2026-03-11

> 新功能预览：语音、图片、更多兼容性

### ✨ 新功能

- **语音转文字**：发语音消息自动转文字，完全本地运行
- **图片理解能力**：自动配置 MiniMax 视觉模型
- **搜索能力**：安装时引导配置 Brave Search API
- **飞书优化**：消除偶尔弹出的配对确认窗

### 🐛 修复

- Intel Mac 全面兼容（路径、编译、配置都适配了）
- Guardian 守护默认自动重启
- Tailscale 三重启动保障
- macOS SSH 兼容 Ventura 及更新系统
- 监控面板登录 token 不再被意外覆盖
- 控制台自动生成登录链接

---

## [1.3.0] - 2026-03-10

> 安全大版本：9 项专业安全审查全部通过

### 🔒 安全

- 敏感信息保护：Token 和密码文件写入时自动加密权限
- 卸载安全检查：防止误删重要目录
- 仅本机访问：监控面板和 MCP 不再暴露到局域网
- 移除硬编码密钥：改为安装时手动输入
- Guardian 安全加固：防注入保护

### ✨ 新功能

- Guardian 智能守护：三层自动恢复
- 监控面板可配置：自定义显示哪些工具和模块
- 定时任务自动注册：安装完自动配好 13 个定时任务
- 健康检查脚本：一键检查所有后台服务状态
- 完整卸载：`--uninstall` 一键清理

### 🐛 修复

- 安装完自动打开浏览器
- 端口冲突预检
- 重跑安装不丢失已有 token
- 记忆搜索工具路径迁移到用户目录

---

## [1.2.0] - 2026-03-09

> 远程控制 + 7×24 小时在线

### ✨ 新功能

- 自动检测代理：国内用户安装时自动配置网络代理
- Tailscale 远程控制：不在家也能管理你的 Mac
- 防休眠：Mac 永不休眠，7×24 在线
- SSH 远程访问：自动开启

### 🐛 修复

- 安装过程只需输入一次密码
- 代理配好后自动验证连通性
- 单步失败不中断整体安装
- 私有仓库下载认证修复

---

## [1.1.0] - 2026-03-09

> 零配置，装完就能用

### ✨ 新功能

- MiniMax 模型内置：不需要配任何 AI API Key
- 监控面板自动安装

### 改进

- 安装步骤从 3 步简化到 2 步
- 模型选择更清晰

---

## [1.0.0] - 2026-03-09

> 🦞 首次发布

- The Loop 工作流：AI 协作方法论
- 24 个技能包：写作、编程、研究、运维
- 13 个定时任务模板
- 交互式安装
- 监控面板
- 7 个后台服务模板
