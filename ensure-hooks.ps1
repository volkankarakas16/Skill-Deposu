# Kurulumu kendiliginden tamamlar. Elle komut girmeye gerek birakmaz.
#
# Sorun: her yeni hook icin kullanici her bilgisayarda ayri ayri
# "install-...ps1" calistirmak zorunda kaliyordu. Unutulan bir kurulum
# sessizce eksik kaliyor -- kural dosyasi guncel, hook yok.
#
# Cozum: bu betik oturum basinda calisir ve HOOK kurulumlarinin hepsini
# idempotent olarak tazeler. check-skill-updates.ps1 en basta bunu cagirir,
# o da zaten SessionStart'a bagli. Yani `git pull` sonrasi ilk oturumda
# eksikler kendiliginden kurulur.
#
# Yalnizca HIZLI ve idempotent kurulumlar burada: CLAUDE.md kopyalama ve
# settings.json hook girdileri. Plugin kuran betikler (install-claude-skills,
# install-agent-skills) BILEREK disarida -- onlar dakikalarca surebiliyor ve
# oturum acilisini bekletirdi.
#
# Damga: Skill Deposu'nun HEAD commit'i degismediyse hic calismaz. Boylece
# her oturumda bes betik bosuna kosmaz.

$ErrorActionPreference = "Continue"
$RepoRoot = $PSScriptRoot

# Alt surec acmadan, ayni surecte calisacak kurulumlar. Sira onemsiz,
# hepsi birbirinden bagimsiz.
$Kurulumlar = @(
    "install-global-claude-md.ps1",
    "install-skill-suggestion-hook.ps1",
    "install-skill-update-hook.ps1",
    "install-agent-skills-update-hook.ps1",
    "install-ste-tr-hook.ps1"
)

function Get-RepoHead {
    try {
        $h = & git -C $RepoRoot rev-parse HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $h) { return $h.Trim() }
    } catch { }
    return $null
}

function Ensure-Hooks {
    $head = Get-RepoHead
    $damga = "$env:USERPROFILE\.claude\hooks-ensured"

    # Damga tutuyorsa hic calisma. HEAD okunamadiysa (git yok, depo degil)
    # damgaya guvenmeyip her seferinde calisiyoruz -- eksik kurulumdan iyi.
    if ($head -and (Test-Path $damga)) {
        try {
            if ((Get-Content $damga -Raw -ErrorAction Stop).Trim() -eq $head) { return }
        } catch { }
    }

    foreach ($ad in $Kurulumlar) {
        $yol = Join-Path $RepoRoot $ad
        if (-not (Test-Path $yol)) { continue }
        try {
            # Cikti YUTULUYOR: bu betiklerin Write-Host satirlari SessionStart
            # hook'unun JSON ciktisina karisirsa hook ciktisi bozulur.
            & $yol *> $null
        } catch {
            # Tek bir kurulumun patlamasi oturum acilisini KIRMAMALI.
            # Sessiz kalmiyoruz ama akisa da karismiyoruz.
            [Console]::Error.WriteLine("ensure-hooks: $ad basarisiz - $($_.Exception.Message)")
        }
    }

    if ($head) {
        try {
            $NoBom = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($damga, $head, $NoBom)
        } catch { }
    }
}

Ensure-Hooks
