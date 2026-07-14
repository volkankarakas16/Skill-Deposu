# CLAUDE.md (global / kullanıcı seviyesi)

Bu dosya `install-global-claude-md.ps1` ile `~/.claude/CLAUDE.md` konumuna kopyalanır ve hangi klasörde Claude Code açılırsa açılsın otomatik olarak okunur.

## Skill / Agent kullanım kuralı

Kurulu tüm Claude Code skill'leri ve agent'lar için:

- Kullanıcının sorduğu her soruda, o soruya en uygun skill veya agent varsa adını ve nasıl çağrılacağını belirterek **öner**.
- Skill'i veya agent'ı kullanıcının açık onayı olmadan **kendiliğinden çalıştırma**. Skill için kullanıcının `/skill-adı` yazması, agent için ise önerdikten sonra kullanıcının onay vermesi gerekir.
- Bu kural, bundan sonra herhangi bir bilgisayarda/projede eklenecek her yeni skill listesi için de geçerlidir — ayrıca hatırlatmaya gerek yok.
- Bu öneri **preamble/postamble sayılmaz** — headroom output-shaping (`HEADROOM_OUTPUT_SHAPER=1`) veya benzeri "kısa/direkt cevap ver" talimatları devredeyken de atlanmaz; her yanıtta zorunlu bir alan olarak kalır.

**Neden:** Kullanıcı, önerilen skill/agent'ları hangi durumda kullanmanın uygun olduğunu genel olarak öğrenmek istiyor; bu yüzden sessizce otomatik çalıştırma yerine öneri + onay akışını tercih ediyor (2026-07-13). 2026-07-14'te headroom'un output-shaping talimatıyla bu kural çakışıp öneri sessizce atlanmaya başladığı fark edildi; bu yüzden yukarıdaki netleştirme eklendi.
