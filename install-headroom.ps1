# Headroom (token-tasarrufu proxy) tam kurulumu.
# headroom@headroom-marketplace plugin'ini AYRICA kurma - o plugin'in kendi
# PreToolUse hook'u bu scriptin settings.json'a yazdigi hook ile cakisip
# her Bash/PowerShell komutunda gorunur bir cmd penceresi acilmasina sebep
# oluyor. Bu script tek basina yeterli: headroom CLI + kalici (durable)
# proxy routing + self-healing arka plan servisi kurar.
#
# Kullanim: powershell -ExecutionPolicy Bypass -File install-headroom.ps1
#
# ONEMLI - bu script iki yerde Admin (Yonetici) PowerShell isteyebilir:
#   1) Windows Defender bazen ast-grep-cli'nin sg.exe dosyasini yanlis
#      pozitif olarak engelliyor. Engellenirse Admin PowerShell'de:
#        Add-MpPreference -ExclusionPath "$env:APPDATA\uv\tools\headroom-ai"
#      calistirip bu scripti tekrar baslat.
#   2) Self-healing Scheduled Task kaydi da admin istiyor. Script admin
#      degilse bunu atlar ve calistirman gereken komutu ekrana yazar.
#   3) Scheduled Task, headroom.exe'yi dogrudan degil wscript.exe uzerinden
#      gizli bir .vbs baslatici ile cagirir; boylece 5 dakikada bir "port
#      kullanimda" kontrolu ekranda gorunur bir cmd penceresi acmaz.
#
# Bu script tekrar tekrar calistirilabilir (idempotent) - zaten kurulu olan
# adimlari atlar. Ozellikle "headroom init --global claude" komutu
# settings.json'i sifirdan yaziyor ve effortLevel gibi ilgisiz alanlari
# silip plugin referansini geri ekleyebiliyor; bu yuzden zaten kuruluysa
# BIR DAHA calistirilmiyor.

$ErrorActionPreference = "Stop"
$SettingsPath = "$env:USERPROFILE\.claude\settings.json"
$DurableMarker = "headroom-init-claude"
$VbsWrapperPath = "$env:USERPROFILE\.local\bin\headroom-proxy-silent.vbs"
$NoBomUtf8 = New-Object System.Text.UTF8Encoding $false

function Write-JsonNoBom($obj) {
    [System.IO.File]::WriteAllText($SettingsPath, ($obj | ConvertTo-Json -Depth 20), $NoBomUtf8)
}

function Ensure-Uv {
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Host "uv zaten kurulu."
        return
    }
    Write-Host "uv kuruluyor..."
    powershell -ExecutionPolicy Bypass -Command "irm https://astral.sh/uv/install.ps1 | iex"
    $localBin = "$env:USERPROFILE\.local\bin"
    if ($env:Path -notlike "*$localBin*") {
        $env:Path = "$localBin;$env:Path"
    }
}

function Ensure-HeadroomCli {
    if (Get-Command headroom -ErrorAction SilentlyContinue) {
        Write-Host "headroom CLI zaten kurulu."
        return
    }
    Write-Host "headroom CLI kuruluyor (uv tool install)..."
    Write-Host "Not: sg.exe (ast-grep-cli) antivirus tarafindan engellenirse yukaridaki"
    Write-Host "Add-MpPreference komutunu Admin PowerShell'de calistirip tekrar dene."
    uv tool install "headroom-ai[all]"
}

function Test-DurableInitDone {
    if (-not (Test-Path $SettingsPath)) { return $false }
    $json = Get-Content $SettingsPath -Raw | ConvertFrom-Json
    if (-not $json.hooks -or -not $json.hooks.SessionStart) { return $false }
    foreach ($entry in $json.hooks.SessionStart) {
        foreach ($h in $entry.hooks) {
            if ($h.command -like "*$DurableMarker*") { return $true }
        }
    }
    return $false
}

function Ensure-DurableInit {
    # headroom init --global claude, settings.json'i baztan yazdigi icin
    # (effortLevel gibi ilgisiz alanlari silip plugin referansi ekleyebiliyor)
    # sadece hic kurulmamissa calistiriyoruz.
    if (Test-DurableInitDone) {
        Write-Host "Kalici (durable) Claude Code entegrasyonu zaten kurulu, atlaniyor."
        return
    }
    Write-Host "Kalici (durable) Claude Code entegrasyonu kuruluyor..."
    headroom init --global claude
}

function Remove-PreToolUseHook {
    # headroom init --global claude, settings.json'a hem SessionStart hem de
    # PreToolUse hook'u yazar. PreToolUse, Bash/PowerShell CALISTIRDIGIMIZ HER
    # SEFERDE gorunur bir cmd penceresi acilmasina sebep oluyor. SessionStart
    # tek basina yeterli (proxy'yi oturum basinda ayaga kaldirir), o yuzden
    # PreToolUse'u kaldiriyoruz.
    if (-not (Test-Path $SettingsPath)) { return }

    $json = Get-Content $SettingsPath -Raw | ConvertFrom-Json
    if ($json.hooks -and $json.hooks.PSObject.Properties.Name -contains "PreToolUse") {
        $json.hooks.PSObject.Properties.Remove("PreToolUse")
        Write-JsonNoBom $json
        Write-Host "settings.json: fazladan PreToolUse hook'u kaldirildi (cmd penceresi sorunu icin)."
    }
}

function Remove-PhantomPlugin {
    # headroom init --global claude bazen enabledPlugins'e
    # headroom@headroom-marketplace = true yaziyor, oysa bu plugin bilerek
    # kaldirilmisti (kendi PreToolUse hook'u cakisiyordu). Gercekte kurulu
    # olmayan bu hayalet referansi temizle.
    if (-not (Test-Path $SettingsPath)) { return }

    $json = Get-Content $SettingsPath -Raw | ConvertFrom-Json
    if ($json.enabledPlugins -and ($json.enabledPlugins.PSObject.Properties.Name -contains "headroom@headroom-marketplace")) {
        $json.enabledPlugins.PSObject.Properties.Remove("headroom@headroom-marketplace")
        Write-JsonNoBom $json
        Write-Host "settings.json: hayalet headroom@headroom-marketplace plugin referansi kaldirildi."
    }
}

function Ensure-Routing {
    if (-not (Test-Path $SettingsPath)) {
        Write-Warning "$SettingsPath bulunamadi, routing ayari atlaniyor."
        return
    }

    $json = Get-Content $SettingsPath -Raw | ConvertFrom-Json

    if (-not $json.env) {
        $json | Add-Member -MemberType NoteProperty -Name env -Value ([PSCustomObject]@{})
    }

    if ($json.env.PSObject.Properties.Name -contains "ANTHROPIC_BASE_URL" -and $json.env.ANTHROPIC_BASE_URL -eq "http://127.0.0.1:8787") {
        Write-Host "Routing zaten ayarli."
        return
    }

    if ($json.env.PSObject.Properties.Name -contains "ANTHROPIC_BASE_URL") {
        $json.env.ANTHROPIC_BASE_URL = "http://127.0.0.1:8787"
    } else {
        $json.env | Add-Member -MemberType NoteProperty -Name ANTHROPIC_BASE_URL -Value "http://127.0.0.1:8787"
    }

    Write-JsonNoBom $json
    Write-Host "settings.json guncellendi: ANTHROPIC_BASE_URL=http://127.0.0.1:8787"
}

function Ensure-OutputShaper {
    # Output-shaper, headroom'un yanit uzunlugunu ogrenilen kullanici
    # tercihine gore ayarlayip output-token tasarrufu saglayan opsiyonel
    # katman. HEADROOM_OUTPUT_SHAPER proxy yeniden baslasa/farkli bilgisayarda
    # kurulsa bile kalici acik kalsin diye settings.json env blogune
    # yaziliyor (ANTHROPIC_BASE_URL ile ayni yontem).
    if (-not (Test-Path $SettingsPath)) {
        Write-Warning "$SettingsPath bulunamadi, output-shaper ayari atlaniyor."
        return
    }

    $json = Get-Content $SettingsPath -Raw | ConvertFrom-Json

    if (-not $json.env) {
        $json | Add-Member -MemberType NoteProperty -Name env -Value ([PSCustomObject]@{})
    }

    if ($json.env.PSObject.Properties.Name -contains "HEADROOM_OUTPUT_SHAPER" -and $json.env.HEADROOM_OUTPUT_SHAPER -eq "1") {
        Write-Host "Output-shaper zaten kalici olarak ayarli."
        return
    }

    if ($json.env.PSObject.Properties.Name -contains "HEADROOM_OUTPUT_SHAPER") {
        $json.env.HEADROOM_OUTPUT_SHAPER = "1"
    } else {
        $json.env | Add-Member -MemberType NoteProperty -Name HEADROOM_OUTPUT_SHAPER -Value "1"
    }

    Write-JsonNoBom $json
    Write-Host "settings.json guncellendi: HEADROOM_OUTPUT_SHAPER=1 (kalici)"
}

function Ensure-HiddenProxyLauncher {
    # Scheduled Task headroom.exe'yi DOGRUDAN cagirirsa (proxy zaten calisiyor
    # oldugu icin hemen "port kullanimda" hatasiyla kapansa bile) her 5
    # dakikada bir gorunur bir cmd penceresi ekranda yanip sonuyor.
    # New-ScheduledTaskSettingsSet -Hidden SADECE Task Scheduler listesinde
    # task'i gizler, baslattigi process'in konsol penceresini gizlemez. Bu
    # yuzden headroom.exe'yi wscript.exe uzerinden, WshShell.Run'in 0 (gizli
    # pencere) parametresiyle baslatan bir .vbs kullaniyoruz.
    $exe = "$env:USERPROFILE\.local\bin\headroom.exe"
    $vbsContent = @'
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run """{0}"" proxy", 0, False
'@ -f $exe
    [System.IO.File]::WriteAllText($VbsWrapperPath, $vbsContent, $NoBomUtf8)
}

function Test-ScheduledTaskHidden {
    $task = Get-ScheduledTask -TaskName "HeadroomProxy" -ErrorAction SilentlyContinue
    if (-not $task) { return $false }
    $action = $task.Actions | Select-Object -First 1
    return ($action.Execute -like "*wscript*")
}

function Ensure-ScheduledTask {
    # Proxy sadece Claude Code SessionStart hook'una bagimli kalirsa, oturum
    # ortasinda olduğunde (uyku/uyanma, cokme) bir sonraki Claude Code
    # acilisina kadar ConnectionRefused riski var. Bu yuzden proxy'yi ayrica
    # 5 dakikada bir kontrol edip olmusse yeniden baslatan, terminalden
    # bagimsiz bir Scheduled Task kaydediyoruz (self-healing). wscript.exe
    # baslatici sayesinde bu kontroller ekranda pencere acmadan calisir.
    Ensure-HiddenProxyLauncher

    if (Test-ScheduledTaskHidden) {
        Write-Host "HeadroomProxy scheduled task zaten kurulu (gizli baslatici ile)."
        return
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host ""
        Write-Warning "HeadroomProxy scheduled task (gizli baslatici) admin yetkisi istiyor, atlandi."
        Write-Host "Kalici/self-healing/gizli proxy icin Admin PowerShell'de sunu calistir:"
        Write-Host (@'
$action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument '"{0}"'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -Hidden -MultipleInstances IgnoreNew -ExecutionTimeLimit 0 -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Unregister-ScheduledTask -TaskName "HeadroomProxy" -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName "HeadroomProxy" -Action $action -Trigger @($logonTrigger, $trigger) -Settings $settings -RunLevel Limited -Force
Start-ScheduledTask -TaskName "HeadroomProxy"
'@ -f $VbsWrapperPath)
        return
    }

    if (Get-ScheduledTask -TaskName "HeadroomProxy" -ErrorAction SilentlyContinue) {
        Write-Host "Eski HeadroomProxy task'i (gorunur pencereli) kaldirilip gizli baslatici ile yeniden kuruluyor..."
        Unregister-ScheduledTask -TaskName "HeadroomProxy" -Confirm:$false
    }

    $action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$VbsWrapperPath`""
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)
    $logonTrigger = New-ScheduledTaskTrigger -AtLogOn
    $taskSettings = New-ScheduledTaskSettingsSet -Hidden -MultipleInstances IgnoreNew -ExecutionTimeLimit 0 -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    Register-ScheduledTask -TaskName "HeadroomProxy" -Action $action -Trigger @($logonTrigger, $trigger) -Settings $taskSettings -RunLevel Limited -Force
    Start-ScheduledTask -TaskName "HeadroomProxy"
    Write-Host "HeadroomProxy scheduled task kuruldu ve baslatildi (gizli, pencere acilmiyor)."
}

Ensure-Uv
Ensure-HeadroomCli
Ensure-DurableInit
Remove-PreToolUseHook
Remove-PhantomPlugin
Ensure-Routing
Ensure-OutputShaper
Ensure-ScheduledTask

Write-Host ""
Write-Host "Kurulum tamamlandi. Claude Code'u yeniden baslat, ardindan dogrulamak icin:"
Write-Host "  headroom doctor"
