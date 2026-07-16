# Skill Deposu

Ev ve ofis bilgisayarları arasında proje dosyalarını ve Claude Code skill listesini senkronize etmek için kullanılır.

## Skilleri senkronize etme

Yeni bir bilgisayarda veya güncel skil listesini almak için:

```
git pull
powershell -ExecutionPolicy Bypass -File install-claude-skills.ps1
```

Yeni bir skill eklemek için `claude-skills.txt` dosyasına `plugin-adi@marketplace-adi` formatında bir satır ekleyip commit + push yap. Eğer skill farklı bir marketplace'ten geliyorsa önce `claude-marketplaces.txt` dosyasına `owner/repo` formatında bir satır ekle. Diğer bilgisayarda yukarıdaki iki komutu çalıştırmak yeterli.

## Global CLAUDE.md (skill/agent kullanım kuralı, her klasörde geçerli)

`global-CLAUDE.md`, hangi klasörde Claude Code açarsan aç geçerli olacak kuralları (ör. skill/agent önerme + onay alma) içerir. Yeni bir bilgisayarda veya güncel kuralları almak için:

```
git pull
powershell -ExecutionPolicy Bypass -File install-global-claude-md.ps1
```

Bu script `global-CLAUDE.md`'yi `~/.claude/CLAUDE.md` konumuna kopyalar. Kuralı güncellemek için `global-CLAUDE.md`'yi düzenleyip commit + push yap, diğer bilgisayarda yukarıdaki iki komutu çalıştır.

## Skill öneri hook'u (her soruda öneri hatırlatması)

`skill-suggestion-reminder.ps1`, her prompt gönderiminde "bu soruya uygun bir skill/agent var mı, kontrol et ve öner" hatırlatmasını modele enjekte eden bir `UserPromptSubmit` hook script'idir. Bu, `global-CLAUDE.md`'deki öneri kuralını güçlendirir (kural sessizce atlanmasın diye). Yeni bir bilgisayarda kurmak için:

```
git pull
powershell -ExecutionPolicy Bypass -File install-skill-suggestion-hook.ps1
```

Bu script hook'u `~/.claude/settings.json` içine idempotent olarak ekler (zaten kuruluysa dokunmaz, mevcut hook'ları bozmaz). Aktif olması için Claude Code'u yeniden başlat (veya `/hooks` menüsünü bir kez aç).

## Skill güncelleme kontrolü + otomatik güncelleme (oturum başı)

`check-skill-updates.ps1`, `claude-marketplaces.txt`'te izlenen repolarda yeni commit olup olmadığını her oturum başında (`SessionStart`) kontrol eder. Bu hook'u `~/.claude/settings.json`'a idempotent olarak eklemek için:

```
git pull
powershell -ExecutionPolicy Bypass -File install-skill-update-hook.ps1
```

Yeni commit tespit edilirse, `apply-skill-updates.ps1` **arka planda (gizli pencerede)** otomatik başlatılır; tüm marketplace'leri tazeler ve `claude-skills.txt`'teki tüm plugin'leri `claude plugin update` ile en güncel sürüme çeker (zaten güncel olanlar no-op, güvenli). Çıktı `~/.claude/skill-update-apply.log`'a yazılır. Güncellemelerin aktif olması için işlem bitince Claude Code'u yeniden başlat.

Otomatik güncellemeyi **kapatmak** için `~/.claude/skill-autoupdate-off` adında boş bir dosya oluştur — o zaman hook sadece bildirir, kurmaz (elle: `install-claude-skills.ps1`). Güncellemeyi elle tetiklemek veya çalıştırmadan ne yapacağını görmek için:

```
powershell -ExecutionPolicy Bypass -File apply-skill-updates.ps1          # uygula
powershell -ExecutionPolicy Bypass -File apply-skill-updates.ps1 -DryRun  # sadece listele
```

Hook'un aktif olması için Claude Code'u yeniden başlat (veya `/hooks` menüsünü bir kez aç).

## Headroom (token tasarrufu proxy) kurulumu

Headroom, Claude Code isteklerini yerel bir proxy üzerinden geçirip context'i sıkıştırarak token tüketimini azaltan bir araç.

**ÖNEMLİ:** `headroom@headroom-marketplace` plugin'ini `claude-skills.txt`'ye EKLEME. O plugin'in kendi `PreToolUse` hook'u, aşağıdaki script'in `settings.json`'a yazdığı hook ile aynı işi tekrarlayıp her Bash/PowerShell komutunda görünür bir cmd penceresi açılmasına sebep oluyor (bunu bir kurulumda yaşadık). Headroom'u sadece şu script ile kur:

```
powershell -ExecutionPolicy Bypass -File install-headroom.ps1
```

Bu script sırasıyla: `uv` kurar (yoksa), `headroom` CLI'ını izole bir ortamda kurar, kalıcı (durable) Claude Code entegrasyonunu kaydeder ve `~/.claude/settings.json` içine `ANTHROPIC_BASE_URL=http://127.0.0.1:8787` satırını ekler.

**Kuruma başlamadan önce:** Bazı antivirüs yazılımları (Windows Defender dahil), headroom'un bağımlılığı olan `ast-grep-cli` paketinin `sg.exe` dosyasını yanlış pozitif olarak engelleyebiliyor. Kurulum bu hatayı verirse, **Yönetici olarak açılmış bir PowerShell**'de şunu çalıştırıp scripti tekrar başlat:

```
Add-MpPreference -ExclusionPath "$env:APPDATA\uv\tools\headroom-ai"
```

Kurulum bitince Claude Code'u yeniden başlat ve `headroom doctor` ile doğrula — `claude: routed`, `proxy: pass`, `0 failure(s)` görmen gerekiyor. Ayar kullanıcı genelinde (`~/.claude/settings.json`) olduğu için hangi repo'yu açarsan aç otomatik devrede olur, ekstra bir işlem gerekmez.
