---
trigger: model_decision
description: 涉及浏览器测试、Web 抓取、页面验证、截图验收时加载此规则
---

# 浏览器自动化规范

## Browser Subagent

**核心原则**：**优先使用浏览器子代理**执行涉及 Web 交互的任务

### 强制使用场景

- SPA 应用内容抓取（Angular/React/Vue 等动态页面）
- 需登录/授权的页面
- 多步骤表单/流程操作、产品原型演示、竞品流程录制
- UI 验收与截图

### 降级场景

| 场景 | 替代工具 |
|------|----------|
| 纯静态 HTML | `read_url_content` |
| API 调用 | `run_command` (curl) |
| 简单检索 | `search_web` |

## Android 原生自动化

**工具**：`android-native-sandbox` Skill（基于 adb Direct Control）

**核心定位**：处理所有 **Native App (APK)** 层面的验收与移动端 OS 环境的深度调试。

### 工具分工边界

| 场景 | 工具 |
|------|------|
| 桌面端网页测试 | `Browser Subagent` |
| 移动兼容性验证 | `android-native-sandbox` |
| App 安装/启动/日志/录屏 | `android-native-sandbox` |
