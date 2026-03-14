#!/usr/bin/env bash
# 共享的仓库发现逻辑 — install-hook-fleet.sh 和 check-hook-fleet.sh 共用
# 用法: source scripts/lib-repo-discovery.sh; find_fleet_repos

find_fleet_repos() {
  local script_dir workspace_root owner_home primary_projects legacy_projects
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  workspace_root="$(cd "$script_dir/.." && pwd -P)"
  owner_home="$(cd "$workspace_root/.." && pwd -P)"
  primary_projects="$owner_home/projects"
  legacy_projects="$HOME/projects"

  local cands=("$workspace_root")
  # shellcheck disable=SC2043  # template: users add their own projects here
  for p in infra-dashboard ; do
    [[ -e "$primary_projects/$p/.git" ]] && cands+=("$primary_projects/$p")
    [[ -e "$legacy_projects/$p/.git" ]] && cands+=("$legacy_projects/$p")
  done

  # bash 3 兼容去重
  local uniq=()
  for r in "${cands[@]}"; do
    local real
    real="$(cd "$r" 2>/dev/null && pwd -P || true)"
    [[ -z "$real" ]] && continue

    local exists=0
    for u in "${uniq[@]:-}"; do
      if [[ "$u" == "$real" ]]; then
        exists=1
        break
      fi
    done
    [[ $exists -eq 0 ]] && uniq+=("$real")
  done

  # shellcheck disable=SC2034 # exported via source
  FLEET_REPOS=("${uniq[@]}")
  # shellcheck disable=SC2034 # exported via source
  FLEET_WORKSPACE_ROOT="$workspace_root"
}
