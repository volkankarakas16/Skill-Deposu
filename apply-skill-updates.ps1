# check-skill-updates.ps1 izlenen bir marketplace'te yeni commit tespit edince
# bunu ARKA PLANDA (gizli pencerede) calistirir. claude-marketplaces.txt'teki
# tum marketplace'leri tazeler ve claude-skills.txt'teki tum plugin'leri en
# guncel surumlerine yukseltir (claude plugin update - zaten guncel olanlar
# no-op, guvenli). Ciktilari ~/.claude/skill-update-apply.log'a yazar.
# Degisikliklerin aktif olmasi icin Claude Code'un yeniden baslatilmasi gerekir.
#
# Elle de calistirilabilir:
#   powershell -ExecutionPolicy Bypass -File apply-skill-updates.ps1
# Sadece ne yapacagini gormek icin (hicbir sey calistirmadan):
#   powershell -ExecutionPolicy Bypass -File apply-skill-updates.ps1 -DryRun

param([switch]$DryRun)

$ErrorActionPreference = "Continue"
$RepoRoot = $PSScriptRoot
$MarketplacesFile = Join-Path $RepoRoot "claude-marketplaces.txt"
$SkillsFile = Join-Path $RepoRoot "claude-skills.txt"
$LogPath = "$env:USERPROFILE\.claude\skill-update-apply.log"

# Test/otomasyon icin env ile de dry-run'a zorlanabilir.
if ($env:SKILL_AUTOUPDATE_DRYRUN -eq "1") { $DryRun = $true }

function Write-Log($msg) {
    $line = "[{0}] {1}" -f (Get-Date).ToString("s"), $msg
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

function Read-List($path) {
    if (-not (Test-Path $path)) { return @() }
    Get-Content $path |
        Where-Object { $_ -and -not $_.TrimStart().StartsWith("#") } |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" }
}

Write-Log "=== apply-skill-updates basladi (DryRun=$DryRun) ==="

$marketplaces = Read-List $MarketplacesFile
foreach ($m in $marketplaces) {
    if ($DryRun) { Write-Log "DRYRUN: claude plugin marketplace add $m"; continue }
    Write-Log "marketplace add: $m"
    try { claude plugin marketplace add $m 2>&1 | ForEach-Object { Write-Log "  $_" } }
    catch { Write-Log "  HATA: $_" }
}

$plugins = Read-List $SkillsFile
$ok = 0; $fail = 0
foreach ($p in $plugins) {
    if ($DryRun) { Write-Log "DRYRUN: claude plugin update $p"; continue }
    Write-Log "update: $p"
    try {
        claude plugin update $p 2>&1 | ForEach-Object { Write-Log "  $_" }
        $ok++
    } catch { Write-Log "  HATA: $_"; $fail++ }
}

if ($DryRun) {
    Write-Log "=== apply-skill-updates bitti (DRYRUN: $($marketplaces.Count) marketplace, $($plugins.Count) plugin listelendi) ==="
} else {
    Write-Log "=== apply-skill-updates bitti (guncellenen=$ok, hata=$fail). Claude Code'u yeniden baslat. ==="
}
