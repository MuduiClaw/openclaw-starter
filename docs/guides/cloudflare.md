# Cloudflare — 网站部署 + CDN + 图床

## 为什么用它

你用 OpenClaw + Codex/Claude Code 写了一个网站或应用，需要部署到线上让人访问。Cloudflare 是最省心的选择之一：

- **Pages**：Git push 自动部署，免费 HTTPS
- **R2**：对象存储，适合当图床或文件存储
- **Workers**：serverless 函数（可选，进阶）

免费额度对个人项目绑绑有余。

简单说：**代码写完，推到 GitHub，网站自动上线。**

---

## 你需要准备什么

📋 清单：
- [Cloudflare 账号](https://dash.cloudflare.com/sign-up)（免费）
- 一个 GitHub 仓库（参考 [GitHub 指南](github.md)）
- （可选）一个域名

---

## 快速开始

### 第一步：安装 Wrangler CLI

```bash
$ npm install -g wrangler
```

> 💬 **npm 不熟？** 见 [从零开始](prerequisites.md#nodejs--很多工具的地基)。

### 第二步：登录

```bash
$ wrangler login
```

浏览器会弹出授权页面。确认后就可以了。

### 第三步：部署你的第一个网站（Pages）

如果你已经有一个静态网站项目（比如 React / Vue / Astro）：

```bash
$ cd your-project
$ wrangler pages deploy ./dist
```

或者通过 Cloudflare Dashboard 连接 GitHub 仓库：

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com)
2. 左侧菜单 → **Workers & Pages**
3. 点击 **Create application → Pages → Connect to Git**
4. 选择你的 GitHub 仓库
5. 配置构建命令（比如 `npm run build`）和输出目录（比如 `dist`）
6. 部署

以后每次 `git push`，网站自动更新 🎉

---

## 核心用法

### Pages — 网站部署

最核心的功能。支持所有主流前端框架：

```bash
# 本地预览
$ wrangler pages dev ./dist

# 手动部署
$ wrangler pages deploy ./dist

# 查看部署状态
$ wrangler pages deployment list
```

连接 GitHub 后是全自动的——推代码就部署，不需要额外操作。

### R2 — 对象存储 / 图床

R2 是 Cloudflare 的对象存储（兼容 S3 API），免费额度很慷慨：
- 10GB 存储
- 1000 万次读取/月
- 100 万次写入/月

创建一个 R2 Bucket：

```bash
$ wrangler r2 bucket create my-images
```

上传文件：

```bash
$ wrangler r2 object put my-images/photo.jpg --file ./photo.jpg
```

设置公开访问（当图床用）：
在 Dashboard → R2 → 你的 Bucket → Settings → Public access → 开启自定义域名。

### 自定义域名

1. 在 Cloudflare 添加你的域名
2. 在域名注册商处修改 DNS 指向 Cloudflare
3. 在 Pages 项目里绑定自定义域名

全程免费，自动配 HTTPS。

---

## 最佳实践

💡 **Git Push 自动部署**：
这是最推荐的方式。连接 GitHub，配一次构建命令，以后永远不用手动部署。

💡 **环境变量管理**：
构建时需要的环境变量（比如 API 地址），在 Pages 的 Settings → Environment variables 里配置。不要写死在代码里。

💡 **R2 当图床**：
配合自定义域名（比如 `img.your-domain.com`），R2 是免费又快的图床方案。支持全球 CDN 加速。

💡 **Wrangler API Token**：
如果需要在 CI/CD 或 OpenClaw 里自动操作 Cloudflare，创建一个 API Token：
Dashboard → My Profile → API Tokens → Create Token

存到 1Password（参考 [1Password 指南](1password.md)）。

---

## 和 OpenClaw 的集成

### 自动部署流程

典型流程：
1. 你在 Discord 里说"帮我改一下首页的标题"
2. OpenClaw 调 Codex/Claude Code 改代码
3. 代码推到 GitHub
4. Cloudflare Pages 自动部署
5. OpenClaw 用浏览器打开验证（参考 [Browser 指南](browser.md)）

### R2 上传

OpenClaw 可以直接用 `wrangler` 或 S3 API 上传文件到 R2。比如生成了一张图片，直接传到图床拿 URL。

### mudui-r2-uploader Skill

如果你经常需要上传图片到 R2，OpenClaw 有现成的 Skill 自动化这个过程。

---

## 常见问题

**Q: 免费额度够用吗？**
个人项目完全够。Pages 无限站点、无限带宽；R2 10GB 存储 + 海量读取。超出后按量计费也很便宜。

**Q: 和 Vercel / Netlify 比怎么样？**
功能类似，各有优势。Cloudflare 的优势是免费额度更大、全球 CDN 网络更广、还有 R2 和 Workers 的生态。

**Q: 域名必须转到 Cloudflare 吗？**
不必须。但转过来可以用 Cloudflare 的 DNS 管理，更方便。只用 Pages 的话不转也行。

**Q: R2 和 S3 兼容吗？**
完全兼容 S3 API。现有的 S3 工具（AWS CLI、各种 SDK）改个 endpoint 就能用。

---

## 进阶阅读

- [Cloudflare Pages 文档](https://developers.cloudflare.com/pages/)
- [Cloudflare R2 文档](https://developers.cloudflare.com/r2/)
- [Wrangler CLI 文档](https://developers.cloudflare.com/workers/wrangler/)
