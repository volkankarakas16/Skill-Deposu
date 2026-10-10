#!/usr/bin/env bash
# Bulut (Linux) oturumlari icin oturum-basi guncelleyici: Windows'taki
# check-skill-updates.ps1 + apply-skill-updates.ps1 + check-agent-skills-updates.ps1
# ucunun bash karsiligi.
#
# Bulut container'i her oturumda setup script'in onbellegindeki halinden
# baslar; ~/.claude altindaki durum dosyasi da o onbellekte kalir. Bu yuzden
# taban (baseline) kurulum aninda yazilir ve her oturum ona gore kontrol edilir.
#
#   bash cloud-skill-update.sh --record  # tabani yaz (install-cloud-skills.sh cagirir)
#   bash cloud-skill-update.sh           # SessionStart hook'u: kontrol + arka planda guncelle
#   bash cloud-skill-update.sh --apply   # guncellemeyi on planda calistir (log'a yazar)
#
# Izlenen repolar: claude-marketplaces.txt + agent-skills-lock.json'daki github
# kaynaklari. Yeni commit kontrolu "git ls-remote" ile yapilir (birkac saniye).
# Kapatmak icin: ~/.claude/skill-autoupdate-off adinda bos dosya olustur.
# Test icin: SKILL_AUTOUPDATE_DRYRUN=1 komutlari calistirmadan log'a yazar.

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="$HOME/.claude/cloud-skill-update-state.json"
LOG="$HOME/.claude/cloud-skill-update.log"
MODE="${1:-check}"

# Yorum (#) ve bos satirlari atlayarak dosya satirlarini yazar.
list_entries() {
    [ -f "$1" ] || return 0
    sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$1" | grep -v -e '^#' -e '^$'
}

# "tur<TAB>owner/repo" satirlari: plugin marketplace'leri ve skills.sh kaynaklari.
tracked_repos() {
    list_entries "$DIR/claude-marketplaces.txt" | sed 's/^/plugin\t/'
    [ -f "$DIR/agent-skills-lock.json" ] && python3 - "$DIR/agent-skills-lock.json" <<'PY' | tr -d '\r'
import json, sys
skills = json.load(open(sys.argv[1], encoding="utf-8")).get("skills", {})
for src in sorted({e["source"] for e in skills.values() if e.get("sourceType") == "github"}):
    print(f"skill\t{src}")
PY
}

# Her repo icin "tur<TAB>repo<TAB>sha" yazar; ulasilamayan repo atlanir.
current_heads() {
    tracked_repos | while IFS=$'\t' read -r kind repo; do
        # </dev/null: git, dongunun okudugu repo listesini tuketmesin.
        sha=$(timeout 15 git ls-remote "https://github.com/$repo" HEAD </dev/null 2>/dev/null | cut -f1)
        [ -n "$sha" ] && printf '%s\t%s\t%s\n' "$kind" "$repo" "$sha"
    done
}

write_state() {
    mkdir -p "$(dirname "$STATE")"
    current_heads | python3 -c '
import json, sys
state = {}
for line in sys.stdin:
    kind, repo, sha = line.rstrip("\n").split("\t")
    state[repo] = {"kind": kind, "sha": sha}
json.dump(state, open(sys.argv[1], "w"), indent=2)
' "$STATE"
}

session_context() {
    python3 -c 'import json, sys; print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": sys.argv[1]}}))' "$1"
}

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >>"$LOG"; }

run() {
    if [ "${SKILL_AUTOUPDATE_DRYRUN:-0}" = 1 ]; then
        log "DRYRUN: $*"
        return 0
    fi
    "$@" >>"$LOG" 2>&1 || log "  HATA ($?): $*"
}

case "$MODE" in
--record)
    write_state
    echo "Guncelleme tabani yazildi: $STATE"
    ;;

--apply)
    kinds="${2:-plugin,skill}"
    log "=== cloud-skill-update basladi (tur: $kinds) ==="
    if [[ "$kinds" == *plugin* ]]; then
        while read -r m; do run claude plugin marketplace add "$m"; done < <(list_entries "$DIR/claude-marketplaces.txt")
        while read -r p; do run claude plugin update "$p"; done < <(list_entries "$DIR/claude-skills.txt")
    fi
    if [[ "$kinds" == *skill* ]]; then
        run npx -y skills update -y </dev/null
    fi
    write_state
    log "=== bitti. Guncel skill'ler bir sonraki mesajdan itibaren yuklenir. ==="
    ;;

check)
    [ -f "$HOME/.claude/skill-autoupdate-off" ] && exit 0
    # Taban yoksa (setup script eski surumle kurulduysa) simdi yaz, guncelleme yapma.
    if [ ! -f "$STATE" ]; then
        write_state
        exit 0
    fi
    changed=$(current_heads | python3 -c '
import json, sys
state = json.load(open(sys.argv[1]))
for line in sys.stdin:
    kind, repo, sha = line.rstrip("\n").split("\t")
    prev = state.get(repo, {}).get("sha")
    if prev and prev != sha:
        print(f"{kind}\t{repo}")
' "$STATE" | tr -d '\r')
    [ -z "$changed" ] && exit 0
    kinds=$(cut -f1 <<<"$changed" | sort -u | paste -sd, -)
    # Arka planda calistir: oturum acilisi beklemesin, ciktilar log'a gitsin.
    nohup setsid bash "$DIR/cloud-skill-update.sh" --apply "$kinds" >/dev/null 2>&1 </dev/null &
    session_context "Skill guncelleme kontrolu (bulut): yeni commit olan repolar: $(cut -f2 <<<"$changed" | paste -sd, - | sed 's/,/, /g'). Guncelleme arka planda baslatildi (log: ~/.claude/cloud-skill-update.log); guncel skill'ler bir sonraki mesajdan itibaren yuklenir."
    ;;

*)
    echo "Kullanim: bash cloud-skill-update.sh [--record | --apply [plugin,skill]]" >&2
    exit 2
    ;;
esac
exit 0
