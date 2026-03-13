# MCP Bridge — 接入外部工具服务

## 为什么用它

OpenClaw 自带很多能力（读写文件、运行命令、浏览器……），但总有覆盖不到的地方。比如你想让 AI：

- 查数据库
- 调公司内部 API
- 连接 Notion、Linear、Jira
- 使用社区开发的工具

MCP（Model Context Protocol）是一个开放标准，让 AI 能连接外部工具服务。你可以理解为 AI 的"USB 接口"——符合标准的工具插上就能用。

简单说：**给 AI 装更多"插件"，扩展它能做的事。**

---

## 你需要准备什么

📋 清单：
- OpenClaw 已安装
- 你想连接的 MCP Server（社区提供或自己开发）
- 对应的 API Key（如果 MCP Server 需要认证）

---

## 快速开始

### 第一步：找一个 MCP Server

MCP Server 社区生态正在快速发展。一些常用的：

| Server | 用途 | 类型 |
|--------|------|------|
| context7 | 代码文档查询 | stdio |
| deepwiki | Wikipedia/知识库查询 | stdio |
| stitch | UI 设计生成 | HTTP |

更多：[MCP Server 目录](https://github.com/modelcontextprotocol/servers)

### 第二步：在 OpenClaw 中配置

在 `openclaw.json` 中添加 MCP Server：

```bash
$ openclaw gateway config.patch '{
  "mcp": {
    "servers": {
      "context7": {
        "command": "npx",
        "args": ["-y", "@context7/mcp-server"]
      }
    }
  }
}'
```

这是 **stdio 模式**——OpenClaw 启动一个本地进程，通过标准输入/输出通信。

### 第三步：验证

在 OpenClaw 对话中问：

> "你现在有哪些 MCP 工具可以用？"

它应该列出刚配好的 MCP Server 提供的工具。

---

## 核心用法

### Stdio 模式（最常见）

MCP Server 作为本地进程运行。OpenClaw 启动它、通过 stdin/stdout 通信：

```json5
{
  "mcp": {
    "servers": {
      "my-server": {
        "command": "node",
        "args": ["path/to/server.js"],
        "env": {
          "API_KEY": "your-key"
        }
      }
    }
  }
}
```

适合：大多数情况。简单、安全、不需要网络。

### HTTP 模式

MCP Server 作为 HTTP 服务运行，OpenClaw 通过 HTTP 调用：

```json5
{
  "mcp": {
    "servers": {
      "remote-server": {
        "url": "http://localhost:3000/mcp",
        "transport": "sse"
      }
    }
  }
}
```

适合：远程服务、共享给多个客户端、需要长驻运行的场景。

### 用 mcporter 管理

OpenClaw 提供了 `mcporter` CLI 来管理 MCP Server：

```bash
# 列出所有已配置的 server
$ mcporter list

# 测试连接
$ mcporter ping my-server

# 列出某个 server 提供的工具
$ mcporter tools my-server
```

---

## 最佳实践

💡 **从小开始**：
不要一次接入 10 个 MCP Server。每个 Server 的工具都会增加 AI 的"选择负担"。先接一两个最需要的。

💡 **环境变量管密钥**：
MCP Server 需要的 API Key，通过环境变量传入，不要写死在配置里：

```json5
{
  "mcp": {
    "servers": {
      "my-server": {
        "command": "node",
        "args": ["server.js"],
        "env": {
          "API_KEY": "${MY_SERVER_API_KEY}"
        }
      }
    }
  }
}
```

💡 **超时设置**：
有些 MCP Server 操作可能很慢（比如查数据库）。设置合理的超时，避免卡住：

```json5
{
  "mcp": {
    "timeout": 30000  // 30 秒
  }
}
```

💡 **安全隔离**：
MCP Server 有权限执行操作。审查你接入的 Server 的代码，确保你信任它。特别是社区提供的 Server——先看源码再用。

---

## 和 OpenClaw 的集成

### 在对话中自然使用

配好 MCP Server 后，在聊天中直接提需求就行。比如配了数据库 Server：

> "帮我查一下 users 表里最近 7 天注册的用户数"

OpenClaw 会自动调用对应的 MCP 工具。

### Skill 联动

一些 OpenClaw Skill 依赖特定的 MCP Server。安装 Skill 时会提示你需要配置哪些 Server。

### Cron 场景

定时任务里也可以用 MCP 工具。比如：
- 每天查一次数据库指标
- 定期同步外部系统的数据

---

## 常见问题

**Q: MCP Server 和 OpenClaw Skill 有什么区别？**
Skill 教 AI "怎么做"（方法论），MCP Server 给 AI "用什么做"（工具能力）。一个是教程，一个是工具箱。

**Q: MCP Server 会占用很多资源吗？**
Stdio 模式的 Server 只在需要时启动。HTTP 模式的 Server 需要长驻运行。资源占用取决于具体 Server 的实现。

**Q: 可以自己开发 MCP Server 吗？**
可以，而且很鼓励。MCP 是开放标准——用 Python（FastMCP）或 Node.js（MCP SDK）都能快速开发。参考 [MCP 官方文档](https://modelcontextprotocol.io)。

**Q: Server 启动失败怎么排查？**
1. 检查 `command` 和 `args` 是否正确
2. 手动运行一遍命令看报错
3. 检查环境变量（特别是 API Key）
4. 查 OpenClaw 日志：`openclaw gateway logs`

---

## 进阶阅读

- [MCP 官方文档](https://modelcontextprotocol.io)
- [MCP Server 目录](https://github.com/modelcontextprotocol/servers)
- [OpenClaw Bridge Protocol 文档](https://docs.openclaw.ai/gateway/bridge-protocol)
- [mcporter Skill](https://clawhub.com)
