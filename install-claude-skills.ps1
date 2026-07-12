# Bu bilgisayarda claude-marketplaces.txt ve claude-skills.txt icindeki
# tum marketplace/pluginleri kurar/gunceller.
# Kullanim: git pull sonrasi bu scripti calistir.
#   powershell -ExecutionPolicy Bypass -File install-claude-skills.ps1

$ErrorActionPreference = "Stop"
$marketplacesFile = Join-Path $PSScriptRoot "claude-marketplaces.txt"
$listFile = Join-Path $PSScriptRoot "claude-skills.txt"

Write-Host "Marketplace'ler ekleniyor/dogrulaniyor..."
$marketplaces = Get-Content $marketplacesFile | Where-Object { $_ -and -not $_.StartsWith("#") }
foreach ($m in $marketplaces) {
    $m = $m.Trim()
    if ($m -eq "") { continue }
    Write-Host "--- $m ---"
    claude plugin marketplace add $m
}

$plugins = Get-Content $listFile | Where-Object { $_ -and -not $_.StartsWith("#") }

foreach ($p in $plugins) {
    $p = $p.Trim()
    if ($p -eq "") { continue }
    Write-Host "=== $p ==="
    claude plugin install $p
}

Write-Host ""
Write-Host "Tamamlandi. Degisikliklerin aktif olmasi icin Claude Code'u yeniden baslat."
