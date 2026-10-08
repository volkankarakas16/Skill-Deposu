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

# Cevap dili: Claude Code'un yerlesik "language" ayari system prompt'a
# "Always respond in turkish" ekler. CLAUDE.md'deki kural tek basina uzun
# Ingilizce arac ciktilarindan sonra yetmedi (2026-10-08).
$SettingsPath = Join-Path $targetDir "settings.json"
if (Test-Path $SettingsPath) {
    $json = Get-Content $SettingsPath -Raw | ConvertFrom-Json
    if ($json.language -ne "turkish") {
        if ($json.PSObject.Properties.Name -contains "language") {
            $json.language = "turkish"
        } else {
            $json | Add-Member -MemberType NoteProperty -Name language -Value "turkish"
        }
        $NoBomUtf8 = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($SettingsPath, ($json | ConvertTo-Json -Depth 20), $NoBomUtf8)
        Write-Host "settings.json guncellendi: language=turkish"
    }
}

Write-Host "Tamamlandi: $target guncellendi. Degisikliklerin aktif olmasi icin Claude Code'u yeniden baslat."
