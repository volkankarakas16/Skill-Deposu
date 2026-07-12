# Headroom (token-tasarrufu proxy) tam kurulumu.
# install-claude-skills.ps1, headroom Claude Code plugin'ini (sadece hook'lari) kurar.
# Bu script ise asil calisan parcayi kurar: headroom CLI + kalici (durable) proxy routing.
#
# Kullanim: powershell -ExecutionPolicy Bypass -File install-headroom.ps1
#
# ONEMLI - bu scripti calistirmadan once:
#   Yonetici (Admin) PowerShell'de su komutu calistir (Windows Defender bazi
#   antivirus taramalarinda ast-grep-cli'nin sg.exe dosyasini yanlis pozitif
#   olarak engelleyebiliyor):
#     Add-MpPreference -ExclusionPath "$env:APPDATA\uv\tools\headroom-ai"

$ErrorActionPreference = "Stop"

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

function Ensure-DurableInit {
    Write-Host "Kalici (durable) Claude Code entegrasyonu kuruluyor..."
    headroom init --global claude
}

function Ensure-Routing {
    $settingsPath = "$env:USERPROFILE\.claude\settings.json"
    if (-not (Test-Path $settingsPath)) {
        Write-Warning "$settingsPath bulunamadi, routing ayari atlaniyor."
        return
    }

    $json = Get-Content $settingsPath -Raw | ConvertFrom-Json

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

    ($json | ConvertTo-Json -Depth 20) | Set-Content -Path $settingsPath -Encoding UTF8
    Write-Host "settings.json guncellendi: ANTHROPIC_BASE_URL=http://127.0.0.1:8787"
}

Ensure-Uv
Ensure-HeadroomCli
Ensure-DurableInit
Ensure-Routing

Write-Host ""
Write-Host "Kurulum tamamlandi. Claude Code'u yeniden baslat, ardindan dogrulamak icin:"
Write-Host "  headroom doctor"
