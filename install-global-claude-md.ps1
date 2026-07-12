# global-CLAUDE.md dosyasini ~/.claude/CLAUDE.md konumuna kopyalar,
# boylece hangi klasorde Claude Code acilirsa acilsin bu kurallar gecerli olur.
# Kullanim: git pull sonrasi bu scripti calistir.
#   powershell -ExecutionPolicy Bypass -File install-global-claude-md.ps1

$ErrorActionPreference = "Stop"
$source = Join-Path $PSScriptRoot "global-CLAUDE.md"
$targetDir = Join-Path $env:USERPROFILE ".claude"
$target = Join-Path $targetDir "CLAUDE.md"

if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
}

Copy-Item -Path $source -Destination $target -Force

Write-Host "Tamamlandi: $target guncellendi. Degisikliklerin aktif olmasi icin Claude Code'u yeniden baslat."
