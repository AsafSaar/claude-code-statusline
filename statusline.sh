#!/usr/bin/env bash
# claude-code-statusline — A rich status line for Claude Code
# https://github.com/AsafSaar/claude-code-statusline
#
# Reads JSON from stdin (provided by Claude Code) and outputs a
# colorized, segment-based status line.
#
# Segments can be toggled by commenting out entries in ENABLED_SEGMENTS below.

set -euo pipefail

# ============================================================================
# CONFIGURATION — comment out any segment you don't want
# ============================================================================
ENABLED_SEGMENTS=(
  "cwd"           # Current directory basename
  "git_branch"    # Git branch name
  "dirty"         # Uncommitted file count
  "ahead_behind"  # Commits ahead/behind remote
  "model"         # Active model name
  "node"          # Node.js version
  "context"       # Context window usage %
  "cost"          # Session cost (from Claude Code)
  "duration"      # Session duration (from Claude Code)
  "lines"         # Lines added/removed this session
  "ts_errors"     # TypeScript errors (cached)
)

# Separator between segments
SEP="  "

# ============================================================================
# HELPERS
# ============================================================================
segment_enabled() {
  local name="$1"
  for s in "${ENABLED_SEGMENTS[@]}"; do
    [[ "$s" == "$name" ]] && return 0
  done
  return 1
}

# Cross-platform file mtime (seconds since epoch)
file_mtime() {
  if stat -c %Y "$1" &>/dev/null; then
    stat -c %Y "$1"  # Linux / GNU stat
  else
    stat -f %m "$1" 2>/dev/null  # macOS / BSD stat
  fi
}

# Cross-platform md5 hash
portable_md5() {
  if command -v md5sum &>/dev/null; then
    echo -n "$1" | md5sum | awk '{print $1}'
  else
    echo -n "$1" | md5
  fi
}

# ============================================================================
# READ INPUT
# ============================================================================
input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd // empty')

# ============================================================================
# SEGMENT: cwd
# ============================================================================
seg_cwd=""
if segment_enabled "cwd" && [[ -n "${cwd:-}" ]]; then
  seg_cwd=$(printf '\033[37m%s\033[0m' "$(basename "$cwd")")
fi

# ============================================================================
# SEGMENT: git_branch
# ============================================================================
seg_git_branch=""
git_branch=""
if segment_enabled "git_branch" && [[ -n "${cwd:-}" ]]; then
  git_branch=$(git --no-optional-locks -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || true)
  if [[ -n "$git_branch" ]]; then
    seg_git_branch=$(printf '\033[36m\ue0a0 %s\033[0m' "$git_branch")
  fi
fi

# ============================================================================
# SEGMENT: dirty
# ============================================================================
seg_dirty=""
if segment_enabled "dirty" && [[ -n "${cwd:-}" ]] && [[ -n "$git_branch" ]]; then
  dirty_count=$(git --no-optional-locks -C "$cwd" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$dirty_count" -gt 0 ]]; then
    seg_dirty=$(printf '\033[33m%s dirty\033[0m' "$dirty_count")
  fi
fi

# ============================================================================
# SEGMENT: ahead_behind
# ============================================================================
seg_ahead_behind=""
if segment_enabled "ahead_behind" && [[ -n "${cwd:-}" ]] && [[ -n "$git_branch" ]]; then
  ab=$(git --no-optional-locks -C "$cwd" rev-list --count --left-right HEAD...@{u} 2>/dev/null || true)
  if [[ -n "$ab" ]]; then
    ahead=$(echo "$ab" | awk '{print $1}')
    behind=$(echo "$ab" | awk '{print $2}')
    if [[ "$ahead" -gt 0 ]] || [[ "$behind" -gt 0 ]]; then
      seg_ahead_behind=$(printf '\033[33m\u2191%s \u2193%s\033[0m' "$ahead" "$behind")
    fi
  fi
fi

# ============================================================================
# SEGMENT: model
# ============================================================================
seg_model=""
if segment_enabled "model"; then
  model_name=$(echo "$input" | jq -r '.model.display_name // empty')
  if [[ -n "${model_name:-}" ]]; then
    seg_model=$(printf '\033[38;5;147m%s\033[0m' "$model_name")
  fi
fi

# ============================================================================
# SEGMENT: node
# ============================================================================
seg_node=""
if segment_enabled "node"; then
  raw_node=$(node --version 2>/dev/null || true)
  if [[ -n "${raw_node:-}" ]]; then
    seg_node=$(printf '\033[32mnode %s\033[0m' "${raw_node#v}")
  fi
fi

# ============================================================================
# SEGMENT: context
# ============================================================================
seg_context=""
if segment_enabled "context"; then
  used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
  if [[ -n "${used_pct:-}" ]]; then
    pct_int=$(printf '%.0f' "$used_pct")
    if [[ "$pct_int" -ge 80 ]]; then
      ctx_color='\033[31m'   # red
    elif [[ "$pct_int" -ge 50 ]]; then
      ctx_color='\033[33m'   # yellow
    else
      ctx_color='\033[32m'   # green
    fi
    seg_context=$(printf "${ctx_color}ctx %s%%\033[0m" "$pct_int")
  fi
fi

# ============================================================================
# SEGMENT: cost (native from Claude Code JSON)
# ============================================================================
seg_cost=""
if segment_enabled "cost"; then
  total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
  if [[ -n "${total_cost:-}" ]]; then
    formatted_cost=$(awk -v c="$total_cost" 'BEGIN { printf "%.3f", c }')
    seg_cost=$(printf '\033[35m$%s\033[0m' "$formatted_cost")
  fi
fi

# ============================================================================
# SEGMENT: duration (native from Claude Code JSON)
# ============================================================================
seg_duration=""
if segment_enabled "duration"; then
  duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')
  if [[ -n "${duration_ms:-}" ]]; then
    elapsed=$(( ${duration_ms%.*} / 1000 ))
    h=$(( elapsed / 3600 ))
    m=$(( (elapsed % 3600) / 60 ))
    if [[ "$h" -gt 0 ]]; then
      seg_duration=$(printf '\033[34m%sh%sm\033[0m' "$h" "$m")
    elif [[ "$m" -gt 0 ]]; then
      seg_duration=$(printf '\033[34m%sm\033[0m' "$m")
    fi
  fi
fi

# ============================================================================
# SEGMENT: lines added/removed
# ============================================================================
seg_lines=""
if segment_enabled "lines"; then
  lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
  lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
  if [[ "$lines_added" -gt 0 ]] || [[ "$lines_removed" -gt 0 ]]; then
    seg_lines=$(printf '\033[32m+%s\033[0m/\033[31m-%s\033[0m' "$lines_added" "$lines_removed")
  fi
fi

# ============================================================================
# SEGMENT: ts_errors (cached, non-blocking)
# ============================================================================
seg_ts_errors=""
if segment_enabled "ts_errors" && [[ -n "${cwd:-}" ]]; then
  cwd_hash=$(portable_md5 "$cwd")
  cache_file="/tmp/tsc-errors-${cwd_hash}.txt"
  if [[ -f "$cache_file" ]]; then
    cache_mtime=$(file_mtime "$cache_file")
    now_ts=$(date +%s)
    age=$(( now_ts - cache_mtime ))
    if [[ "$age" -le 300 ]]; then
      ts_err=$(head -1 "$cache_file" 2>/dev/null | tr -d ' ')
      if [[ -n "${ts_err:-}" ]] && [[ "$ts_err" -gt 0 ]] 2>/dev/null; then
        seg_ts_errors=$(printf '\033[31mTS:%s\033[0m' "$ts_err")
      fi
    fi
  fi
fi

# ============================================================================
# ASSEMBLE OUTPUT
# ============================================================================
parts=()

[[ -n "$seg_cwd" ]]          && parts+=("$seg_cwd")
[[ -n "$seg_git_branch" ]]   && parts+=("$seg_git_branch")
[[ -n "$seg_dirty" ]]        && parts+=("$seg_dirty")
[[ -n "$seg_ahead_behind" ]] && parts+=("$seg_ahead_behind")
[[ -n "$seg_model" ]]        && parts+=("$seg_model")
[[ -n "$seg_node" ]]         && parts+=("$seg_node")
[[ -n "$seg_context" ]]      && parts+=("$seg_context")
[[ -n "$seg_cost" ]]         && parts+=("$seg_cost")
[[ -n "$seg_duration" ]]     && parts+=("$seg_duration")
[[ -n "$seg_lines" ]]        && parts+=("$seg_lines")
[[ -n "$seg_ts_errors" ]]    && parts+=("$seg_ts_errors")

# Join with separator
output=""
for i in "${!parts[@]}"; do
  if [[ "$i" -gt 0 ]]; then
    output+="$SEP"
  fi
  output+="${parts[$i]}"
done

printf '%s' "$output"
