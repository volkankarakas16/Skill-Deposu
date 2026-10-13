#!/bin/bash
# Bulut ortaminin "Kurulum betigi" (Setup script) alanina AYNEN yapistirilir.
# Oturuma hangi repo eklenirse eklensin Skill-Deposu'nu /opt/skill-deposu'ya
# kendisi klonlar ve kurar. Bu yuzden Skill-Deposu'nu oturuma eklemek gerekmez.
#
# Repo herkese acik (public) olmali: kurulum betigi oturuma eklenmemis ozel
# bir repoyu klonlayamaz.
#
# Ortam onbellege alindiginda /opt/skill-deposu eski kalabilir. Oturum
# acilisinda cloud-repo-sync.sh onu GitHub'dan ceker ve hook'lari tazeler.
D=/opt/skill-deposu
U=https://github.com/volkankarakas16/Skill-Deposu
if [ -d "$D/.git" ]; then
  git -C "$D" pull -q --ff-only
else
  git clone -q --depth 1 "$U" "$D"
fi
[ -f "$D/install-cloud-skills.sh" ] && bash "$D/install-cloud-skills.sh"
true
