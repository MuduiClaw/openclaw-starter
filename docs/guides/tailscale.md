# Tailscale — 出门在外也能用你的 OpenClaw

## 为什么用它

OpenClaw Gateway 默认跑在本机（127.0.0.1），只能在同一台电脑上用。但你可能想：

- 在手机上通过 Discord 和 AI 对话，AI 需要访问家里电脑上的文件
- 从公司的电脑远程连回家里的 OpenClaw
- 在服务器上跑 Gateway，从任何设备访问

Tailscale 就是解决这个问题的——它创建一个加密的私人网络（VPN），让你的设备之间安全互连。

简单说：**它给你所有设备拉了一条加密专线，走哪儿都能回家。**

---

## 你需要准备什么

📋 清单：
- [Tailscale 账号](https://tailscale.com)（免费计划支持 100 个设备）
- OpenClaw 已安装
- 至少两个设备（比如一台电脑跑 Gateway + 手机或另一台电脑）

---

## 快速开始

### 第一步：安装 Tailscale

macOS：
```bash
# 从 Mac App Store 安装，或者：
$ brew install tailscale
```

Linux：
```bash
$ curl -fsSL https://tailscale.com/install.sh | sh
```

Windows：从 [tailscale.com/download](https://tailscale.com/download) 下载安装包。

手机：App Store / Google Play 搜索 Tailscale。

### 第二步：登录

```bash
$ sudo tailscale up
```

会弹出一个浏览器链接让你登录。登录后这台设备就加入了你的 Tailscale 网络。

**每台要互联的设备都装一遍、登录一遍。**

### 第三步：查看你的设备

```bash
$ tailscale status
```

你会看到每台设备都有一个 `100.x.y.z` 的 IP 地址，这就是 Tailscale 分配的内网 IP。

### 第四步：让 OpenClaw 监听 Tailscale IP

默认 Gateway 只监听 `127.0.0.1`（本机）。要让其他设备通过 Tailscale 访问，需要改绑定地址。

先获取你的 Tailscale IP：

```bash
$ tailscale ip -4
# 输出类似 100.86.78.124
```

然后让 Gateway 监听这个 IP：

```bash
$ openclaw gateway config.patch '{
  "gateway": {
    "bind": "100.86.78.124"
  }
}'
```

把 `100.86.78.124` 替换成你实际的 Tailscale IP。

⚠️ **安全警告：不要用 `0.0.0.0`！** `0.0.0.0` 表示监听所有网络接口，包括公网 IP。如果你的机器有公网 IP 且没有防火墙，Gateway 会直接暴露在互联网上。只绑定 Tailscale IP（`100.x.y.z`），确保只有你的 Tailscale 网络内的设备能访问。

### 第五步：从另一台设备访问

在另一台设备（已装 Tailscale 并登录）上：

```bash
# 假设 Gateway 机器的 Tailscale IP 是 100.86.78.124
$ curl http://100.86.78.124:18789/health
```

看到 `ok` 就通了。

---

## 核心用法

### 远程访问 Dashboard

在浏览器里打开 `http://100.x.y.z:18789/`（替换成你的 Tailscale IP）。

### 远程 SSH

Tailscale 也能帮你 SSH 到远程机器：

```bash
$ ssh user@100.x.y.z
```

不需要端口转发、不需要公网 IP，直接连。

### MagicDNS

如果在 [Tailscale 管理台](https://login.tailscale.com/admin/dns) 开启 MagicDNS，可以用设备名代替 IP：

```bash
$ curl http://my-mac-mini:18789/health
```

---

## 最佳实践

💡 **Gateway Auth Token**：
远程访问时一定要开 Gateway 认证（默认就是开的）。这样即使别人拿到你的 Tailscale IP，没有 Token 也访问不了。

💡 **ACL 控制**：
Tailscale 支持 [ACL 策略](https://tailscale.com/kb/1018/acls)，你可以限制哪些设备能访问 Gateway 端口。

💡 **Exit Node（可选）**：
如果你想让流量都走家里的网络（比如访问家里才能用的服务），可以把 Gateway 机器设为 Exit Node。

💡 **开机自启**：
macOS 上 Tailscale 是常驻应用，默认开机启动。Linux 上确认 systemd 服务在跑：`sudo systemctl enable tailscaled`。

---

## 和 OpenClaw 的集成

### 在 onboarding 时配置

`openclaw onboard` 的高级模式里有 Tailscale 选项。如果你在 onboarding 阶段就配好，会更省事。

### 多设备协同

典型场景：
- **Mac mini 在家跑 Gateway**（7×24 在线）
- **手机上用 Discord** 和 AI 对话
- **笔记本出门** 时通过 Tailscale 远程操作

你在 Discord 里说"帮我查一下本机上的 xxx 文件"，AI 实际在家里的 Mac mini 上执行——你感觉它就在身边。

---

## 常见问题

**Q: Tailscale 安全吗？**
安全。所有流量端对端加密（WireGuard 协议），Tailscale 服务器只做握手协调，不看你的数据。

**Q: 免费够用吗？**
绝大多数场景够。免费计划支持 1 个用户 + 100 个设备。

**Q: 网速会变慢吗？**
通常不会。Tailscale 优先用直连（P2P），只在直连不通时才走中继。延迟通常在 1-10ms。

**Q: 和公司 VPN 冲突吗？**
可能会。如果公司 VPN 接管了所有路由，需要在 Tailscale 或公司 VPN 里配排除规则。

---

## 进阶阅读

- [Tailscale 官方文档](https://tailscale.com/kb/)
- [Tailscale + OpenClaw VPS 部署指南](https://docs.openclaw.ai/vps)
