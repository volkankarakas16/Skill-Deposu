#!/usr/bin/env bash
# Bulut (Linux) oturumlari icin tek seferlik kurulum: Windows'taki .ps1
# scriptlerinin bash karsiligi. Ayni listeleri okur:
#   - claude-marketplaces.txt + claude-skills.txt  -> claude plugin install
#   - agent-skills-lock.json                       -> npx skills add -g
#   - global-CLAUDE.md                             -> ~/.claude/CLAUDE.md
#   - skill-oneri hatirlatma hook'u                -> ~/.claude/settings.json
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

echo "== Skill-oneri hook'u =="
if [ "$DRY_RUN" = 1 ]; then
    echo "DRYRUN: UserPromptSubmit hook'u ~/.claude/settings.json'a eklenecek"
else
    python3 - "$HOME/.claude/settings.json" <<'PY' || failed+=("hook:skill-suggestion")
import json, os, sys
path = sys.argv[1]
settings = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
reminder = ("Bu soruya uygun bir skill veya agent var mi kontrol et ve varsa oner "
            "(bu preamble/postamble sayilmaz, atlama).")
payload = json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit",
                                             "additionalContext": reminder}})
command = "echo '" + payload + "'"
groups = settings.setdefault("hooks", {}).setdefault("UserPromptSubmit", [])
if any(h.get("command") == command for g in groups for h in g.get("hooks", [])):
    print("Zaten kurulu.")
else:
    groups.append({"hooks": [{"type": "command", "command": command}]})
    with open(path, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
    print("Eklendi.")
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
