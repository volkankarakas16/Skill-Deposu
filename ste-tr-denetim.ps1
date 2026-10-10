# STE-TR yazim denetimi -- Stop hook.
#
# Claude cevabini bitirdiginde calisir, SON asistan mesajini okur ve global
# CLAUDE.md'deki STE-TR kurallarina aykiri yerleri bulur. Ihlal varsa cevabi
# ENGELLER; Claude duzeltip yeniden yazar.
#
# Neden gerekli: skill-suggestion-reminder.ps1 kurali her istekte
# HATIRLATIYOR ama hatirlatma yetmiyor. 2026-10-11'de kullanici, kuralin
# hatirlatmaya ragmen uygulanmadigini bildirdi. Hatirlatma istekten ONCE
# calisiyor ve cevabi goremiyor. Bu betik cevabi GORUYOR.
#
# Dongu korumasi: stop_hook_active bayragi geldiginde hic denetim yapmaz.
# Claude bir kez engellendiyse ikinci kez engellenmez, yoksa cevap hic
# bitmez.
#
# Olcum kod DISINDA yapilir. Kod blogu, satir ici kod, tablo ve baglanti
# adresi elenir: oralardaki noktali virgul ve uzun satir yazim hatasi degil.

$ErrorActionPreference = "Stop"

# PowerShell 5.1 stdout'u sistemin kod sayfasiyla (Turkce Windows'ta
# cp1254) yaziyor ve JSON icindeki Turkce harfler bozuluyor. Claude'a
# "ko?ul" diye ulasan bir uyari okunmaz. Akis UTF-8 olmak ZORUNDA.
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

# --- girdi ---------------------------------------------------------------
$ham = [Console]::In.ReadToEnd()
if (-not $ham) { exit 0 }

try { $girdi = $ham | ConvertFrom-Json } catch { exit 0 }

# Dongu korumasi. Bu olmadan Claude sonsuza kadar yeniden yazar.
if ($girdi.stop_hook_active -eq $true) { exit 0 }

$yol = $girdi.transcript_path
if (-not $yol -or -not (Test-Path $yol)) { exit 0 }

# --- son asistan metnini cek ---------------------------------------------
# Transcript JSONL. Sondan geriye tarayip ilk asistan METIN mesajini aliyoruz;
# arac cagrilari metin tasimaz, onlar atlanir.
$metin = ""
# 1500 satir: uzun arac dizilerinde son METIN mesaji cok geride kalabilir.
# -Tail dosyayi sondan okuyor, 27 MB'lik bir transcript'te bile hizli.
$satirlar = Get-Content $yol -Tail 1500 -Encoding UTF8
for ($i = $satirlar.Count - 1; $i -ge 0; $i--) {
    $s = $satirlar[$i]
    if (-not $s) { continue }
    try { $o = $s | ConvertFrom-Json } catch { continue }
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
$yasak = @{
    'gerçekleştir'            = 'gerceklestirmek -> yapmak'
    'icra et'                 = 'icra etmek -> yapmak'
    'mektedir\b'              = '-mektedir -> -ir / -ar'
    'maktadır\b'              = '-maktadir -> -ir / -ar'
    'bulunmaktadır'           = 'bulunmaktadir -> var'
    'mevcuttur'               = 'mevcuttur -> var'
    'söz konusu'              = 'soz konusu -> bu, o (ya da adi)'
    'hususunda'               = 'hususunda -> hakkinda'
    'itibarıyla'              = 'itibariyla -> -den beri'
    'nezdinde'                = 'nezdinde -> -de'
    'gerekmektedir'           = 'gerekmektedir -> gerekir / yapin'
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
if ($bulgular.Count -eq 0) { exit 0 }

$ln = [Environment]::NewLine
$sebep = "STE-TR yazim kurali ihlali bulundu. Cevabi DUZELTIP yeniden yaz." +
         $ln + "Global CLAUDE.md > Yazim kurali (STE-TR) bolumune bak." + $ln +
         $ln + ($bulgular -join $ln) + $ln +
         $ln + "Kural: her cumlede tek bilgi, aciklama en cok 20 kelime," +
         $ln + "noktali virgul yok, etken cati, koşul once gelir."

$cikti = @{
    decision = "block"
    reason   = $sebep
}
$cikti | ConvertTo-Json -Compress -Depth 5
exit 0
