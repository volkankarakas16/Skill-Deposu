# find-skills / npx skills ile GLOBAL kurulan skillerin kaydini tutan
# ~/.agents/.skill-lock.json dosyasini repo icine (agent-skills-lock.json)
# kopyalar. Boylece commit + push ile diger bilgisayara senkronlanabilir.
#
# Kullanim: find-skills ile yeni bir skill kurduktan SONRA calistir, ardindan
# commit + push yap:
#   powershell -ExecutionPolicy Bypass -File export-agent-skills.ps1
#   git add agent-skills-lock.json; git commit -m "..."; git push

$ErrorActionPreference = "Stop"
$lock = "$env:USERPROFILE\.agents\.skill-lock.json"
$dest = Join-Path $PSScriptRoot "agent-skills-lock.json"

if (-not (Test-Path $lock)) {
    Write-Warning "$lock bulunamadi. Once find-skills ile en az bir skill kur."
    return
}

Copy-Item $lock $dest -Force
$json = Get-Content $dest -Raw | ConvertFrom-Json
$count = @($json.skills.PSObject.Properties.Name).Count
Write-Host "Kopyalandi: agent-skills-lock.json ($count skill)"
Write-Host "Simdi senkron icin: git add agent-skills-lock.json; git commit; git push"
