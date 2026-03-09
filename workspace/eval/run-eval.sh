#!/usr/bin/env bash
# eval/run-eval.sh — Run eval judge on all samples and produce baseline JSON
# Usage: bash eval/run-eval.sh [output-file]
# Output: eval/baselines/YYYY-MM-DD.json

set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")" && pwd)"
SAMPLES_DIR="$EVAL_DIR/samples"
JUDGE_PROMPT="$EVAL_DIR/judge-prompt.md"
OUTPUT_FILE="${1:-$EVAL_DIR/baselines/$(date +%Y-%m-%d).json}"
JUDGE_MODEL="gemini-3.1-flash"

mkdir -p "$(dirname "$OUTPUT_FILE")"

if [ ! -f "$JUDGE_PROMPT" ]; then
  echo "❌ Judge prompt not found: $JUDGE_PROMPT"
  exit 1
fi

JUDGE=$(cat "$JUDGE_PROMPT")

echo "📊 Eval Run: $(date +%Y-%m-%d\ %H:%M:%S)"
echo "  Judge: $JUDGE_PROMPT"
echo "  Model: $JUDGE_MODEL"
echo "  Samples: $(find "$SAMPLES_DIR" -name '*.md' ! -name '.gitkeep' | wc -l | tr -d ' ') files"
echo "  Output: $OUTPUT_FILE"
echo ""

# Collect all results
RESULTS="[]"
TOTAL=0
PASS=0
MARGINAL=0
FAIL=0
ERROR=0

for category in cron-output translation summary; do
  dir="$SAMPLES_DIR/$category"
  [ -d "$dir" ] || continue
  
  for sample in "$dir"/*.md; do
    [ -f "$sample" ] || continue
    basename=$(basename "$sample")
    
    echo "  ⏳ Evaluating: $category/$basename"
    
    SAMPLE_CONTENT=$(cat "$sample")
    
    # Use gemini CLI for judge (cost-efficient)
    RESULT=$(echo "$JUDGE

---

$SAMPLE_CONTENT" | gemini -m "$JUDGE_MODEL" 2>/dev/null || echo '{"error": "judge failed"}')
    
    # Extract JSON from result (gemini might wrap in markdown)
    JSON_RESULT=$(echo "$RESULT" | sed -n '/^{/,/^}/p' | head -20)
    
    if [ -z "$JSON_RESULT" ]; then
      # Try extracting from code block
      JSON_RESULT=$(echo "$RESULT" | sed -n '/```json/,/```/p' | grep -v '```' | head -20)
    fi
    
    if [ -n "$JSON_RESULT" ]; then
      # Check verdict
      VERDICT=$(echo "$JSON_RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('verdict','unknown'))" 2>/dev/null || echo "unknown")
      WEIGHTED=$(echo "$JSON_RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('weighted_total',0))" 2>/dev/null || echo "0")
      
      case "$VERDICT" in
        pass) PASS=$((PASS+1)) ;;
        marginal) MARGINAL=$((MARGINAL+1)) ;;
        fail) FAIL=$((FAIL+1)) ;;
        *) ERROR=$((ERROR+1)) ;;
      esac
      
      echo "    → $VERDICT ($WEIGHTED)"
    else
      echo "    → ⚠️ Judge output not parseable"
      ERROR=$((ERROR+1))
      JSON_RESULT="{\"error\": \"unparseable\", \"raw\": \"$(echo "$RESULT" | head -3 | tr '\n' ' ' | sed 's/"/\\"/g')\"}"
    fi
    
    TOTAL=$((TOTAL+1))
    
    # Append to results using python
    RESULTS=$(python3 -c "
import json, sys
results = json.loads(sys.argv[1])
try:
    score = json.loads(sys.argv[4])
except:
    score = {'error': 'parse_failed'}

results.append({
    'category': sys.argv[2],
    'sample': sys.argv[3],
    'weighted_total': score.get('weighted_total'),
    'verdict': score.get('verdict', 'error'),
    'one_line': score.get('one_line', score.get('error', 'judge failed')),
})
print(json.dumps(results, ensure_ascii=False))
" "$RESULTS" "$category" "$basename" "$JSON_RESULT" 2>/dev/null || echo "$RESULTS")
    
  done
done

# Write final output
python3 -c "
import json, sys
from datetime import datetime

results = json.loads(sys.argv[1])
category_scores = {}
for row in results:
    category = row.get('category')
    score = row.get('weighted_total')
    if isinstance(score, (int, float)) and category:
        category_scores.setdefault(category, []).append(score)

category_averages = {
    category: round(sum(scores) / len(scores), 2)
    for category, scores in category_scores.items()
    if scores
}

output = {
    'date': datetime.now().strftime('%Y-%m-%d'),
    'judge_model': sys.argv[2],
    'total_samples': int(sys.argv[3]),
    'pass': int(sys.argv[4]),
    'marginal': int(sys.argv[5]),
    'fail': int(sys.argv[6]),
    'error': int(sys.argv[7]),
    'results': results,
    'category_averages': category_averages,
}
print(json.dumps(output, indent=2, ensure_ascii=False))
" "$RESULTS" "$JUDGE_MODEL" "$TOTAL" "$PASS" "$MARGINAL" "$FAIL" "$ERROR" > "$OUTPUT_FILE"

echo ""
echo "✅ Eval complete: $TOTAL samples"
echo "  Pass: $PASS | Marginal: $MARGINAL | Fail: $FAIL | Error: $ERROR"
echo "  Output: $OUTPUT_FILE"
