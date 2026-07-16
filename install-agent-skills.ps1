# Repo'daki agent-skills-lock.json'da kayitli TUM skills.sh skillerini
# (find-skills dahil) GLOBAL olarak "npx skills add" ile kurar. Bu, ev/ofis
# bilgisayarlari arasinda find-skills ile kurulan skilleri senkronlamanin
# yoludur (Yol A: lockfile tabanli).
#
# Kaynak makinede: find-skills ile skilleri kur -> export-agent-skills.ps1 ->
# commit + push. Hedef makinede: git pull -> bu scripti calistir.
#
# Gereksinim: Node.js / npx.
# Kullanim:
#   powershell -ExecutionPolicy Bypass -File install-agent-skills.ps1
#   powershell -ExecutionPolicy Bypass -File install-agent-skills.ps1 -DryRun

param([switch]$DryRun)

$ErrorActionPreference = "Stop"

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Write-Warning "npx bulunamadi. Node.js gerekli: https://nodejs.org"
    return
}

$lockPath = Join-Path $PSScriptRoot "agent-skills-lock.json"
if (-not (Test-Path $lockPath)) {
    Write-Host "agent-skills-lock.json yok; senkronlanacak skill yok. Atlaniyor."
    return
}

$lock = Get-Content $lockPath -Raw | ConvertFrom-Json
if (-not $lock.skills -or @($lock.skills.PSObject.Properties.Name).Count -eq 0) {
    Write-Host "Kayitli skill yok. Atlaniyor."
    return
}

foreach ($name in $lock.skills.PSObject.Properties.Name) {
    $entry = $lock.skills.$name
    if ($entry.sourceType -ne "github") {
        Write-Warning "$name : sourceType=$($entry.sourceType) (github disi) - otomatik kurulamiyor, elle kur. Atlaniyor."
        continue
    }
    $target = "$($entry.source)@$name"
    if ($DryRun) { Write-Host "DRYRUN: npx skills add $target -g -y"; continue }
    Write-Host "=== $target ==="
    npx -y skills add $target -g -y
}

Write-Host ""
if ($DryRun) {
    Write-Host "DryRun bitti (hicbir sey kurulmadi)."
} else {
    Write-Host "Tamamlandi. Skillerin yuklenmesi icin Claude Code'u yeniden baslat."
}
