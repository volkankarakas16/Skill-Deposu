#!/usr/bin/env bash
# Bulut oturumu acilisinda (ve devam ettirilisinde) /home/user altindaki
# git repolarini GitHub ile esitler. SessionStart hook'u olarak calisir;
# install-cloud-skills.sh kaydeder (matcher: startup|resume).
#
# Neden: bulut container'i repoyu yalnizca ILK acilista klonlar. Oturum
# gunlerce surdugunde, yerel bilgisayardan yapilan push'lar buraya kendiligin-
# den gelmez. 2026-10-13'te Skill-Deposu bu yuzden 6 commit geride kaldi.
#
# Guvenli: yalnizca fast-forward yapar. Commit edilmemis degisiklik varsa ya da
# dallar ayrismissa HICBIR SEY degistirmez, yalnizca durumu bildirir.
# Sonuc Claude'a additionalContext olarak gider; degisiklik yoksa sessizdir.
#
# Skill-Deposu cekildiyse install-cloud-skills.sh --fast calisir. Yeni
# CLAUDE.md kurallari ve hook'lar ayni oturumda devreye girer.
#
# Elle calistirma: bash cloud-repo-sync.sh
# Kapatma: ~/.claude/repo-sync-off dosyasini olusturun.

set -uo pipefail

[ -f "$HOME/.claude/repo-sync-off" ] && exit 0
ROOT="${REPO_SYNC_ROOT:-/home/user}"
# Kurulum betiginin her oturumda klonladigi kopya (README > Setup script).
SKILL_HOME="${SKILL_DEPOSU_HOME:-/opt/skill-deposu}"

# Tek repo: "durum<TAB>repo<TAB>aciklama" satiri yazar.
sync_one() {
    local d="$1" name branch upstream behind ahead
    name=$(basename "$d")
    branch=$(git -C "$d" symbolic-ref --short -q HEAD) || { printf 'atla\t%s\tdetached HEAD\n' "$name"; return; }
    upstream=$(git -C "$d" rev-parse --abbrev-ref -q "@{u}" 2>/dev/null) || upstream="origin/$branch"
    # GIT_TERMINAL_PROMPT=0: kimlik sormadan dussun. timeout: acilis beklemesin.
    if ! GIT_TERMINAL_PROMPT=0 timeout 12 git -C "$d" fetch -q origin "$branch" </dev/null 2>/dev/null; then
        printf 'hata\t%s\tfetch basarisiz\n' "$name"; return
    fi
    git -C "$d" rev-parse -q --verify "$upstream" >/dev/null || upstream="FETCH_HEAD"
    behind=$(git -C "$d" rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)
    ahead=$(git -C "$d" rev-list --count "$upstream..HEAD" 2>/dev/null || echo 0)
    [ "$behind" = 0 ] && { [ "$ahead" != 0 ] && printf 'ileri\t%s\t%s commit push edilmedi\n' "$name" "$ahead"; return; }
    if [ -n "$(git -C "$d" status --porcelain --untracked-files=no)" ]; then
        printf 'atla\t%s\tGitHub %s commit ileride ama commit edilmemis degisiklik var, cekilmedi\n' "$name" "$behind"
    elif [ "$ahead" != 0 ]; then
        printf 'atla\t%s\tdallar ayrismis (yerel +%s, GitHub +%s), cekilmedi\n' "$name" "$ahead" "$behind"
    elif git -C "$d" merge -q --ff-only "$upstream" >/dev/null 2>&1; then
        printf 'cekildi\t%s\t%s yeni commit (%s)\n' "$name" "$behind" "$(git -C "$d" log -1 --format=%h)"
    else
        printf 'hata\t%s\tfast-forward basarisiz\n' "$name"
    fi
}

# Repolar paralel esitlenir. Cikti sirasi karisabilir, sonda siralanir.
results=$(
    for g in "$ROOT"/*/.git "$SKILL_HOME/.git"; do
        [ -d "$g" ] || continue
        sync_one "$(dirname "$g")" &
    done
    wait
)
results=$(sort -t$'\t' -k2 <<<"$results" | sed '/^$/d')
[ -z "$results" ] && exit 0

# Skill-Deposu cekildiyse hizli kurulum. Hook'larin isaret ettigi kopya
# once /opt klonu, yoksa oturuma eklenen repo. Sirayla, tek kez calisir:
# iki kurulum ayni anda settings.json'a yazmasin.
if grep -qiP '^cekildi\tskill-deposu\t' <<<"$results"; then
    for d in "$SKILL_HOME" "$ROOT"/[Ss]kill-[Dd]eposu; do
        if [ -f "$d/install-cloud-skills.sh" ]; then
            if bash "$d/install-cloud-skills.sh" --fast >/dev/null 2>&1; then
                results+=$'\nkuruldu\tskill-deposu\tCLAUDE.md ve hook\'lar tazelendi (--fast)'
            else
                results+=$'\nhata\tskill-deposu\t--fast kurulum basarisiz'
            fi
            break
        fi
    done
fi

# Ozet Claude'a gider. Kullaniciya ilk cevapta iletilmesi istenir.
python3 -c '
import json, sys
lines = [l.split("\t") for l in sys.argv[1].splitlines()]
msg = "Oturum acilisi repo esitlemesi (cloud-repo-sync.sh):\n" + "\n".join(
    f"- {repo}: {durum} - {aciklama}" for durum, repo, aciklama in lines)
if any(d in ("atla", "hata", "ileri") for d, _, _ in lines):
    msg += "\nCekilmeyen repolar var. Kullaniciya ilk cevapta bildir."
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart",
                                         "additionalContext": msg}}))
' "$results"
exit 0
