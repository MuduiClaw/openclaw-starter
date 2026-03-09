#!/bin/bash
# archive_memory.sh — 将超过 7 天的 daily notes 移入 archive/YYYY-MM/
# v2: 归档前输出即将过期的文件列表，供调用方（cron agent）提取精华
# Usage: bash archive_memory.sh [--dry-run]

set -euo pipefail

MEMORY_DIR="${HOME}/clawd/memory"
ARCHIVE_DIR="${MEMORY_DIR}/archive"
RETENTION_DAYS=7
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "🔍 DRY RUN — no files will be moved"
fi

# Phase 1: Identify files to archive and output for extraction
archived=0
skipped=0
expiring_files=()

for file in "${MEMORY_DIR}"/????-??-??*.md; do
  [[ -f "$file" ]] || continue
  
  basename=$(basename "$file")
  file_date="${basename:0:10}"
  year_month="${basename:0:7}"
  
  if ! date -j -f "%Y-%m-%d" "$file_date" "+%s" &>/dev/null 2>&1; then
    continue
  fi
  
  file_epoch=$(date -j -f "%Y-%m-%d" "$file_date" "+%s" 2>/dev/null)
  now_epoch=$(date "+%s")
  age_days=$(( (now_epoch - file_epoch) / 86400 ))
  
  if (( age_days > RETENTION_DAYS )); then
    expiring_files+=("$file")
    file_size=$(wc -c < "$file" | tr -d ' ')
    echo "  📋 Expiring: ${basename} (${age_days}d, ${file_size}B)"
  else
    ((skipped++))
  fi
done

# Phase 2: Output expiring files for agent extraction
if (( ${#expiring_files[@]+0} > 0 )); then
  echo ""
  echo "EXPIRING_FILES=${#expiring_files[@]}"
  for file in "${expiring_files[@]}"; do
    echo "EXPIRING_PATH=$(basename "$file")"
  done
  echo ""
fi

# Phase 3: Archive
for file in "${expiring_files[@]+${expiring_files[@]}}"; do
  [[ -z "$file" ]] && continue
  basename=$(basename "$file")
  year_month="${basename:0:7}"
  target_dir="${ARCHIVE_DIR}/${year_month}"
  
  if $DRY_RUN; then
    echo "  📦 Would archive: ${basename} → archive/${year_month}/"
  else
    mkdir -p "$target_dir"
    mv "$file" "$target_dir/"
    echo "  📦 Archived: ${basename} → archive/${year_month}/"
  fi
  ((archived++))
done

echo ""
echo "✅ Done: ${archived} archived, ${skipped} kept (within ${RETENTION_DAYS} days)"
