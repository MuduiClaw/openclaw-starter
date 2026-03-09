#!/usr/bin/env bash
# agents-md-scanner.sh — 扫描 $HOME/projects 下所有 git 项目的 fix/revert commit，输出教训候选 JSON
# 用途：cron 日扫描 + 手动触发
# 输出 JSON 数组，每条包含 project/commit/message/files/diff_stat

set -euo pipefail

PROJECTS_DIR="$HOME/projects"
SINCE="${1:-yesterday}"

discover_projects() {
  find "$PROJECTS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | while IFS= read -r dir; do
    [[ -d "$dir/.git" ]] || continue
    printf '%s\n' "$dir"
  done
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

printf '[\n'
first=true

while IFS= read -r dir; do
  [[ -n "$dir" ]] || continue
  proj="$(basename "$dir")"

  commits="$(cd "$dir" && git log --since="$SINCE" --oneline --all \
    --grep="fix" --grep="revert" --grep="hotfix" --grep="bug" \
    --format="%H|%s" 2>/dev/null || true)"

  [[ -n "$commits" ]] || continue

  while IFS='|' read -r hash msg; do
    [[ -n "$hash" ]] || continue
    short="${hash:0:7}"
    diff_stat="$(cd "$dir" && git diff --stat "${hash}^..${hash}" 2>/dev/null | tail -1 || echo 'unknown')"
    files_changed="$(cd "$dir" && git diff --name-only "${hash}^..${hash}" 2>/dev/null | head -5 | paste -sd ',' - || echo 'unknown')"

    if [[ "$first" == true ]]; then
      first=false
    else
      printf ',\n'
    fi

    cat <<EOF
  {
    "project": $(printf '%s' "$proj" | json_escape),
    "commit": $(printf '%s' "$short" | json_escape),
    "message": $(printf '%s' "$msg" | json_escape),
    "files": $(printf '%s' "$files_changed" | json_escape),
    "diff_stat": $(printf '%s' "$diff_stat" | json_escape)
  }
EOF
  done <<< "$commits"
done < <(discover_projects)

printf '\n]\n'
