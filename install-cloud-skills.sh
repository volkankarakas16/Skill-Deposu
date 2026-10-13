#!/usr/bin/env bash
# Bulut (Linux) oturumlari icin tek seferlik kurulum: Windows'taki .ps1
# scriptlerinin bash karsiligi. Ayni listeleri okur:
#   - claude-marketplaces.txt + claude-skills.txt  -> claude plugin install
#   - agent-skills-lock.json                       -> npx skills add -g
#   - global-CLAUDE.md                             -> ~/.claude/CLAUDE.md
#   - cevap dili (language=turkish)                -> ~/.claude/settings.json
#   - skill-oneri hatirlatma hook'u                -> ~/.claude/settings.json
#   - oturum-basi guncelleme hook'u                -> cloud-skill-update.sh (SessionStart)
#   - repo esitleme hook'u                         -> cloud-repo-sync.sh (SessionStart)
#   - PowerShell (pwsh)                            -> .ps1 betiklerini bulutta test icin
#   - STE-TR yazim denetimi hook'u                 -> ste-tr-denetim.py (Stop)
#
# Bulut ortaminin "setup script" alanindan cagrilmak uzere yazildi (oturum
# baslamadan once calisir, boylece skiller ilk mesajdan itibaren yuklu olur).
# Elle de calistirilabilir:
#   bash install-cloud-skills.sh            # kur
#   bash install-cloud-skills.sh --dry-run  # sadece listele
#
# Tek bir plugin/skill hata verirse digerlerine devam eder; sonda ozet basar.

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

failed=()

run() {
    if [ "$DRY_RUN" = 1 ]; then
        echo "DRYRUN: $*"
        return 0
    fi
    "$@"
}

# Yorum (#) ve bos satirlari atlayarak dosya satirlarini yazar.
list_entries() {
    sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$1" | grep -v -e '^#' -e '^$'
}

if ! command -v claude >/dev/null 2>&1; then
    echo "claude CLI bulunamadi; plugin kurulumu atlaniyor." >&2
else
    echo "== Marketplace'ler =="
    while read -r m; do
        echo "--- $m"
        run claude plugin marketplace add "$m" || failed+=("marketplace:$m")
    done < <(list_entries "$DIR/claude-marketplaces.txt")

    echo "== Plugin'ler =="
    while read -r p; do
        echo "--- $p"
        run claude plugin install "$p" || failed+=("plugin:$p")
    done < <(list_entries "$DIR/claude-skills.txt")
fi

if ! command -v npx >/dev/null 2>&1; then
    echo "npx bulunamadi; skills.sh skilleri atlaniyor." >&2
elif [ -f "$DIR/agent-skills-lock.json" ]; then
    echo "== skills.sh skilleri =="
    # Yalnizca github kaynakli kayitlar otomatik kurulabilir (ps1 ile ayni kural).
    while IFS=$'\t' read -r name source; do
        echo "--- $source@$name"
        run npx -y skills add "$source@$name" -g -y -a claude-code </dev/null || failed+=("skill:$source@$name")
    done < <(python3 - "$DIR/agent-skills-lock.json" <<'PY'
import json, sys
skills = json.load(open(sys.argv[1], encoding="utf-8")).get("skills", {})
for name, e in skills.items():
    if e.get("sourceType") == "github":
        print(f"{name}\t{e['source']}")
    else:
        print(f"{name}: sourceType={e.get('sourceType')} (github disi), atlaniyor", file=sys.stderr)
PY
)
fi

echo "== Global CLAUDE.md =="
run mkdir -p "$HOME/.claude"
run cp "$DIR/global-CLAUDE.md" "$HOME/.claude/CLAUDE.md"

# Cevap dili: install-global-claude-md.ps1 ile ayni "language" ayari.
if [ "$DRY_RUN" = 1 ]; then
    echo "DRYRUN: ~/.claude/settings.json language=turkish yapilacak"
else
    python3 - "$HOME/.claude/settings.json" <<'PY' || failed+=("settings:language")
import json, os, sys
path = sys.argv[1]
settings = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
if settings.get("language") != "turkish":
    settings["language"] = "turkish"
    with open(path, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
    print("settings.json: language=turkish")
PY
fi

echo "== Skill-oneri hook'u =="
if [ "$DRY_RUN" = 1 ]; then
    echo "DRYRUN: UserPromptSubmit hook'u ~/.claude/settings.json'a eklenecek"
else
    python3 - "$HOME/.claude/settings.json" <<'PY' || failed+=("hook:skill-suggestion")
import json, os, sys
path = sys.argv[1]
settings = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
# skill-suggestion-reminder.ps1 ile ayni metin; tek tirnak icermemeli (echo '...').
reminder = ("Bu soruya uygun bir skill veya agent var mi kontrol et ve varsa oner "
            "(bu preamble/postamble sayilmaz, atlama). "
            "Cevabi ve ara mesajlari TURKCE yaz (arac ciktisi Ingilizce olsa da), "
            "global CLAUDE.md dosyasindaki STE-TR yazim ve sema kurallarina gore.")
payload = json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit",
                                             "additionalContext": reminder}})
command = "echo '" + payload + "'"
groups = settings.setdefault("hooks", {}).setdefault("UserPromptSubmit", [])
# Metin degisse de eski hook'u tani: sabit parcayla ara, bulunani guncelle.
existing = [h for g in groups for h in g.get("hooks", [])
            if "skill veya agent" in h.get("command", "")]
if existing and all(h["command"] == command for h in existing):
    print("Zaten kurulu.")
else:
    if existing:
        for h in existing:
            h["command"] = command
        print("Guncellendi.")
    else:
        groups.append({"hooks": [{"type": "command", "command": command}]})
        print("Eklendi.")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
PY
fi

echo "== Oturum-basi guncelleme hook'u =="
if [ "$DRY_RUN" = 1 ]; then
    echo "DRYRUN: guncelleme tabani yazilacak, SessionStart hook'u ~/.claude/settings.json'a eklenecek"
else
    bash "$DIR/cloud-skill-update.sh" --record || failed+=("update:record")
    python3 - "$HOME/.claude/settings.json" "$DIR/cloud-skill-update.sh" <<'PY' || failed+=("hook:skill-update")
import json, os, sys
path, script = sys.argv[1], sys.argv[2]
settings = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
# Repo bu oturuma eklenmediyse hook sessizce gecsin.
command = f'f="{script}"; [ -f "$f" ] && bash "$f" || true'
# matcher "startup": resume/clear/compact'ta tekrar calismasin.
# timeout 20: ls-remote takilsa bile oturum acilisi en cok 20 sn bekler.
hook = {"type": "command", "command": command, "timeout": 20}
groups = settings.setdefault("hooks", {}).setdefault("SessionStart", [])
existing = [g for g in groups
            if any("cloud-skill-update.sh" in h.get("command", "") for h in g.get("hooks", []))]
if len(existing) == 1 and existing[0] == {"matcher": "startup", "hooks": [hook]}:
    print("Zaten kurulu.")
else:
    for g in existing:
        groups.remove(g)
    groups.append({"matcher": "startup", "hooks": [hook]})
    print("Guncellendi." if existing else "Eklendi.")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
PY
fi

echo "== Repo esitleme hook'u =="
if [ "$DRY_RUN" = 1 ]; then
    echo "DRYRUN: SessionStart hook'u (cloud-repo-sync.sh) ~/.claude/settings.json'a eklenecek"
else
    python3 - "$HOME/.claude/settings.json" "$DIR/cloud-repo-sync.sh" <<'PY' || failed+=("hook:repo-sync")
import json, os, sys
path, script = sys.argv[1], sys.argv[2]
settings = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
command = f'f="{script}"; [ -f "$f" ] && bash "$f" || true'
# resume: gunlerce suren oturum devam ettirildiginde de GitHub'dan ceksin.
hook = {"type": "command", "command": command, "timeout": 30}
want = {"matcher": "startup|resume", "hooks": [hook]}
groups = settings.setdefault("hooks", {}).setdefault("SessionStart", [])
mine = lambda h: "cloud-repo-sync.sh" in h.get("command", "")
existing = [g for g in groups if any(mine(h) for h in g.get("hooks", []))]
if existing == [want]:
    print("Zaten kurulu.")
else:
    for g in groups:
        g["hooks"] = [h for h in g.get("hooks", []) if not mine(h)]
    groups[:] = [g for g in groups if g["hooks"]]
    groups.append(want)
    print("Guncellendi." if existing else "Eklendi.")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
PY
fi

echo "== PowerShell =="
# ste-tr-denetim.ps1 gibi Windows betikleri bulutta da test edilebilsin.
# Kurulamazsa yalnizca uyari: bulutta denetimi ste-tr-denetim.py yapar.
if command -v pwsh >/dev/null 2>&1; then
    echo "Zaten kurulu: $(pwsh -NoProfile -c '$PSVersionTable.PSVersion.ToString()')"
elif [ "$DRY_RUN" = 1 ]; then
    echo "DRYRUN: powershell paketi packages.microsoft.com'dan kurulacak"
elif command -v apt-get >/dev/null 2>&1 && [ -r /etc/os-release ]; then
    . /etc/os-release
    tmp=$(mktemp -d)
    if curl -sSfL -o "$tmp/ms.deb" "https://packages.microsoft.com/config/${ID}/${VERSION_ID}/packages-microsoft-prod.deb" \
        && dpkg -i "$tmp/ms.deb" >/dev/null \
        && apt-get update -qq >/dev/null 2>&1 \
        && apt-get install -y -qq powershell >/dev/null 2>&1; then
        echo "Kuruldu: $(pwsh -NoProfile -c '$PSVersionTable.PSVersion.ToString()')"
    else
        echo "PowerShell kurulamadi (atlaniyor)." >&2
    fi
    rm -rf -- "$tmp"
else
    echo "apt-get yok, PowerShell atlaniyor." >&2
fi

echo "== STE-TR denetim hook'u =="
if [ "$DRY_RUN" = 1 ]; then
    echo "DRYRUN: Stop hook'u (ste-tr-denetim.py) ~/.claude/settings.json'a eklenecek"
else
    python3 - "$HOME/.claude/settings.json" "$DIR/ste-tr-denetim.py" <<'PY' || failed+=("hook:ste-tr")
import json, os, sys
path, script = sys.argv[1], sys.argv[2]
settings = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
# Repo bu oturuma eklenmediyse hook sessizce gecsin.
command = f'f="{script}"; [ -f "$f" ] && python3 "$f" || true'
hook = {"type": "command", "command": command, "timeout": 20}
groups = settings.setdefault("hooks", {}).setdefault("Stop", [])
# Diger Stop hook'larina dokunma, yalnizca bu betigin girdisini tazele.
# Ayni gruptaki baska hook'lar korunur, bosalan grup silinir.
mine = lambda h: "ste-tr-denetim" in h.get("command", "")
existing = [h for g in groups for h in g.get("hooks", []) if mine(h)]
if existing == [hook]:
    print("Zaten kurulu.")
else:
    for g in groups:
        g["hooks"] = [h for h in g.get("hooks", []) if not mine(h)]
    groups[:] = [g for g in groups if g["hooks"]]
    groups.append({"hooks": [hook]})
    print("Guncellendi." if existing else "Eklendi.")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
PY
fi

echo ""
if [ ${#failed[@]} -gt 0 ]; then
    echo "Tamamlandi, ${#failed[@]} hata ile:"
    printf '  - %s\n' "${failed[@]}"
else
    echo "Tamamlandi, hata yok."
fi
# Setup script'in tamamen dusmemesi icin her zaman 0 ile cik; hatalar yukarida listelenir.
exit 0
