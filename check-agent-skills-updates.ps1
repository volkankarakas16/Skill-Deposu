# find-skills / npx skills ekosistemi icin oturum-basi otomatik guncelleyici.
# Her Claude Code oturumu basinda (SessionStart) calisir; throttle geceliyse
# (varsayilan 6 saat) kendini -Apply ile ARKA PLANDA (gizli pencere) cagirip
# "npx skills update -y" komutunu calistirir. Bloklamaz. Bu, plugin sistemimizin
# check-skill-updates.ps1 -> apply-skill-updates.ps1 kalibinin skills.sh
# ekosistemindeki karsiligidir; iki sistem ayri kalir, sadece guncelleme
# otomasyonu paralel calisir.
#
# Kapatmak icin: ~/.claude/agent-skills-autoupdate-off adinda bos dosya olustur.
#
# Normalde elle calistirilmaz - install-agent-skills-update-hook.ps1'in kurdugu
# SessionStart hook'u bunu cagirir.

param([switch]$Apply)

$ErrorActionPreference = "Continue"
$StatePath = "$env:USERPROFILE\.claude\agent-skills-update-state.json"
$LogPath   = "$env:USERPROFILE\.claude\agent-skills-update.log"
$OffMarker = "$env:USERPROFILE\.claude\agent-skills-autoupdate-off"
$LockPath  = "$env:USERPROFILE\.agents\.skill-lock.json"
$ThrottleHours = 6
$NoBomUtf8 = New-Object System.Text.UTF8Encoding $false

# ----- APPLY MODU: arka planda gercek guncelleme (npx skills update) -----
if ($Apply) {
    Add-Content -Path $LogPath -Value ("[{0}] === npx skills update basladi ===" -f (Get-Date).ToString("s")) -Encoding UTF8
    try {
        npx -y skills update -y 2>&1 | ForEach-Object { Add-Content -Path $LogPath -Value "  $_" -Encoding UTF8 }
    } catch {
        Add-Content -Path $LogPath -Value "  HATA: $_" -Encoding UTF8
    }
    Add-Content -Path $LogPath -Value ("[{0}] === bitti. Guncellemelerin aktif olmasi icin Claude Code'u yeniden baslat. ===" -f (Get-Date).ToString("s")) -Encoding UTF8
    return
}

# ----- DETEKTOR MODU: SessionStart hook'u burayi cagirir -----
function Write-Context($text) {
    $output = [PSCustomObject]@{
        hookSpecificOutput = [PSCustomObject]@{
            hookEventName     = "SessionStart"
            additionalContext = $text
        }
    }
    $output | ConvertTo-Json -Depth 5 -Compress
}

if (Test-Path $OffMarker) { exit 0 }
if (-not (Get-Command npx -ErrorAction SilentlyContinue)) { exit 0 }

# Throttle: son calismadan bu yana $ThrottleHours saat gecmediyse sessizce cik
if (Test-Path $StatePath) {
    try {
        $state = Get-Content $StatePath -Raw | ConvertFrom-Json
        if ($state._lastCheckedUtc) {
            $last = [datetime]::Parse($state._lastCheckedUtc)
            if (((Get-Date).ToUniversalTime() - $last).TotalHours -lt $ThrottleHours) { exit 0 }
        }
    } catch { }
}

# Kurulu skills.sh skill'i var mi? Yoksa npx'i bosuna calistirma.
$hasSkills = $false
if (Test-Path $LockPath) {
    try {
        $lock = Get-Content $LockPath -Raw | ConvertFrom-Json
        if ($lock.skills -and @($lock.skills.PSObject.Properties.Name).Count -gt 0) { $hasSkills = $true }
    } catch { }
}

# Throttle zaman damgasini her denemede guncelle (bos halde de spam olmasin)
$newState = [PSCustomObject]@{ _lastCheckedUtc = (Get-Date).ToUniversalTime().ToString("o") }
[System.IO.File]::WriteAllText($StatePath, ($newState | ConvertTo-Json), $NoBomUtf8)

if (-not $hasSkills) { exit 0 }

# Kendini -Apply ile arka planda (gizli pencere) cagir; oturum acilisini bloklamaz
$self = $PSCommandPath
$spawned = $false
try {
    Start-Process -FilePath "powershell" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$self`"", "-Apply") `
        -WindowStyle Hidden | Out-Null
    $spawned = $true
} catch { }

if ($spawned) {
    Write-Context "npx skills (skills.sh) guncellemesi arka planda baslatildi (log: ~/.claude/agent-skills-update.log). Bitince Claude Code'u yeniden baslat."
}
