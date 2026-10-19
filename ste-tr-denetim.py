#!/usr/bin/env python3
# STE-TR yazim denetimi -- Stop hook (bulut/Linux).
#
# ste-tr-denetim.ps1'in Python karsiligi. Kurallar, esikler ve kalip sirasi
# AYNI. Birini degistiren otekini de degistirmeli. Bulut oturumlarinda
# install-cloud-skills.sh bu dosyayi Stop olayina baglar.
#
# UYARI MODU, iki asamali:
#   Stop             -> son asistan mesajini denetler. Ihlal varsa cevabi
#                       ENGELLEMEZ, oturuma ozel bir not dosyasina yazar.
#   UserPromptSubmit -> (--istem) not varsa sonraki cevaba talimat olarak
#                       ekler ve notu siler.
#
# Neden engellemiyor: engellenen cevap ekranda zaten gorunuyordu. Claude
# duzeltmeyi ikinci bir mesaj olarak yaziyordu. Kullanici ayni cevabi iki
# kez goruyor, cikti token'i ikiye katlaniyordu (2026-10-19).
#
# Olcum kod DISINDA yapilir. Kod blogu, satir ici kod, tablo ve baglanti
# adresi elenir: oralardaki noktali virgul ve uzun satir yazim hatasi degil.
#
# Beklenmeyen her hatada sessizce 0 ile cikar: bozuk bir denetim cevaplari
# engellememeli.

import json
import os
import re
import sys
from collections import deque

MAX_BULGU = 6
NOT_DIZINI = os.path.expanduser("~/.claude/ste-tr-notlar")
MAX_KELIME = 20

# Yalnizca KESIN olanlar listede: "ilgili" ve "saglamak" bilerek disarida,
# dogru kullanimlari da var ve yanlis uyari uretirlerdi.
# Sira onemli: ozel kaliplar ("bulunmaktadir", "gerekmektedir") genel
# "-maktadir" / "-mektedir" kalibindan ONCE gelir, yoksa hic eslesmezler.
YASAK = [
    (r"bulunmaktadır", "bulunmaktadir -> var"),
    (r"gerekmektedir", "gerekmektedir -> gerekir / yapin"),
    (r"gerçekleştir", "gerceklestirmek -> yapmak"),
    (r"icra et", "icra etmek -> yapmak"),
    (r"mevcuttur", "mevcuttur -> var"),
    (r"söz konusu", "soz konusu -> bu, o (ya da adi)"),
    (r"hususunda", "hususunda -> hakkinda"),
    (r"itibarıyla", "itibariyla -> -den beri"),
    (r"nezdinde", "nezdinde -> -de"),
    (r"mektedir\b", "-mektedir -> -ir / -ar"),
    (r"maktadır\b", "-maktadir -> -ir / -ar"),
]

# Transcript'in yalnizca sonu okunur: uzun oturumda dosya onlarca MB olur.
OKUMA_BAYT = 4 * 1024 * 1024


def kullanici_istegi(o):
    # Gercek kullanici mesaji: metin tasir. Arac sonucu (tool_result) ve
    # sistem hatirlatmasi (isMeta) turu bitirmez.
    if o.get("type") != "user" or o.get("isMeta"):
        return False
    c = (o.get("message") or {}).get("content")
    if isinstance(c, str):
        return True
    return isinstance(c, list) and any(
        isinstance(p, dict) and p.get("type") == "text" for p in c)


def son_asistan_metni(yol):
    # Dosyanin sonundan okur. 1500 satir: uzun arac dizilerinde son METIN
    # mesaji cok geride kalabilir.
    with open(yol, "rb") as f:
        f.seek(0, os.SEEK_END)
        f.seek(max(0, f.tell() - OKUMA_BAYT))
        ham = f.read().decode("utf-8", errors="replace")
    satirlar = deque(ham.splitlines(), maxlen=1500)
    for s in reversed(satirlar):
        try:
            o = json.loads(s)
        except ValueError:
            continue    # yarim kalan ilk satir da buraya duser
        # Bu turda metin yoksa onceki turun cevabi yeniden denetlenmez.
        if kullanici_istegi(o):
            return ""
        if o.get("type") != "assistant":
            continue
        parcalar = (o.get("message") or {}).get("content")
        if not isinstance(parcalar, list):
            continue
        yazi = "\n".join(p.get("text", "") for p in parcalar
                         if isinstance(p, dict) and p.get("type") == "text")
        if yazi.strip():
            return yazi
    return ""


def temizle(t):
    # Sira onemli: once uc tirnakli bloklar, sonra satir ici kod. Ters sirada
    # blok icindeki tek tirnaklar yanlis eslesir.
    t = re.sub(r"```.*?```", " ", t, flags=re.S)           # kod blogu
    t = re.sub(r"`[^`]*`", " K ", t)                        # satir ici kod
    t = re.sub(r"^\s*\|.*$", " ", t, flags=re.M)           # tablo satiri
    t = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", t)         # baglanti -> metin
    t = re.sub(r"https?://\S+", " K ", t)                  # ciplak adres
    t = re.sub(r"[*_#>]", " ", t)                          # vurgu ve baslik
    t = re.sub(r"^\s*[-+]\s+", "", t, flags=re.M)          # madde isareti
    return t


def cumleler(t):
    # Nokta tek basina yetmez: "teklif.html" icindeki nokta cumle sonu degil.
    # Cumle sonu = nokta/unlem/soru + bosluk + BUYUK harf, ya da satir sonu.
    t = re.sub(r"(?<=[.!?])\s+(?=[A-ZÇĞİÖŞÜ])", "\n", t)
    return [c.strip() for c in t.split("\n") if c.strip()]


def denetle(metin):
    bulgular = []

    def ekle(kural, ornek):
        if len(bulgular) >= MAX_BULGU:      # mesaj uzamasin
            return
        kisa = ornek.strip()
        if len(kisa) > 110:
            kisa = kisa[:110] + "..."
        bulgular.append(f"  - {kural}\n    > {kisa}")

    cs = cumleler(temizle(metin))

    # 1) Noktali virgul (STE 8.1). Kod elendigi icin kalan her tane yazim hatasi.
    for c in cs:
        if ";" in c:
            ekle("STE 8.1 - noktali virgul kullanma", c)

    # 2) Cumle uzunlugu. Aciklama en cok 20 kelime (STE 8.5-8.6).
    for c in cs:
        n = len(c.split())
        if n > MAX_KELIME:
            ekle(f"STE 8.5 - {n} kelime, en cok {MAX_KELIME} olmali", c)

    # 3) Yasakli kaliplar. Bir cumlede ILK eslesmeden sonra durulur:
    #    "bulunmaktadir" zaten "-maktadir" iceriyor, ayni hata iki kez yazilmaz.
    #    PowerShell -match gibi buyuk/kucuk harf duyarsiz.
    for c in cs:
        for desen, oneri in YASAK:
            if re.search(desen, c, flags=re.I):
                ekle("Kelime: " + oneri, c)
                break

    return bulgular


def not_yolu(girdi):
    # Oturum kimligi dosya adinda kullanilir. Yol karakterleri ayiklanir.
    sid = re.sub(r"[^A-Za-z0-9_-]", "", str(girdi.get("session_id") or ""))
    return os.path.join(NOT_DIZINI, (sid or "oturum") + ".txt")


def denetim(girdi):
    # Eski surumden kalan yeniden yazma turunda tekrar denetleme.
    if girdi.get("stop_hook_active") is True:
        return
    yol = girdi.get("transcript_path")
    if not yol or not os.path.isfile(yol):
        return
    metin = son_asistan_metni(yol)
    bulgular = denetle(metin) if metin else []
    hedef = not_yolu(girdi)
    if not bulgular:
        return
    not_metni = ("Onceki cevabinda STE-TR yazim kurali ihlalleri vardi. Onceki "
                 "cevabi YENIDEN YAZMA. Bu cevapta ayni hatalari yapma.\n"
                 + "\n".join(bulgular) + "\n"
                 "Kural: her cumlede tek bilgi, aciklama en cok 20 kelime, "
                 "noktali virgul yok, etken cati, koşul once gelir.")
    os.makedirs(NOT_DIZINI, exist_ok=True)
    with open(hedef, "w", encoding="utf-8") as f:
        f.write(not_metni)


def istem(girdi):
    hedef = not_yolu(girdi)
    if not os.path.isfile(hedef):
        return
    with open(hedef, encoding="utf-8") as f:
        not_metni = f.read()
    os.remove(hedef)
    # ensure_ascii: stdout kodlamasi UTF-8 olmasa da cikti bozulmaz.
    sys.stdout.write(json.dumps({"hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit", "additionalContext": not_metni}}))


def main():
    ham = sys.stdin.read()
    if not ham.strip():
        return
    try:
        girdi = json.loads(ham)
    except ValueError:
        return
    if "--istem" in sys.argv[1:]:
        istem(girdi)
    else:
        denetim(girdi)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Bozuk denetim oturumu bozmasin.
        pass
    sys.exit(0)
