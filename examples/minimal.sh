#!/usr/bin/env bash
# claude-code-statusline — Minimal variant
# Shows only: git branch | context usage | cost
#
# Usage: Set in ~/.claude/settings.json:
#   "statusLine": { "type": "command", "command": "bash /path/to/minimal.sh" }

set -euo pipefail

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')
parts=()
SEP=$' \033[90m|\033[0m '

# Git branch (cyan)
if [[ -n "${cwd:-}" ]]; then
  branch=$(git --no-optional-locks -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || true)
  if [[ -n "$branch" ]]; then
    parts+=("$(printf '\033[36m\xee\x82\xa0 %s\033[0m' "$branch")")
  fi
fi

# Context window (color-coded)
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [[ -n "${used_pct:-}" ]]; then
  pct_int=$(printf '%.0f' "$used_pct")
  if [[ "$pct_int" -ge 80 ]]; then color='\033[31m'
  elif [[ "$pct_int" -ge 50 ]]; then color='\033[33m'
  else color='\033[32m'; fi
  parts+=("$(printf "${color}🔋 %s%%\033[0m" "$pct_int")")
fi

# Cost (magenta)
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
if [[ -n "${total_cost:-}" ]]; then
  formatted=$(awk -v c="$total_cost" 'BEGIN { printf "%.3f", c }')
  parts+=("$(printf '\033[35m💰 $%s\033[0m' "$formatted")")
fi

# Output
output=""
for i in "${!parts[@]}"; do
  [[ "$i" -gt 0 ]] && output+="$SEP"
  output+="${parts[$i]}"
done
printf '%s' "$output"
