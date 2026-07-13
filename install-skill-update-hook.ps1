# check-skill-updates.ps1'i her Claude Code oturumu basinda (SessionStart)
# otomatik calistiran hook'u ~/.claude/settings.json'a idempotent olarak
# ekler. Mevcut headroom SessionStart hook'unu BOZMAZ - ayni event altina
# ikinci bir hook girdisi olarak eklenir.
#
# Kullanim: git pull sonrasi (ozellikle yeni bir bilgisayarda)
#   powershell -ExecutionPolicy Bypass -File install-skill-update-hook.ps1

$ErrorActionPreference = "Stop"
$SettingsPath = "$env:USERPROFILE\.claude\settings.json"
$NoBomUtf8 = New-Object System.Text.UTF8Encoding $false

function Write-JsonNoBom($obj) {
    [System.IO.File]::WriteAllText($SettingsPath, ($obj | ConvertTo-Json -Depth 20), $NoBomUtf8)
}

function Ensure-SkillUpdateHook {
    if (-not (Test-Path $SettingsPath)) {
        Write-Warning "$SettingsPath bulunamadi, skill guncelleme hook'u atlaniyor."
        return
    }

    $scriptPath = Join-Path $PSScriptRoot "check-skill-updates.ps1"
    if (-not (Test-Path $scriptPath)) {
        Write-Warning "$scriptPath bulunamadi, skill guncelleme hook'u atlaniyor."
        return
    }
    $command = "powershell -ExecutionPolicy Bypass -File `"$scriptPath`""

    $json = Get-Content $SettingsPath -Raw | ConvertFrom-Json

    if (-not $json.hooks) {
        $json | Add-Member -MemberType NoteProperty -Name hooks -Value ([PSCustomObject]@{})
    }
    if (-not ($json.hooks.PSObject.Properties.Name -contains "SessionStart")) {
        $json.hooks | Add-Member -MemberType NoteProperty -Name SessionStart -Value @()
    }

    foreach ($entry in $json.hooks.SessionStart) {
        foreach ($h in $entry.hooks) {
            if ($h.command -like "*check-skill-updates.ps1*") {
                Write-Host "Skill guncelleme hook'u zaten kurulu, atlaniyor."
                return
            }
        }
    }

    $newEntry = [PSCustomObject]@{
        matcher = "startup|resume"
        hooks   = @(
            [PSCustomObject]@{
                type    = "command"
                command = $command
                timeout = 30
            }
        )
    }

    $json.hooks.SessionStart = @($json.hooks.SessionStart) + $newEntry
    Write-JsonNoBom $json
    Write-Host "settings.json guncellendi: skill guncelleme SessionStart hook'u eklendi."
    Write-Host "Komut: $command"
}

Ensure-SkillUpdateHook

Write-Host ""
Write-Host "Tamamlandi. Hook'un aktif olmasi icin Claude Code'u yeniden baslat"
Write-Host "(veya /hooks menusunu bir kez ac)."
