# check-agent-skills-updates.ps1'i her Claude Code oturumu basinda (SessionStart)
# otomatik calistiran hook'u ~/.claude/settings.json'a idempotent olarak ekler.
# Boylece find-skills/npx skills ile kurulan skiller de oturum acilisinda arka
# planda guncellenir. Mevcut SessionStart hook'larini (headroom, skill guncelleme)
# BOZMAZ - ayni event altina ek bir hook girdisi olarak eklenir.
#
# Kullanim: git pull sonrasi (ozellikle yeni bir bilgisayarda)
#   powershell -ExecutionPolicy Bypass -File install-agent-skills-update-hook.ps1

$ErrorActionPreference = "Stop"
$SettingsPath = "$env:USERPROFILE\.claude\settings.json"
$NoBomUtf8 = New-Object System.Text.UTF8Encoding $false

function Write-JsonNoBom($obj) {
    [System.IO.File]::WriteAllText($SettingsPath, ($obj | ConvertTo-Json -Depth 20), $NoBomUtf8)
}

function Ensure-AgentSkillsUpdateHook {
    if (-not (Test-Path $SettingsPath)) {
        Write-Warning "$SettingsPath bulunamadi, agent-skills guncelleme hook'u atlaniyor."
        return
    }

    $scriptPath = Join-Path $PSScriptRoot "check-agent-skills-updates.ps1"
    if (-not (Test-Path $scriptPath)) {
        Write-Warning "$scriptPath bulunamadi, agent-skills guncelleme hook'u atlaniyor."
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
            if ($h.command -like "*check-agent-skills-updates.ps1*") {
                Write-Host "Agent-skills guncelleme hook'u zaten kurulu, atlaniyor."
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
    Write-Host "settings.json guncellendi: agent-skills SessionStart guncelleme hook'u eklendi."
    Write-Host "Komut: $command"
}

Ensure-AgentSkillsUpdateHook

Write-Host ""
Write-Host "Tamamlandi. Hook'un aktif olmasi icin Claude Code'u yeniden baslat"
Write-Host "(veya /hooks menusunu bir kez ac)."
