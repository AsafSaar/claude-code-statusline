# claude-code-statusline — Minimal variant (Windows)
# Shows only: git branch | context usage | cost
#
# Usage: Set in ~/.claude/settings.json:
#   "statusLine": { "type": "command", "command": "pwsh -NoProfile -File /path/to/minimal.ps1" }

$ErrorActionPreference = 'SilentlyContinue'
$ESC = [char]27

$input = @($Input) -join "`n"
try { $json = $input | ConvertFrom-Json } catch { Write-Host ""; exit 0 }

$cwd = if ($json.cwd) { $json.cwd } else { "" }
$parts = @()
$Sep = " $ESC[90m|$ESC[0m "

# Git branch (cyan)
if ($cwd) {
    $branch = & git --no-optional-locks -C $cwd symbolic-ref --short HEAD 2>$null
    if ($branch) {
        $icon = [char]0xe0a0
        $parts += "$ESC[36m$icon $branch$ESC[0m"
    }
}

# Context window (color-coded)
$used_pct = $json.context_window.used_percentage
if ($null -ne $used_pct) {
    $pct_int = [math]::Round($used_pct)
    if ($pct_int -ge 80) { $color = "$ESC[31m" }
    elseif ($pct_int -ge 50) { $color = "$ESC[33m" }
    else { $color = "$ESC[32m" }
    $battery = [char]::ConvertFromUtf32(0x1F50B)
    $parts += "${color}$battery ${pct_int}%$ESC[0m"
}

# Cost (magenta)
$total_cost = $json.cost.total_cost_usd
if ($null -ne $total_cost) {
    $formatted = "{0:F3}" -f [double]$total_cost
    $money = [char]::ConvertFromUtf32(0x1F4B0)
    $parts += "$ESC[35m$money `$$formatted$ESC[0m"
}

# Output
Write-Host -NoNewline ($parts -join $Sep)
