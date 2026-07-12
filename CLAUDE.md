# CLAUDE.md

Bu repo, bu bilgisayar ile diğer bilgisayar arasında GitHub üzerinden senkronize ediliyor (bkz. README.md). Buradaki kurallar, `git pull` yapılan her bilgisayarda otomatik olarak geçerli olur.

## Skill / Agent kullanım kuralı

Kurulu tüm Claude Code skill'leri (bkz. `claude-skills.txt`) ve agent'lar için:

- Kullanıcının sorduğu her soruda, o soruya en uygun skill veya agent varsa adını ve nasıl çağrılacağını belirterek **öner**.
- Skill'i veya agent'ı kullanıcının açık onayı olmadan **kendiliğinden çalıştırma**. Skill için kullanıcının `/skill-adı` yazması, agent için ise önerdikten sonra kullanıcının onay vermesi gerekir.
- Bu kural, bu repoya bundan sonra eklenecek her yeni skill listesi için de geçerlidir — ayrıca hatırlatmaya gerek yok.

**Neden:** Kullanıcı, önerilen skill/agent'ları hangi durumda kullanmanın uygun olduğunu genel olarak öğrenmek istiyor; bu yüzden sessizce otomatik çalıştırma yerine öneri + onay akışını tercih ediyor (2026-07-12/13).
