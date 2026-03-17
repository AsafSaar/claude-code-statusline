# claude-code-statusline — Git-focused variant (Windows)
# Shows: cwd | branch | dirty files | ahead/behind | last commit age | lines changed
#
# Usage: Set in ~/.claude/settings.json:
#   "statusLine": { "type": "command", "command": "pwsh -NoProfile -File /path/to/git-focused.ps1" }

$ErrorActionPreference = 'SilentlyContinue'
$ESC = [char]27

$input = @($Input) -join "`n"
try { $json = $input | ConvertFrom-Json } catch { Write-Host ""; exit 0 }

$cwd = if ($json.cwd) { $json.cwd } else { "" }
$parts = @()
$Sep = " $ESC[90m|$ESC[0m "

# CWD basename (white)
if ($cwd) {
    $basename = Split-Path $cwd -Leaf
    $folder = [char]::ConvertFromUtf32(0x1F4C2)
    $parts += "$ESC[37m$folder $basename$ESC[0m"
}

# Git branch (cyan)
$git_branch = ""
if ($cwd) {
    $git_branch = & git --no-optional-locks -C $cwd symbolic-ref --short HEAD 2>$null
    if ($git_branch) {
        $icon = [char]0xe0a0
        $parts += "$ESC[36m$icon $git_branch$ESC[0m"
    }
}

# Dirty files (yellow)
if ($cwd -and $git_branch) {
    $dirty_output = & git --no-optional-locks -C $cwd status --porcelain 2>$null
    $dirty = if ($dirty_output) { @($dirty_output).Count } else { 0 }
    if ($dirty -gt 0) {
        $dot = [char]0x25CF
        $parts += "$ESC[33m$dot $dirty dirty$ESC[0m"
    }
}

# Ahead / behind (yellow)
if ($cwd -and $git_branch) {
    $ab = & git --no-optional-locks -C $cwd rev-list --count --left-right "HEAD...@{u}" 2>$null
    if ($ab) {
        $ab_parts = $ab -split '\s+'
        $ahead = [int]$ab_parts[0]
        $behind = [int]$ab_parts[1]
        if ($ahead -gt 0 -or $behind -gt 0) {
            $up = [char]0x2191
            $down = [char]0x2193
            $parts += "$ESC[33m$up$ahead $down$behind$ESC[0m"
        }
    }
}

# Last commit age (blue)
if ($cwd -and $git_branch) {
    $last_commit_ts = & git --no-optional-locks -C $cwd log -1 --format=%ct 2>$null
    if ($last_commit_ts) {
        $now = [int][double]::Parse((Get-Date -UFormat %s))
        $age_s = $now - [int]$last_commit_ts
        $age_d = [math]::Floor($age_s / 86400)
        $age_h = [math]::Floor($age_s / 3600)
        $age_m = [math]::Floor($age_s / 60)
        $timer = [char]0x23F1
        if ($age_d -gt 0) { $age_str = "${age_d}d ago" }
        elseif ($age_h -gt 0) { $age_str = "${age_h}h ago" }
        else { $age_str = "${age_m}m ago" }
        $parts += "$ESC[34m$timer last commit $age_str$ESC[0m"
    }
}

# Lines added/removed (green/red)
$lines_added = if ($json.cost.total_lines_added) { $json.cost.total_lines_added } else { 0 }
$lines_removed = if ($json.cost.total_lines_removed) { $json.cost.total_lines_removed } else { 0 }
if ($lines_added -gt 0 -or $lines_removed -gt 0) {
    $pencil = [char]0x270F
    $parts += "$ESC[32m$pencil +$lines_added$ESC[0m/$ESC[31m-$lines_removed$ESC[0m"
}

# Output
Write-Host -NoNewline ($parts -join $Sep)
