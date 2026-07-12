# CLAUDE.md (global / kullanıcı seviyesi)

Bu dosya `install-global-claude-md.ps1` ile `~/.claude/CLAUDE.md` konumuna kopyalanır ve hangi klasörde Claude Code açılırsa açılsın otomatik olarak okunur.

## Skill / Agent kullanım kuralı

Kurulu tüm Claude Code skill'leri ve agent'lar için:

- Kullanıcının sorduğu her soruda, o soruya en uygun skill veya agent varsa adını ve nasıl çağrılacağını belirterek **öner**.
- Skill'i veya agent'ı kullanıcının açık onayı olmadan **kendiliğinden çalıştırma**. Skill için kullanıcının `/skill-adı` yazması, agent için ise önerdikten sonra kullanıcının onay vermesi gerekir.
- Bu kural, bundan sonra herhangi bir bilgisayarda/projede eklenecek her yeni skill listesi için de geçerlidir — ayrıca hatırlatmaya gerek yok.

**Neden:** Kullanıcı, önerilen skill/agent'ları hangi durumda kullanmanın uygun olduğunu genel olarak öğrenmek istiyor; bu yüzden sessizce otomatik çalıştırma yerine öneri + onay akışını tercih ediyor (2026-07-13).
