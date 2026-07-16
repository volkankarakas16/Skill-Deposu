# find-skills becerisini (vercel-labs/skills ekosisteminin "skill bulucu"su)
# GLOBAL olarak kurar. Bu beceri, ne yaptigini anlattiginda skills.sh / GitHub
# katalogundan uygun skilleri bulup "npx skills add" ile kurmana yardim eder.
#
# NOT: Bu, bizim claude plugin / marketplace sistemimizden AYRI bir ekosistem
# (npx skills). find-skills'in kurdugu skiller ~/.claude/skills/ altina duser ve
# global skill-oneri hook'umuz tarafindan her projede gorulur/onerilir.
# Kendi guncellemesi ayridir: "npx skills update".
#
# Gereksinim: Node.js / npx (node -v ile kontrol et).
# Kullanim: git pull sonrasi (ozellikle yeni bir bilgisayarda)
#   powershell -ExecutionPolicy Bypass -File install-find-skills.ps1

$ErrorActionPreference = "Stop"

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Write-Warning "npx bulunamadi. find-skills icin Node.js gerekli: https://nodejs.org"
    Write-Warning "Node kurduktan sonra bu scripti tekrar calistir."
    return
}

Write-Host "find-skills global olarak kuruluyor (npx skills add)..."
npx -y skills add vercel-labs/skills@find-skills -g -y

Write-Host ""
Write-Host "Tamamlandi. Skill'in yuklenmesi icin Claude Code'u yeniden baslat."
Write-Host "Not: find-skills ile ileride kurulan skiller ~/.agents/.skill-lock.json'a"
Write-Host "kaydedilir ve 'npx skills update' ile guncellenir."
