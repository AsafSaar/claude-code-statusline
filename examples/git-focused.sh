#!/usr/bin/env bash
# claude-code-statusline — Git-focused variant
# Shows: cwd | branch | dirty files | ahead/behind | last commit age | lines changed
#
# Usage: Set in ~/.claude/settings.json:
#   "statusLine": { "type": "command", "command": "bash /path/to/git-focused.sh" }

set -euo pipefail

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')
parts=()

# CWD basename (white)
if [[ -n "${cwd:-}" ]]; then
  parts+=("$(printf '\033[37m%s\033[0m' "$(basename "$cwd")")")
fi

# Git branch (cyan)
git_branch=""
if [[ -n "${cwd:-}" ]]; then
  git_branch=$(git --no-optional-locks -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || true)
  if [[ -n "$git_branch" ]]; then
    parts+=("$(printf '\033[36m\ue0a0 %s\033[0m' "$git_branch")")
  fi
fi

# Dirty files (yellow)
if [[ -n "${cwd:-}" ]] && [[ -n "$git_branch" ]]; then
  dirty=$(git --no-optional-locks -C "$cwd" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$dirty" -gt 0 ]]; then
    parts+=("$(printf '\033[33m%s dirty\033[0m' "$dirty")")
  fi
fi

# Ahead / behind (yellow)
if [[ -n "${cwd:-}" ]] && [[ -n "$git_branch" ]]; then
  ab=$(git --no-optional-locks -C "$cwd" rev-list --count --left-right HEAD...@{u} 2>/dev/null || true)
  if [[ -n "$ab" ]]; then
    ahead=$(echo "$ab" | awk '{print $1}')
    behind=$(echo "$ab" | awk '{print $2}')
    if [[ "$ahead" -gt 0 ]] || [[ "$behind" -gt 0 ]]; then
      parts+=("$(printf '\033[33m\u2191%s \u2193%s\033[0m' "$ahead" "$behind")")
    fi
  fi
fi

# Last commit age (blue)
if [[ -n "${cwd:-}" ]] && [[ -n "$git_branch" ]]; then
  last_commit_ts=$(git --no-optional-locks -C "$cwd" log -1 --format=%ct 2>/dev/null || true)
  if [[ -n "$last_commit_ts" ]]; then
    now=$(date +%s)
    age_s=$(( now - last_commit_ts ))
    age_m=$(( age_s / 60 ))
    age_h=$(( age_s / 3600 ))
    age_d=$(( age_s / 86400 ))
    if [[ "$age_d" -gt 0 ]]; then
      age_str="${age_d}d ago"
    elif [[ "$age_h" -gt 0 ]]; then
      age_str="${age_h}h ago"
    else
      age_str="${age_m}m ago"
    fi
    parts+=("$(printf '\033[34mlast commit %s\033[0m' "$age_str")")
  fi
fi

# Lines added/removed (green/red)
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
if [[ "$lines_added" -gt 0 ]] || [[ "$lines_removed" -gt 0 ]]; then
  parts+=("$(printf '\033[32m+%s\033[0m/\033[31m-%s\033[0m' "$lines_added" "$lines_removed")")
fi

# Output
output=""
for i in "${!parts[@]}"; do
  [[ "$i" -gt 0 ]] && output+="  "
  output+="${parts[$i]}"
done
printf '%s' "$output"
