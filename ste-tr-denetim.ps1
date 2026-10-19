# STE-TR yazim denetimi -- Stop hook.
#
# UYARI MODU, iki asamali (ste-tr-denetim.py ile ayni):
#   Stop             -> SON asistan mesajini denetler. Ihlal varsa cevabi
#                       ENGELLEMEZ, oturuma ozel bir not dosyasina yazar.
#   UserPromptSubmit -> (-Istem) not varsa sonraki cevaba talimat olarak
#                       ekler ve notu siler.
#
# Neden engellemiyor: engellenen cevap ekranda zaten gorunuyordu. Claude
# duzeltmeyi ikinci bir mesaj olarak yaziyordu. Kullanici ayni cevabi iki
# kez goruyor, cikti token'i ikiye katlaniyordu (2026-10-19).
#
# Neden gerekli: skill-suggestion-reminder.ps1 kurali her istekte
# HATIRLATIYOR ama hatirlatma yetmiyor. 2026-10-11'de kullanici, kuralin
# hatirlatmaya ragmen uygulanmadigini bildirdi. Hatirlatma istekten ONCE
# calisiyor ve cevabi goremiyor. Bu betik cevabi GORUYOR.
#
#
# Olcum kod DISINDA yapilir. Kod blogu, satir ici kod, tablo ve baglanti
# adresi elenir: oralardaki noktali virgul ve uzun satir yazim hatasi degil.

param([switch]$Istem)

$ErrorActionPreference = "Stop"

# PowerShell 5.1 stdout'u sistemin kod sayfasiyla (Turkce Windows'ta
# cp1254) yaziyor ve JSON icindeki Turkce harfler bozuluyor. Claude'a
# "ko?ul" diye ulasan bir uyari okunmaz. Akis UTF-8 olmak ZORUNDA.
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

# --- girdi ---------------------------------------------------------------
$ham = [Console]::In.ReadToEnd()
if (-not $ham) { exit 0 }

try { $girdi = $ham | ConvertFrom-Json } catch { exit 0 }

# Oturuma ozel not dosyasi. Oturum kimligindeki yol karakterleri ayiklanir.
$notDizini = Join-Path $env:USERPROFILE ".claude\ste-tr-notlar"
$sid = ([string]$girdi.session_id) -replace '[^A-Za-z0-9_-]', ''
if (-not $sid) { $sid = "oturum" }
$notYolu = Join-Path $notDizini "$sid.txt"
$NoBomUtf8 = New-Object System.Text.UTF8Encoding $false

# --- UserPromptSubmit: notu sonraki cevaba ekle --------------------------
if ($Istem) {
    if (-not (Test-Path $notYolu)) { exit 0 }
    $not = [System.IO.File]::ReadAllText($notYolu, $NoBomUtf8)
    Remove-Item $notYolu -Force
    @{ hookSpecificOutput = @{ hookEventName = "UserPromptSubmit"
                               additionalContext = $not } } |
        ConvertTo-Json -Compress -Depth 5
    exit 0
}

# Eski surumden kalan yeniden yazma turunda tekrar denetleme.
if ($girdi.stop_hook_active -eq $true) { exit 0 }

$yol = $girdi.transcript_path
if (-not $yol -or -not (Test-Path $yol)) { exit 0 }

# --- son asistan metnini cek ---------------------------------------------
# Transcript JSONL. Sondan geriye tarayip ilk asistan METIN mesajini aliyoruz;
# arac cagrilari metin tasimaz, onlar atlanir.
$metin = ""
# Dosyanin yalnizca son 4 MB'i okunur. Get-Content -Tail cok uzun satirli
# transcript'te yavas: 2 MB'lik bir dosyada 29 sn olculdu, hook 20 sn'de
# kesiliyor. ReadWrite paylasimi: Claude dosyaya yazmaya devam ediyor.
# 1500 satir: uzun arac dizilerinde son METIN mesaji cok geride kalabilir.
$fs = [System.IO.File]::Open($yol, 'Open', 'Read', 'ReadWrite')
try {
    $bas = [Math]::Max(0, $fs.Length - 4MB)
    [void]$fs.Seek($bas, 'Begin')
    $buf = New-Object byte[] ($fs.Length - $bas)
    $okunan = 0
    while ($okunan -lt $buf.Length) {
        $n = $fs.Read($buf, $okunan, $buf.Length - $okunan)
        if ($n -le 0) { break }
        $okunan += $n
    }
} finally { $fs.Close() }
# Yarim kalan ilk satir JSON olarak cozulemez ve dongude atlanir.
$satirlar = [System.Text.Encoding]::UTF8.GetString($buf, 0, $okunan) -split "`r?`n"
if ($satirlar.Count -gt 1500) {
    $satirlar = $satirlar[($satirlar.Count - 1500)..($satirlar.Count - 1)]
}
for ($i = $satirlar.Count - 1; $i -ge 0; $i--) {
    $s = $satirlar[$i]
    if (-not $s) { continue }
    try { $o = $s | ConvertFrom-Json } catch { continue }
    # Gercek kullanici mesajinda dur: bu turda metin yoksa onceki turun
    # cevabi yeniden engellenmesin. Arac sonucu (tool_result) ve sistem
    # hatirlatmasi (isMeta) turu bitirmez.
    if ($o.type -eq "user" -and -not $o.isMeta) {
        $c = $o.message.content
        if ($c -is [string]) { break }
        if (@($c | Where-Object { $_.type -eq "text" }).Count -gt 0) { break }
        continue
    }
    if ($o.type -ne "assistant") { continue }
    $parcalar = $o.message.content
    if (-not $parcalar) { continue }
    $yazi = ($parcalar | Where-Object { $_.type -eq "text" } |
             ForEach-Object { $_.text }) -join "`n"
    if ($yazi -and $yazi.Trim().Length -gt 0) { $metin = $yazi; break }
}
if (-not $metin) { exit 0 }

# --- markdown temizligi ---------------------------------------------------
# Sira onemli: once uc tirnakli bloklar, sonra satir ici kod. Ters sirada
# blok icindeki tek tirnaklar yanlis eslesir.
$t = $metin
$t = [regex]::Replace($t, '(?s)```.*?```', ' ')           # kod blogu
$t = [regex]::Replace($t, '`[^`]*`', ' K ')               # satir ici kod
$t = [regex]::Replace($t, '(?m)^\s*\|.*$', ' ')           # tablo satiri
$t = [regex]::Replace($t, '\[([^\]]*)\]\([^\)]*\)', '$1')  # baglanti -> metin
$t = [regex]::Replace($t, 'https?://\S+', ' K ')          # cıplak adres
$t = [regex]::Replace($t, '[*_#>]', ' ')                  # vurgu ve baslik
$t = [regex]::Replace($t, '(?m)^\s*[-+]\s+', '')          # madde isareti

# --- cumlelere bol --------------------------------------------------------
# Nokta tek basina yetmez: "teklif.html" icindeki nokta cumle sonu degil.
# Cumle sonu = nokta/unlem/soru + bosluk + BUYUK harf, ya da satir sonu.
$parcali = [regex]::Replace($t, '(?<=[\.\!\?])\s+(?=[A-ZÇĞİÖŞÜ])', "`n")
$cumleler = $parcali -split "`n" |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_.Length -gt 0 }

# --- denetimler -----------------------------------------------------------
$bulgular = New-Object System.Collections.ArrayList

function Ekle($kural, $ornek) {
    if ($bulgular.Count -ge 6) { return }     # mesaj uzamasin
    $kisa = $ornek.Trim()
    if ($kisa.Length -gt 110) { $kisa = $kisa.Substring(0, 110) + "..." }
    [void]$bulgular.Add("  - $kural" + [Environment]::NewLine + "    > $kisa")
}

# 1) Noktali virgul (STE 8.1). Kod elendigi icin kalan her tane yazim hatasi.
foreach ($c in $cumleler) {
    if ($c.Contains(";")) { Ekle "STE 8.1 - noktali virgul kullanma" $c }
}

# 2) Cumle uzunlugu. Aciklama en cok 20 kelime (STE 8.5-8.6).
foreach ($c in $cumleler) {
    $n = ($c -split '\s+' | Where-Object { $_ -match '\S' }).Count
    if ($n -gt 20) { Ekle "STE 8.5 - $n kelime, en cok 20 olmali" $c }
}

# 3) Yasakli kaliplar. Yalnizca KESIN olanlar listede: "ilgili" ve "saglamak"
#    bilerek disarida, dogru kullanimlari da var ve yanlis uyari uretirlerdi.
#    [ordered]: sira onemli. Ozel kaliplar ("bulunmaktadir", "gerekmektedir")
#    genel "-maktadir" / "-mektedir" kalibindan ONCE gelir, yoksa hic
#    eslesmezler. Duz @{} hashtable sirasizdir. ste-tr-denetim.py ile ayni sira.
$yasak = [ordered]@{
    'bulunmaktadır'           = 'bulunmaktadir -> var'
    'gerekmektedir'           = 'gerekmektedir -> gerekir / yapin'
    'gerçekleştir'            = 'gerceklestirmek -> yapmak'
    'icra et'                 = 'icra etmek -> yapmak'
    'mevcuttur'               = 'mevcuttur -> var'
    'söz konusu'              = 'soz konusu -> bu, o (ya da adi)'
    'hususunda'               = 'hususunda -> hakkinda'
    'itibarıyla'              = 'itibariyla -> -den beri'
    'nezdinde'                = 'nezdinde -> -de'
    'mektedir\b'              = '-mektedir -> -ir / -ar'
    'maktadır\b'              = '-maktadir -> -ir / -ar'
}
# Bir cumlede ILK eslesmeden sonra durulur. "bulunmaktadir" zaten
# "-maktadir" iceriyor; ikisini birden bildirmek ayni hatayi iki kez
# soylemek olurdu ve mesaj gereksiz uzardi.
foreach ($c in $cumleler) {
    foreach ($k in $yasak.Keys) {
        if ($c -match $k) { Ekle ("Kelime: " + $yasak[$k]) $c; break }
    }
}

# --- sonuc ----------------------------------------------------------------
# Cevap ENGELLENMEZ. Ihlaller not edilir, sonraki istekte -Istem ile eklenir.
if ($bulgular.Count -eq 0) { exit 0 }

$ln = [Environment]::NewLine
$not = "Onceki cevabinda STE-TR yazim kurali ihlalleri vardi. Onceki " +
       "cevabi YENIDEN YAZMA. Bu cevapta ayni hatalari yapma." + $ln +
       ($bulgular -join $ln) + $ln +
       "Kural: her cumlede tek bilgi, aciklama en cok 20 kelime, " +
       "noktali virgul yok, etken cati, koşul once gelir."

New-Item -ItemType Directory -Force -Path $notDizini | Out-Null
[System.IO.File]::WriteAllText($notYolu, $not, $NoBomUtf8)
exit 0
