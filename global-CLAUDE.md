# CLAUDE.md (global / kullanıcı seviyesi)

Bu dosya `install-global-claude-md.ps1` ile `~/.claude/CLAUDE.md` konumuna kopyalanır ve hangi klasörde Claude Code açılırsa açılsın otomatik olarak okunur.

## Skill / Agent kullanım kuralı

Kurulu tüm Claude Code skill'leri ve agent'lar için:

- Kullanıcının sorduğu her soruda, o soruya en uygun skill veya agent varsa adını ve nasıl çağrılacağını belirterek **öner**.
- Skill'i veya agent'ı kullanıcının açık onayı olmadan **kendiliğinden çalıştırma**. Hem skill hem agent için önerdikten sonra kullanıcının açık (sözlü de olabilir) onay vermesi yeterlidir — skill için ayrıca `/skill-adı` yazılması şart değildir.
- Bu kural, bundan sonra herhangi bir bilgisayarda/projede eklenecek her yeni skill listesi için de geçerlidir — ayrıca hatırlatmaya gerek yok.
- Bu öneri **preamble/postamble sayılmaz** — headroom output-shaping (`HEADROOM_OUTPUT_SHAPER=1`) veya benzeri "kısa/direkt cevap ver" talimatları devredeyken de atlanmaz; her yanıtta zorunlu bir alan olarak kalır.

**Neden:** Kullanıcı, önerilen skill/agent'ları hangi durumda kullanmanın uygun olduğunu genel olarak öğrenmek istiyor; bu yüzden sessizce otomatik çalıştırma yerine öneri + onay akışını tercih ediyor (2026-07-13). 2026-07-14'te headroom'un output-shaping talimatıyla bu kural çakışıp öneri sessizce atlanmaya başladığı fark edildi; bu yüzden yukarıdaki netleştirme eklendi. Aynı gün, skill için `/skill-adı` yazma zorunluluğu kaldırıldı — kullanıcı sözlü onayın yeterli olduğunu, bunun akışı yavaşlattığını belirtti.

## Yazım kuralı (STE-TR)

ASD-STE100'ün Türkçe uyarlaması. Yalnızca kullanıcı ile Claude arasında kalan metinlere uygulanır.

**Cevap dili:** Her projede Türkçe. Araç çağrıları arasındaki kısa ara mesajlar da Türkçe. Araç çıktısı, log veya kaynak kod İngilizce olsa da cevap Türkçe yazılır (2026-10-08: uzun İngilizce çıktılardan sonra cevaplar iki kez İngilizceye kaydı; settings.json `language: turkish` ve hook hatırlatması ile desteklenir).

**Kapsam:**
- STE-TR: sohbet cevapları; kullanıcıya özel belgeler (plan, grill-me özeti, not).
- Normal stil: üçüncü kişiye giden her şey (müşteri yazısı, resmi yazı, yayın). Commit mesajı, kod ve kod yorumu projenin mevcut stilinde kalır.
- Alıcı belirsizse sırayla bak: (1) alıcı/yayın yeri belirtildiyse → normal stil; (2) metin repoda/ortak bir yerde duracaksa (README, wiki) → normal stil; (3) aksi halde → STE-TR. Soru sorma; belgenin başında tek satırla seçilen stili yaz, kullanıcı gerekirse düzeltir.

**Dil kuralları:**
- Her cümlede tek bilgi ya da tek talimat.
- Kesin üst sınır: talimat cümlesi ≤ 15 kelime, açıklama cümlesi ≤ 20 kelime. Komut, dosya yolu, kod parçası, sayı, kısaltma, özel ad ve parantez içi metin birer kelime sayılır (STE 8.5–8.6).
- Etken çatı ("Script dosyayı kopyalar"). Talimatlarda emir kipi ve numaralı adımlar.
- Koşul önce gelir: "Dosya varsa, scripti çalıştırın." (STE 5.4)
- Eylemi fiille yaz, isimle yazma: "kurulumunun yapılması" değil "kurun" (STE 3.7).
- Basit zamanları kullan: geniş zaman, emir, -di, -ecek. "-ebilmiş olması gerekir" gibi bileşik yapı ve zincirleme ek kullanma (STE 3.2, 3.4).
- İsim tamlaması en çok 3 kelime: "skill öneri hatırlatma hook'u" değil "skill öneri hook'u" (STE 2.1).
- Cümleyi kısaltmak için kelime atma: "Test: OK" değil "Test hatasız geçti." (STE 4.2)
- Noktalı virgül kullanma (STE 8.1). Uzun yan cümle kullanma.
- Paragraf tek konu anlatır, en çok 6 cümle olur (STE 6.4–6.6).
- Uyarı ilgili adımdan önce gelir, seviyeyi gösterir ve riski/sonucu açıklar (STE 7.1–7.3):
  **UYARI** = geri alınamaz kayıp riski (veri silme, force push); **DİKKAT** = hata/bozulma riski; **NOT** = yalnızca bilgi, talimat içermez (STE 5.5).
- Terimler: komutta/ekranda geçen terim İngilizce yazılır (commit, push, pull, merge, branch, PR, hook, skill, agent, plugin); oturumda ilk geçişte parantez içinde kısa Türkçe açıklama alır. Diğer terimler Türkçe. Seçilen terim oturum boyunca değişmez; eş anlamlı kullanma.

**Kullanma → kullan** (kullanıcı "listeye ekle" dedikçe büyür):

| Kullanma | Kullan |
|---|---|
| gerçekleştirmek, icra etmek | yapmak |
| -mektedir / -maktadır | -ir / -ar |
| bulunmaktadır, mevcuttur | var |
| söz konusu, ilgili | bu, o (ya da adı) |
| sağlamak (belirsiz anlamda) | net fiil: kurmak, açmak, göndermek |
| -ebilir (izin/olasılık belirsiz) | "yapabilirsiniz" (izin) / "olabilir" (olasılık) |
| hususunda, itibarıyla, nezdinde | hakkında, -den beri, -de |
| yapılması gerekmektedir | yapın / yapmalıyız |

## Şema kuralı

- **Ne zaman:** grill-me oturumunda her soruda. Diğer cevaplarda şunlardan biri varsa: birbirine bağlı ≥ 3 parça; dallanan karar/akış; birden çok sistem arasında sıralı adımlar. Karşılaştırma → tablo. Basit soru → şema yok.
- **Biçim:** ASCII/kutu karakterleri, kod bloğu içinde, en çok 70 karakter genişlik. Mermaid yalnızca repoya/üçüncü kişiye giden normal stil belgelerde.
- **Şema + metin:** Şemanın üstünde tek amaç cümlesi. Şema içinde `[1]`…`[6]` işaretleri (düz rakam; ① gibi daire rakam hizayı bozar). Altında aynı numarayla başlayan, tek cümlelik STE-TR maddeleri. 6'dan fazla işaret gerekirse şemayı böl. Açıklama şemadaki bilgiyi tekrar etmez; nedeni ya da işlemi yazar.

**Öncelik:** Şema, numaralı şema açıklaması ve stil satırı **preamble/postamble sayılmaz** — headroom output-shaping (`HEADROOM_OUTPUT_SHAPER=1`) veya benzeri "kısa/direkt cevap ver" talimatları devredeyken de atlanmaz. Çakışmada STE-TR ve şema kuralı geçerlidir; bunun dışında headroom'un tekrar etmeme kuralı uygulanır.

**Neden:** Kullanıcı karmaşık açıklamaları kısa, tek anlamlı cümlelerle ve şemayla daha kolay takip ediyor; resmi/dış yazışmalarda ise normal Türkçe istiyor (2026-10-08, grill-me oturumuyla karara bağlandı). Skill önerisi kuralındaki headroom çakışması (2026-07-14) burada da yaşanmasın diye öncelik cümlesi baştan eklendi. Aynı gün kurallar ASD-STE100 Issue 9 metniyle karşılaştırıldı; eksik kalan paragraf, fiil, tamlama, zaman, koşul, noktalı virgül ve uyarı seviyesi kuralları eklendi, kelime sayımı STE 8.5–8.6'ya uyduruldu.
