# Bu bilgisayarda claude-skills.txt icindeki tum pluginleri kurar/gunceller.
# Kullanim: git pull sonrasi bu scripti calistir.
#   powershell -ExecutionPolicy Bypass -File install-claude-skills.ps1

$ErrorActionPreference = "Stop"
$listFile = Join-Path $PSScriptRoot "claude-skills.txt"

Write-Host "Marketplace ekleniyor/dogrulaniyor..."
claude plugin marketplace add alirezarezvani/claude-skills
claude plugin marketplace update claude-code-skills

$plugins = Get-Content $listFile | Where-Object { $_ -and -not $_.StartsWith("#") }

foreach ($p in $plugins) {
    $p = $p.Trim()
    if ($p -eq "") { continue }
    Write-Host "=== $p ==="
    claude plugin install $p
}

Write-Host ""
Write-Host "Tamamlandi. Degisikliklerin aktif olmasi icin Claude Code'u yeniden baslat."
