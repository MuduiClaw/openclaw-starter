---
name: blueprint-infographic
description: 将任意主题转化为高质量蓝图风格信息图（PNG）。模板驱动 + AI 结构化，5 主题 × 4 布局 × 2 字体 = 40 种视觉变体。当用户说"生成信息图""做一张图""infographic""blueprint""一页总结"时触发。
description_zh: "蓝图风格信息图生成：5 主题 x 4 布局 x 2 字体 = 40 种变体。一句话生成高质量 PNG 信息图。"
---

# Blueprint Infographic Generator

> 将任意主题转化为高质量蓝图风格信息图（PNG）。模板驱动 + AI 结构化，40 种视觉变体。

## 快速使用

### 一键生成（推荐）
```bash
cd ~/clawd/skills/blueprint-infographic
node scripts/generate.mjs "AI时代的个人品牌建设" --output output/result.png
```

### 指定布局 + 主题 + 字体
```bash
node scripts/generate.mjs "主题" \
  --layout hero \
  --theme forest \
  --font handwritten \
  --output output/result.png
```

### 手动 JSON 渲染（精细控制）
```bash
node scripts/render-v2.mjs input.json \
  --layout dense \
  --theme ocean \
  --font handwritten \
  --output output/result.png \
  --html  # 同时保存 HTML 用于调试
```

## 三层架构

```
主题文本 → [AI 结构化] → JSON → [模板渲染] → HTML/CSS → [Playwright] → PNG
           generate.mjs         render-v2.mjs         headless Chromium
```

**解耦设计**：每层可独立使用。可以手写 JSON 跳过 AI，也可以用 AI 生成 JSON 后手动调整再渲染。

## 文件结构

```
skills/blueprint-infographic/
├── SKILL.md                  ← 你在这里
├── design-tokens.json        ← Design OS 设计令牌（主题/字体/布局/常量）
├── .gitignore                ← 排除 output/*.png, fonts/*.ttf
├── schema.json               ← JSON 数据合约（12 种模块类型）
├── scripts/
│   ├── generate.mjs          ← 端到端管线（主题 → PNG）
│   └── render-v2.mjs         ← 渲染器（JSON → PNG，~1700 行）
├── prompts/
│   └── structuring.md        ← AI 结构化 system prompt
├── fonts/
│   ├── XiaolaiSC-Regular.ttf ← 小赖手写字体（21MB, SIL OFL, git-ignored）
│   └── Caveat.ttf            ← 英文手写字体（git-ignored）
├── demo/                     ← 测试 JSON 数据
│   ├── test-action.json      ← 7 模块标准测试
│   ├── test-brand.json       ← 7 模块品牌主题测试
│   ├── test-pm-career.json   ← 7 模块产品经理测试
│   ├── test-5mod.json        ← 5 模块紧凑测试
│   └── test-9mod.json        ← 9 模块密集测试
└── output/                   ← 渲染结果（git-ignored）
```

## 视觉变体系统（4 × 5 × 2 = 40 种）

### 4 种布局架构 (`--layout`)

| 布局 | 标题区 | 网格 | 适合 |
|------|--------|------|------|
| `banner` | 彩色大横幅 | 对称 2-3 列 | 正式报告、公众号头图 |
| `dense` | 纯文字内联标题 | 强制 3 列 + 标尺框 | 技术文档、数据密集 |
| `hero` | 极简标题 | 首模块全宽 + 下方网格 | 核心概念突出 |
| `mosaic` | 薄横幅 | CSS Grid Areas 不对称 | 多维度分析、视觉层次丰富 |

### 5 种配色主题 (`--theme`)

| 主题 | 主色 | 适合 |
|------|------|------|
| `ocean` | `#0F4C81` 深蓝 | 商业战略、严肃分析 |
| `forest` | `#2D6A4F` 深绿 | 成长路径、长期主义 |
| `sunset` | `#C65D07` 橙棕 | 创业行动、变革转型 |
| `slate` | `#475569` 石灰 | 技术系统、中性分析 |
| `blueprint` | `#3FA882` 薄荷绿 | 经典蓝图、品牌一致 |

### 2 种字体 (`--font`)

| 字体 | 中文 | 英文/等宽 | 适合 |
|------|------|-----------|------|
| `default` | Noto Sans SC | IBM Plex Mono | 正式、专业 |
| `handwritten` | 小赖字体 (Xiaolai) | Caveat | 小红书、社交媒体、亲和力 |

### 选择优先级
CLI 参数 > JSON 数据字段 > 自动选择（AI 根据内容情感选主题/布局，无指定时 fallback 到 ocean/banner）

## 12 种模块类型

| 类型 | 用途 | 推荐 span |
|------|------|-----------|
| `matrix` | 2×2 四象限分类 | — |
| `timeline` | 时间线/阶段演进 | — |
| `breakdown` | 分层结构/深度分解 | **tall** |
| `loop` | 闭环系统/飞轮 | — |
| `warning` | 风险/反模式警示 | **wide** |
| `stats` | 3 个关键指标数据 | — |
| `progress` | 多维度评分/进度 | wide |
| `comparison` | 两方案对比 | — |
| `pyramid` | 优先级金字塔 | — |
| `chart` | 柱状/折线趋势图 | — |
| `flowchart` | 步骤流程 | — |
| `checklist` | 执行检查清单 | — |

## JSON 数据格式

```json
{
  "title": "主标题",
  "subtitle": "副标题 — 一句话核心判断",
  "theme": "ocean",           // 可选，覆盖自动选择
  "layout": "hero",           // 可选，覆盖自动选择
  "fontStyle": "handwritten", // 可选
  "modules": [
    {
      "slot": "A-01",
      "type": "matrix",
      "title": "模块标题",
      "span": "tall|wide",    // 可选
      "content": { ... }      // 类型特定，见 schema.json
    }
  ]
}
```

## AI 管线参数

- **模型**: `claude-sonnet-4-5` via Antigravity (`http://127.0.0.1:8045/v1`)
- **结构化 prompt**: `prompts/structuring.md`
- **输出归一化**: 自动处理 `data→content` 重映射、缺失 title、span 清理
- **温度**: 0.7

## 嵌入其他流程

### 作为博客配图
```bash
# 博客翻译完成后，用文章标题生成配图
node scripts/generate.mjs "文章标题" \
  --theme ocean --font default \
  --output /path/to/blog-cover.png
```

### 作为 Cron 任务调用
在 cron agentTurn prompt 中：
```
用 blueprint-infographic skill 为这篇文章生成信息图：
cd ~/clawd/skills/blueprint-infographic && node scripts/generate.mjs "主题"
```

### 输出到媒体目录（供 message tool 发送）
```bash
node scripts/generate.mjs "主题" \
  --output ~/.openclaw/media/outgoing/general/infographic.png
```

## 依赖

- Node.js 24+
- Playwright（`/opt/homebrew/lib/node_modules/playwright`）
- Antigravity API（本地反代 :8045）
- 小赖字体（`~/Library/Fonts/XiaolaiSC-Regular.ttf`，handwritten 模式需要）
- Google Fonts CDN（Noto Sans SC / IBM Plex Mono / Caveat）

## Design Tokens（设计令牌）

所有设计决策集中在 `design-tokens.json`，遵循 Design OS 原则：**设计决策和实现分离。**

```json
{
  "base": { ... },      // 共享中性底色（暖米纸背景、灰度色阶）
  "themes": { ... },    // 5 种配色主题（ocean/forest/sunset/slate/blueprint）
  "fonts": { ... },     // 2 种字体配置（default/handwritten）
  "layouts": { ... },   // 4 种布局架构（banner/dense/hero/mosaic）
  "constants": { ... }, // 全局常量（黑/白/红/边框色）
  "sizes": { ... }      // 画布尺寸（default 1200×1600 / xhs 1080×1440）
}
```

**扩展方式**：新增主题/布局/字体只需编辑 JSON，不需改渲染器代码。渲染器启动时自动加载 design-tokens.json 并解析继承关系（`"extends": "base"` 的主题自动合并共享底色）。

## 设计规格

- 画布宽度: 750px，高度自适应内容
- 背景: `#E4DED2` 网格纸质感 + 噪点纹理
- 卡片: 白色/奶油底，3px 黑边，6px 硬阴影
- 模块头: 34px 黑色背景 + 白色中文标题 + SVG 图标
- 角标: L 形括号装饰
- 字体: 900-weight 粗标题，无衬线正文
- SVG 图标库: 19 个内联线条图标（cross/check/warn/star/arrow/skull/gear/person/book/code/chart/target/lightning/lock/rocket/scissors/play/flag/search）

## 质量标准

- 每张图 400-600KB PNG
- 所有文字清晰可读，对比度达标
- 模块间信息密度一致（不允许半空模块）
- 中文为主，无装饰性英文
- 配色跟随主题系统，无突兀色块
