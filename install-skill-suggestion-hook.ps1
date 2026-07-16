# skill-suggestion-reminder.ps1'i her prompt gonderiminde (UserPromptSubmit)
# otomatik calistiran hook'u ~/.claude/settings.json'a idempotent olarak
# ekler. Boylece her soruda "uygun skill/agent var mi" hatirlatmasi modele
# enjekte edilir. Mevcut UserPromptSubmit hook'larini BOZMAZ - ayni event
# altina ikinci bir hook girdisi olarak eklenir.
#
# Kullanim: git pull sonrasi (ozellikle yeni bir bilgisayarda)
#   powershell -ExecutionPolicy Bypass -File install-skill-suggestion-hook.ps1

$ErrorActionPreference = "Stop"
$SettingsPath = "$env:USERPROFILE\.claude\settings.json"
$NoBomUtf8 = New-Object System.Text.UTF8Encoding $false

function Write-JsonNoBom($obj) {
    [System.IO.File]::WriteAllText($SettingsPath, ($obj | ConvertTo-Json -Depth 20), $NoBomUtf8)
}

function Ensure-SkillSuggestionHook {
    if (-not (Test-Path $SettingsPath)) {
        Write-Warning "$SettingsPath bulunamadi, skill oneri hook'u atlaniyor."
        return
    }

    $scriptPath = Join-Path $PSScriptRoot "skill-suggestion-reminder.ps1"
    if (-not (Test-Path $scriptPath)) {
        Write-Warning "$scriptPath bulunamadi, skill oneri hook'u atlaniyor."
        return
    }
    $command = "powershell -ExecutionPolicy Bypass -File `"$scriptPath`""

    $json = Get-Content $SettingsPath -Raw | ConvertFrom-Json

    if (-not $json.hooks) {
        $json | Add-Member -MemberType NoteProperty -Name hooks -Value ([PSCustomObject]@{})
    }
    if (-not ($json.hooks.PSObject.Properties.Name -contains "UserPromptSubmit")) {
        $json.hooks | Add-Member -MemberType NoteProperty -Name UserPromptSubmit -Value @()
    }

    foreach ($entry in $json.hooks.UserPromptSubmit) {
        foreach ($h in $entry.hooks) {
            if ($h.command -like "*skill-suggestion-reminder.ps1*") {
                Write-Host "Skill oneri hook'u zaten kurulu, atlaniyor."
                return
            }
        }
    }

    $newEntry = [PSCustomObject]@{
        hooks = @(
            [PSCustomObject]@{
                type    = "command"
                command = $command
                timeout = 15
            }
        )
    }

    $json.hooks.UserPromptSubmit = @($json.hooks.UserPromptSubmit) + $newEntry
    Write-JsonNoBom $json
    Write-Host "settings.json guncellendi: skill oneri UserPromptSubmit hook'u eklendi."
    Write-Host "Komut: $command"
}

Ensure-SkillSuggestionHook

Write-Host ""
Write-Host "Tamamlandi. Hook'un aktif olmasi icin Claude Code'u yeniden baslat"
Write-Host "(veya /hooks menusunu bir kez ac)."
