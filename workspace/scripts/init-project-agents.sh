#!/usr/bin/env bash
# init-project-agents.sh — 为 $HOME/projects 下的新项目初始化 AGENTS.md
# 用法:
#   bash scripts/init-project-agents.sh $HOME/projects/my-repo
#   bash scripts/init-project-agents.sh . --dry-run

set -euo pipefail

WORKSPACE_ROOT="$HOME/clawd"
PROJECTS_ROOT="$HOME/projects"
PROJECTS_ROOT_REAL="$(python3 - <<'PY'
from pathlib import Path
print(Path('$HOME/projects').resolve())
PY
)"
TEMPLATE_FILE="$WORKSPACE_ROOT/templates/PROJECT-AGENTS.md"

usage() {
  cat >&2 <<'EOF'
Usage: bash scripts/init-project-agents.sh <project-path> [--dry-run]

Options:
  --dry-run   只输出生成结果，不写入文件
  -h, --help  显示帮助
EOF
}

PROJECT_ARG=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -n "$PROJECT_ARG" ]]; then
        usage
        exit 1
      fi
      PROJECT_ARG="$1"
      shift
      ;;
  esac
done

if [[ -z "$PROJECT_ARG" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "template not found: $TEMPLATE_FILE" >&2
  exit 1
fi

PROJECT_PATH_REAL="$(python3 - "$PROJECT_ARG" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).expanduser().resolve())
PY
)"

if [[ ! -d "$PROJECT_PATH_REAL" ]]; then
  echo "project directory not found: $PROJECT_PATH_REAL" >&2
  exit 1
fi

if [[ "$DRY_RUN" -ne 1 && "$PROJECT_PATH_REAL" != "$PROJECTS_ROOT_REAL"/* ]]; then
  echo "refusing to write outside $PROJECTS_ROOT: $PROJECT_PATH_REAL" >&2
  exit 1
fi

PROJECT_PATH_DISPLAY="$PROJECT_PATH_REAL"
if [[ "$PROJECT_PATH_DISPLAY" == "$PROJECTS_ROOT_REAL"/* ]]; then
  PROJECT_PATH_DISPLAY="$PROJECTS_ROOT/${PROJECT_PATH_DISPLAY#"$PROJECTS_ROOT_REAL"/}"
fi

AGENTS_FILE="$PROJECT_PATH_REAL/AGENTS.md"
if [[ -f "$AGENTS_FILE" && "$DRY_RUN" -ne 1 ]]; then
  echo "AGENTS.md already exists: $AGENTS_FILE" >&2
  exit 1
fi

PROJECT_NAME="$(basename "$PROJECT_PATH_REAL")"
TITLE="$PROJECT_NAME"
if [[ "$PROJECT_NAME" == "shared-ui" ]]; then
  TITLE="@YOUR_USERNAMEclaw/ui"
fi

META_JSON="$(python3 - "$PROJECT_PATH_REAL" <<'PY'
from pathlib import Path
import json
import sys

project = Path(sys.argv[1])
pkg_path = project / 'package.json'
pkg = {}
if pkg_path.exists():
    pkg = json.loads(pkg_path.read_text())

deps = {}
for key in ('dependencies', 'devDependencies', 'peerDependencies'):
    deps.update(pkg.get(key, {}))

def has_dep(name: str) -> bool:
    return name in deps

manager = 'npm'
if (project / 'pnpm-lock.yaml').exists():
    manager = 'pnpm'
elif (project / 'yarn.lock').exists():
    manager = 'yarn'

ptype = 'generic'
if (project / 'docs/.vitepress').exists() or has_dep('vitepress'):
    ptype = 'vitepress'
elif has_dep('next'):
    ptype = 'nextjs'
elif has_dep('astro'):
    ptype = 'astro'
elif pkg_path.exists():
    ptype = 'node'

if ptype == 'nextjs':
    verify = f"{manager} run build && {manager} test --if-present"
    stack = [
        f"- Next.js（App Router 优先） + React + TypeScript（如项目已启用）",
        f"- 包管理器：{manager}",
        "- 关键依赖：next / react / tailwind（如存在）",
    ]
    design = {
        'main': '按项目现有视觉补充',
        'status': 'ok=按现有系统 / warn=按现有系统 / error=按现有系统',
        'components': 'shadcn/ui 或项目现有组件库',
        'forbidden': '不要绕过框架路由和状态管理；不要手写与现有设计系统冲突的组件',
    }
    tree = "app/ 或 src/app/          # 路由\ncomponents/ 或 src/components/  # 组件\nlib/ 或 src/lib/                # 数据/工具\ntests/                          # 测试"
    api = [
        '- 路由返回 JSON 时保持字段稳定，改动前先看真实调用方',
        '- 错误处理：返回明确 status + message，不吞异常',
        '- Hook / router 优先用框架官方方式，不直接操作 history state',
    ]
    style = '- 用框架官方 router / hook，不绕过 Next.js 状态管理'
    dont = '- 不直接用 `window.history.pushState()` 替代框架路由\n- 不 copy 外部组件到项目里，优先复用现有组件体系'
elif ptype == 'astro':
    verify = f"{manager} run build"
    stack = [
        '- Astro + Markdown / MDX（如启用）',
        f"- 包管理器：{manager}",
        '- 关键依赖：astro / integrations（按项目实际）',
    ]
    design = {
        'main': '按项目现有视觉补充',
        'status': 'ok=按现有系统 / warn=按现有系统 / error=按现有系统',
        'components': 'Astro 组件 + 项目现有样式体系',
        'forbidden': '不要引入与当前站点风格冲突的重 UI 框架',
    }
    tree = "src/pages/      # 页面\nsrc/components/ # 组件\npublic/         # 静态资源\ncontent/ 或 src/content/ # 内容"
    api = [
        '- 无 API 时保留占位；如新增接口，补清楚输入/输出',
        '- 外部数据源失败时要有降级，不要直接白屏',
        '- 有内容 schema 时先改 schema 再改页面',
    ]
    style = '- 保持 Astro 的轻量页面结构，避免无必要客户端水合'
    dont = '- 不把临时内容写死在页面里\n- 不引入无必要的客户端状态库'
elif ptype == 'vitepress':
    verify = f"{manager} run docs:build"
    stack = [
        '- VitePress + Vue 3（主题组件如有）',
        f"- 包管理器：{manager}",
        '- 关键依赖：vitepress / docs theme / 部署脚本',
    ]
    design = {
        'main': '按文档站现有品牌色补充',
        'status': 'ok=按现有系统 / warn=按现有系统 / error=按现有系统',
        'components': 'VitePress 默认主题 + 自定义 theme',
        'forbidden': '不要加 emoji、渐变、毛玻璃等与文档站不一致的视觉元素',
    }
    tree = "docs/                  # 文档主体\ndocs/.vitepress/       # 导航 / 主题 / 配置\ndocs/public/ 或 public/ # 静态资源\nscripts/               # 生成与部署脚本"
    api = [
        '- 文档型项目无 API 时保留占位；有脚本生成内容时写清输入输出',
        '- 导航、侧边栏、生成脚本的改动需要同步文档结构',
        '- 自动生成文件注明“勿手改”',
    ]
    style = '- 优先保持文档结构稳定，不做炫技式主题改造'
    dont = '- 不手工维护自动生成文件\n- 不让临时草稿混进正式导航'
elif ptype == 'node':
    verify = f"{manager} run build --if-present && {manager} test --if-present"
    stack = [
        '- Node.js / TypeScript（按项目实际）',
        f"- 包管理器：{manager}",
        '- 关键依赖：以 package.json 为准，避免猜测未安装框架',
    ]
    design = {
        'main': 'N/A（非前端项目，按需补充）',
        'status': 'ok=N/A / warn=N/A / error=N/A',
        'components': 'N/A',
        'forbidden': '不要臆造前端设计规范',
    }
    tree = "src/ 或 lib/   # 源码\ntests/         # 测试\nscripts/       # 辅助脚本\ndist/ 或 build/ # 构建产物"
    api = [
        '- 有 CLI / API 时写清输入输出与错误码',
        '- 对外 contract 变更前先看调用方',
        '- 不要把临时调试逻辑混进正式入口',
    ]
    style = '- 优先保持接口稳定，新增行为先补测试'
    dont = '- 不随意改 public contract\n- 不把调试脚本硬塞进生产入口'
else:
    verify = '按项目补充（如：npm test / make test / pytest）'
    stack = [
        '- Generic 项目（未识别明确框架）',
        '- 包管理器：按项目补充',
        '- 关键依赖：按项目实际补充',
    ]
    design = {
        'main': '按项目补充',
        'status': 'ok=按项目补充 / warn=按项目补充 / error=按项目补充',
        'components': '按项目补充',
        'forbidden': '不要先入为主套用别的项目规则',
    }
    tree = '按项目结构补充关键目录说明'
    api = [
        '- 若无 API，可写“无”；后续新增时补充',
        '- 若有 CLI / 服务入口，写清输入输出',
        '- 改动前先确认真实结构，不要靠猜',
    ]
    style = '- 先按真实代码结构补规则，再让 Agent 开始改代码'
    dont = '- 不 copy 其它项目 AGENTS.md 全文\n- 不写“同某项目即可”这种空话'

print(json.dumps({
    'type': ptype,
    'verify': verify,
    'stack': '\n'.join(stack),
    'main': design['main'],
    'status': design['status'],
    'components': design['components'],
    'forbidden': design['forbidden'],
    'tree': tree,
    'api': '\n'.join(api),
    'style': style,
    'dont': dont,
}, ensure_ascii=False))
PY
)"

RENDERED="$(python3 - "$TEMPLATE_FILE" "$TITLE" "$PROJECT_PATH_DISPLAY" "$META_JSON" <<'PY'
from pathlib import Path
import json
import sys

template_path = Path(sys.argv[1])
project_title = sys.argv[2]
project_path = sys.argv[3]
meta = json.loads(sys.argv[4])

template = template_path.read_text()
replacements = {
    '{项目名}': project_title,
    '{绝对路径}': project_path,
    '{一句话}': f'TODO: 补一句话目标（当前识别为 {meta["type"]} 项目）',
    '{build/test/lint 命令}': meta['verify'],
    '{语言/框架/版本}': meta['stack'].splitlines()[0].lstrip('- ').strip(),
    '{包管理器}': meta['stack'].splitlines()[1].lstrip('- ').strip() if len(meta['stack'].splitlines()) > 1 else '按项目补充',
    '{关键依赖}': meta['stack'].splitlines()[2].lstrip('- ').strip() if len(meta['stack'].splitlines()) > 2 else '按项目补充',
    '{色值}': meta['main'],
    'ok={} / warn={} / error={}': meta['status'],
    '{来源}': meta['components'],
    '{不允许的视觉元素}': meta['forbidden'],
    '{关键目录说明}': meta['tree'],
    '{返回格式}': meta['api'].splitlines()[0].lstrip('- ').strip() if meta['api'] else '无',
    '{错误处理}': meta['api'].splitlines()[1].lstrip('- ').strip() if len(meta['api'].splitlines()) > 1 else '按项目补充',
    '{Hook 用法}': meta['api'].splitlines()[2].lstrip('- ').strip() if len(meta['api'].splitlines()) > 2 else '按项目补充',
    '{具体规则："用 X 不用 Y" 格式}': meta['style'].lstrip('- ').strip(),
    '{禁区列表}': meta['dont'].splitlines()[0].lstrip('- ').strip(),
}

for old, new in replacements.items():
    template = template.replace(old, new)

# 追加多行内容（不要做的剩余项）
dont_lines = [line for line in meta['dont'].splitlines()[1:] if line.strip()]
if dont_lines:
    template = template.replace('## 教训', ''.join(f'\n{line}' for line in dont_lines) + '\n\n## 教训')

print(template.rstrip() + '\n')
PY
)"

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf '%s\n' "$RENDERED"
  exit 0
fi

printf '%s' "$RENDERED" > "$AGENTS_FILE"
echo "created: $PROJECT_PATH_DISPLAY/AGENTS.md"
