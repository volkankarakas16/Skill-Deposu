# Takip edilen GitHub marketplace repolarinda (claude-marketplaces.txt) yeni
# commit olup olmadigini kontrol eder ve sonucu SessionStart hook'unun
# bekledigi JSON formatinda (hookSpecificOutput.additionalContext) stdout'a
# yazar. Boylece aktif Claude oturum basinda kullaniciya durumu bildirebilir.
#
# Normalde elle calistirilmaz - ~/.claude/settings.json'daki SessionStart
# hook'u (install-skill-update-hook.ps1 tarafindan kurulur) bunu her oturum
# basinda otomatik cagirir.
#
# Rate-limit/gereksiz trafik icin: son basarili kontrolden bu yana
# $ThrottleHours saat gecmediyse GitHub'a hic gitmeden sessizce cikar.

$ErrorActionPreference = "Stop"
$RepoRoot = $PSScriptRoot
$MarketplacesFile = Join-Path $RepoRoot "claude-marketplaces.txt"
$StatePath = "$env:USERPROFILE\.claude\skill-update-state.json"
$ThrottleHours = 6
$NoBomUtf8 = New-Object System.Text.UTF8Encoding $false

function Write-Context($text) {
    $output = [PSCustomObject]@{
        hookSpecificOutput = [PSCustomObject]@{
            hookEventName     = "SessionStart"
            additionalContext = $text
        }
    }
    $output | ConvertTo-Json -Depth 5 -Compress
}

function Load-State {
    if (Test-Path $StatePath) {
        try {
            return Get-Content $StatePath -Raw | ConvertFrom-Json
        } catch {
            return [PSCustomObject]@{}
        }
    }
    return [PSCustomObject]@{}
}

function Set-StateValue($state, $key, $value) {
    if ($state.PSObject.Properties.Name -contains $key) {
        $state.$key = $value
    } else {
        $state | Add-Member -MemberType NoteProperty -Name $key -Value $value
    }
}

function Save-State($state) {
    $dir = Split-Path $StatePath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($StatePath, ($state | ConvertTo-Json -Depth 5), $NoBomUtf8)
}

if (-not (Test-Path $MarketplacesFile)) {
    Write-Context "Skill guncelleme kontrolu yapilamadi: claude-marketplaces.txt bulunamadi ($MarketplacesFile)."
    exit 0
}

$state = Load-State

if ($state.PSObject.Properties.Name -contains "_lastCheckedUtc") {
    $lastChecked = [datetime]::Parse($state._lastCheckedUtc)
    if (((Get-Date).ToUniversalTime() - $lastChecked).TotalHours -lt $ThrottleHours) {
        exit 0
    }
}

$repos = Get-Content $MarketplacesFile |
    Where-Object { $_ -and -not $_.TrimStart().StartsWith("#") } |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne "" }

$updated = @()
$failed = @()

foreach ($repo in $repos) {
    try {
        $headers = @{ "User-Agent" = "ClaudeProjeler-skill-update-check" }
        $commits = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/commits?per_page=1" -Headers $headers -TimeoutSec 10
        if (-not $commits -or $commits.Count -eq 0) { continue }
        $latest = $commits[0]
        $sha = $latest.sha
        $message = ($latest.commit.message -split "`n")[0]

        $prevSha = $null
        if ($state.PSObject.Properties.Name -contains $repo) { $prevSha = $state.$repo }

        if ($prevSha -and $prevSha -ne $sha) {
            $updated += "$repo : $message ($($sha.Substring(0,7)))"
        }
        Set-StateValue $state $repo $sha
    } catch {
        $failed += $repo
    }
}

Set-StateValue $state "_lastCheckedUtc" ((Get-Date).ToUniversalTime().ToString("o"))
Save-State $state

if ($updated.Count -gt 0) {
    $text = "Skill guncelleme kontrolu: $($updated.Count) repoda yeni commit var:`n" + ($updated -join "`n")
} else {
    $text = "Skill guncelleme kontrolu: izlenen $($repos.Count) repoda yeni bir sey yok."
}
if ($failed.Count -gt 0) {
    $text += "`n(Kontrol edilemeyen: $($failed -join ', '))"
}

Write-Context $text
