# ste-tr-denetim.ps1'i Stop ve UserPromptSubmit olaylarina baglar (uyari
# modu). Claude cevabi bitirince son mesaj STE-TR kurallarina gore denetlenir.
# Ihlal varsa cevap ENGELLENMEZ: ihlaller not edilir ve sonraki istekte
# Claude'a talimat olarak eklenir. Boylece cevap hep tek gelir.
#
# Hook GLOBAL kurulur: ~/.claude/settings.json. Hangi klasorde Claude Code
# acilirsa acilsin calisir, tek bir projeye bagli degildir.
#
# Mevcut hook'lari BOZMAZ. Yalnizca kendi girdisini tazeler ve iki kez
# kurulmaz. Eski engelleyen surumun girdisi de tazelenir.
#
# Kullanim: git pull sonrasi (ozellikle yeni bir bilgisayarda)
#   powershell -ExecutionPolicy Bypass -File install-ste-tr-hook.ps1

$ErrorActionPreference = "Stop"
$SettingsPath = "$env:USERPROFILE\.claude\settings.json"
$NoBomUtf8 = New-Object System.Text.UTF8Encoding $false

function Write-JsonNoBom($obj) {
    [System.IO.File]::WriteAllText($SettingsPath, ($obj | ConvertTo-Json -Depth 20), $NoBomUtf8)
}

function Ensure-Entry($json, $event, $command, $isMine) {
    # Olay yoksa olustur. Diger hook'lara dokunmadan yalnizca bu betigin
    # girdisini tazeler. Degisiklik olduysa $true doner.
    if (-not ($json.hooks.PSObject.Properties.Name -contains $event)) {
        $json.hooks | Add-Member -MemberType NoteProperty -Name $event -Value @()
    }
    $mevcut = @()
    foreach ($entry in $json.hooks.$event) {
        foreach ($h in $entry.hooks) { if (& $isMine $h.command) { $mevcut += $h.command } }
    }
    if ($mevcut.Count -eq 1 -and $mevcut[0] -eq $command) { return $false }

    $kalan = @()
    foreach ($entry in $json.hooks.$event) {
        $entry.hooks = @($entry.hooks | Where-Object { -not (& $isMine $_.command) })
        if ($entry.hooks.Count -gt 0) { $kalan += $entry }
    }
    $kalan += [PSCustomObject]@{
        hooks = @([PSCustomObject]@{ type = "command"; command = $command; timeout = 20 })
    }
    $json.hooks.$event = $kalan
    return $true
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
    $base = "powershell -ExecutionPolicy Bypass -File `"$scriptPath`""

    $json = Get-Content $SettingsPath -Raw | ConvertFrom-Json
    if (-not $json.hooks) {
        $json | Add-Member -MemberType NoteProperty -Name hooks -Value ([PSCustomObject]@{})
    }

    # Uyari modu: Stop ihlali not eder, UserPromptSubmit notu sonraki
    # cevaba ekler. Eski engelleyen surumun girdisi ayni komutla tazelenir.
    $isMine = { param($c) $c -like "*ste-tr-denetim.ps1*" }
    $d1 = Ensure-Entry $json "Stop" $base $isMine
    $d2 = Ensure-Entry $json "UserPromptSubmit" "$base -Istem" $isMine

    if ($d1 -or $d2) {
        Write-JsonNoBom $json
        Write-Host "settings.json guncellendi: STE-TR hook'lari (Stop + UserPromptSubmit) kuruldu."
    } else {
        Write-Host "STE-TR hook'lari zaten kurulu, atlaniyor."
    }
}

Ensure-SteTrHook

Write-Host ""
Write-Host "Tamamlandi. Hook'un aktif olmasi icin Claude Code'u yeniden baslat"
Write-Host "(veya /hooks menusunu bir kez ac)."
Write-Host ""
Write-Host "Kapatmak icin: ~/.claude/settings.json icinde hooks.Stop altindaki"
Write-Host "ste-tr-denetim.ps1 girdisini silin."
