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

## find-skills (skills.sh kataloğundan yeni skill bulma)

`find-skills`, `vercel-labs/skills` ekosisteminin "skill bulucu" becerisidir: ne yaptığını anlattığında skills.sh / GitHub kataloğundan uygun skilleri bulup `npx skills add` ile kurmana yardım eder. Bu, bizim `claude plugin` / marketplace sistemimizden **ayrı bir ekosistem** ama tamamlayıcıdır — kurduğu skiller `~/.claude/skills/` altına düşer ve global skill-öneri hook'umuz tarafından her projede görülür/önerilir.

Global kurmak için (Node.js/npx gerekli):

```
git pull
powershell -ExecutionPolicy Bypass -File install-find-skills.ps1
```

**Otomatik güncelleme (oturum başı):** find-skills ile kurulan skiller `~/.agents/.skill-lock.json`'a kaydedilir. `check-agent-skills-updates.ps1`, her Claude Code oturumu başında (SessionStart) throttle'lı (6 saat) olarak `npx skills update -y`'yi **arka planda (gizli pencere)** çalıştırıp bu skilleri güncel tutar. Bu, plugin sistemimizin `claude plugin update` otomatik güncellemesinin skills.sh ekosistemindeki karşılığıdır — **iki sistem ayrı kalır**, yalnızca güncelleme otomasyonu paralel çalışır. Hook'u kurmak için:

```
git pull
powershell -ExecutionPolicy Bypass -File install-agent-skills-update-hook.ps1
```

Kapatmak için `~/.claude/agent-skills-autoupdate-off` adında boş bir dosya oluştur (o zaman güncelleme çalışmaz; elle: `npx skills update`). Log: `~/.claude/agent-skills-update.log`.

### find-skills ile kurulan skilleri bilgisayarlar arası senkronlama (Yol A: lockfile tabanlı)

`npx skills` her global kurulumu `~/.agents/.skill-lock.json`'a otomatik kaydettiği için, ayrı bir liste tutmana gerek yok. Akış:

**Kaynak bilgisayarda** (find-skills ile skill kurduktan sonra):

```
powershell -ExecutionPolicy Bypass -File export-agent-skills.ps1
git add agent-skills-lock.json
git commit -m "yeni skills.sh skilleri"
git push
```

`export-agent-skills.ps1`, global lockfile'ı repo içine `agent-skills-lock.json` olarak kopyalar.

**Hedef bilgisayarda** (git pull sonrası):

```
git pull
powershell -ExecutionPolicy Bypass -File install-agent-skills.ps1
```

`install-agent-skills.ps1`, `agent-skills-lock.json`'daki **tüm** skilleri (find-skills dahil) `npx skills add ... -g -y` ile kurar. Ne yapacağını görmek için `-DryRun` ekle. Bu script find-skills'i de kapsadığından, hedef makinede `install-find-skills.ps1`'e ayrıca gerek kalmaz — o yalnızca lockfile olmadan hızlı bir "sadece bulucu" kurulumu içindir.

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

## Bulut oturumları (claude.ai/code) — Linux kurulumu

Bulut oturumları Linux konteynerinde çalışır, PowerShell yoktur. `install-cloud-skills.sh` yukarıdaki `.ps1` scriptlerinin bash karşılığıdır ve **aynı listeleri** okur:

- `claude-marketplaces.txt` + `claude-skills.txt` → `claude plugin install`
- `agent-skills-lock.json` → `npx skills add -g -a claude-code`
- `global-CLAUDE.md` → `~/.claude/CLAUDE.md`
- cevap dili `language: "turkish"` → `~/.claude/settings.json` (Windows'ta `install-global-claude-md.ps1` yapar)
- skill-öneri hatırlatma hook'u → `~/.claude/settings.json` (idempotent)

Tek bir kurulum hata verirse diğerlerine devam eder, sonda özet basar ve her zaman 0 ile çıkar (setup script oturumu düşürmesin diye). Tam kurulum ~3 dakika sürer.

```
bash install-cloud-skills.sh            # kur
bash install-cloud-skills.sh --dry-run  # sadece listele
```

**Her bulut oturumunda otomatik kurulum:** Skill-Deposu'nu oturuma ekle ve bulut ortamının **Setup script** alanına (oturum başlığındaki ortam menüsü → Edit) şunu yaz:

```bash
for d in /home/user/skill-deposu /home/user/Skill-Deposu; do
  [ -f "$d/install-cloud-skills.sh" ] && { bash "$d/install-cloud-skills.sh"; break; }
done
true
```

**Oturum-başı otomatik güncelleme:** `install-cloud-skills.sh` kurulum anındaki marketplace ve skills.sh kaynak repolarının son commit'lerini `~/.claude/cloud-skill-update-state.json`'a yazar ve `cloud-skill-update.sh`'i SessionStart hook'u olarak kaydeder. Her bulut oturumu başında hook bu repoları `git ls-remote` ile kontrol eder (birkaç saniye); yeni commit varsa plugin'leri ve/veya skills.sh skill'lerini **arka planda** günceller (log: `~/.claude/cloud-skill-update.log`). Güncel skill'ler bir sonraki mesajdan itibaren yüklenir. Bu, Windows'taki `check-skill-updates.ps1` / `check-agent-skills-updates.ps1` hook'larının karşılığıdır. Güncelleme container önbelleğine yazılmaz, yani önbellek eskidikçe her oturumda tekrarlanır. Kapatmak için `~/.claude/skill-autoupdate-off` dosyasını oluştur.

Setup script ~5 dakikadan kısa sürerse ortam önbelleğe alınır; sonraki oturumlar kurulu halde başlar. Listeye yeni skill eklediğinde önbellek kendiliğinden yenilenmez — setup script'i küçük bir değişiklikle (ör. sonuna bir yorum satırı) kaydet ki yeniden çalışsın, ya da oturum içinde `bash install-cloud-skills.sh` çalıştır (kurulan skiller bir sonraki mesajda yüklenir).
