# ste-tr-denetim.ps1'i Stop olayina baglar. Claude her cevabi bitirdiginde
# son mesaj STE-TR kurallarina gore denetlenir, ihlal varsa cevap engellenir
# ve Claude yeniden yazar.
#
# Hook GLOBAL kurulur: ~/.claude/settings.json. Hangi klasorde Claude Code
# acilirsa acilsin calisir, tek bir projeye bagli degildir.
#
# Mevcut Stop hook'larini BOZMAZ. Ayni olay altina ikinci bir girdi olarak
# eklenir ve iki kez kurulmaz.
#
# Kullanim: git pull sonrasi (ozellikle yeni bir bilgisayarda)
#   powershell -ExecutionPolicy Bypass -File install-ste-tr-hook.ps1

$ErrorActionPreference = "Stop"
$SettingsPath = "$env:USERPROFILE\.claude\settings.json"
$NoBomUtf8 = New-Object System.Text.UTF8Encoding $false

function Write-JsonNoBom($obj) {
    [System.IO.File]::WriteAllText($SettingsPath, ($obj | ConvertTo-Json -Depth 20), $NoBomUtf8)
}

function Ensure-SteTrHook {
    if (-not (Test-Path $SettingsPath)) {
        Write-Warning "$SettingsPath bulunamadi, STE-TR hook'u atlaniyor."
        return
    }

    $scriptPath = Join-Path $PSScriptRoot "ste-tr-denetim.ps1"
    if (-not (Test-Path $scriptPath)) {
        Write-Warning "$scriptPath bulunamadi, STE-TR hook'u atlaniyor."
        return
    }
    $command = "powershell -ExecutionPolicy Bypass -File `"$scriptPath`""

    $json = Get-Content $SettingsPath -Raw | ConvertFrom-Json

    if (-not $json.hooks) {
        $json | Add-Member -MemberType NoteProperty -Name hooks -Value ([PSCustomObject]@{})
    }
    if (-not ($json.hooks.PSObject.Properties.Name -contains "Stop")) {
        $json.hooks | Add-Member -MemberType NoteProperty -Name Stop -Value @()
    }

    foreach ($entry in $json.hooks.Stop) {
        foreach ($h in $entry.hooks) {
            if ($h.command -like "*ste-tr-denetim.ps1*") {
                Write-Host "STE-TR hook'u zaten kurulu, atlaniyor."
                return
            }
        }
    }

    $newEntry = [PSCustomObject]@{
        hooks = @(
            [PSCustomObject]@{
                type    = "command"
                command = $command
                timeout = 20
            }
        )
    }

    $json.hooks.Stop = @($json.hooks.Stop) + $newEntry
    Write-JsonNoBom $json
    Write-Host "settings.json guncellendi: STE-TR Stop hook'u eklendi."
    Write-Host "Komut: $command"
}

Ensure-SteTrHook

Write-Host ""
Write-Host "Tamamlandi. Hook'un aktif olmasi icin Claude Code'u yeniden baslat"
Write-Host "(veya /hooks menusunu bir kez ac)."
Write-Host ""
Write-Host "Kapatmak icin: ~/.claude/settings.json icinde hooks.Stop altindaki"
Write-Host "ste-tr-denetim.ps1 girdisini silin."
