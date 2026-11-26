#!/bin/bash
# Claude Code status line: project, git branch, model, context used, 5h + 7d quota of the current
# account, and last known quota of every other account you have logged in with (/login).
in=$(cat)
E=$'\033'
clean() { printf "%s" "$1" | tr -d "\000-\037\177"; }   # strip control chars from names
acct=$(jq -r '.oauthAccount.emailAddress // "?"' "$HOME/.claude.json" 2>/dev/null | cut -d@ -f1); acct=$(clean "$acct")
cache="$HOME/.claude/quota-cache"; mkdir -p "$cache"
now=$(date +%s)

dt() { date -r "$1" +"$2" 2>/dev/null || date -d "@$1" +"$2"; }   # macOS / Linux
fmt() { # pct resets_at [format]
  [ -z "$1" ] && return
  local p=${1%.*} t=""
  [ -n "$2" ] && [ "$2" != 0 ] && t=$(dt "$2" "${3:-%a}")
  local c="${E}[32m"; [ "$p" -ge 70 ] && c="${E}[33m"; [ "$p" -ge 90 ] && c="${E}[31m"
  printf "${c}%s%%${E}[0m→%s" "$p" "$t"
}

f5=$(echo "$in" | jq -r '.rate_limits.five_hour.used_percentage // empty')
r5=$(echo "$in" | jq -r '.rate_limits.five_hour.resets_at // empty')
f7=$(echo "$in" | jq -r '.rate_limits.seven_day.used_percentage // empty')
r7=$(echo "$in" | jq -r '.rate_limits.seven_day.resets_at // empty')
# Right after /login, stdin may still carry the previous account's quota: skip the write when the
# weekly reset equals another account's cached one to the second.
dup=""
for f in "$cache"/*.json; do
  [ -e "$f" ] || continue; [ "$(jq -r .a "$f")" = "$acct" ] && continue
  [ -n "$r7" ] && [ "$(jq -r '.r.seven_day.resets_at // empty' "$f")" = "$r7" ] && dup=1
done
[ -n "$f7$f5" ] && [ -z "$dup" ] && echo "$in" | jq -c --arg a "$acct" --argjson t "$now" '{a:$a,t:$t,r:.rate_limits}' > "$cache/$acct.json"

out="[$acct] 5h $(fmt "$f5" "$r5" %H:%M) · 7d $(fmt "$f7" "$r7")"
[ -z "$f5$f7" ] && out="[$acct] quota: waiting for first response"
[ -n "$dup" ] && out="[$acct] 7d ? (previous account's data)"
hint=""
[ -n "$f5" ] && [ "${f5%.*}" -ge 90 ] && hint=" ${E}[31m⇄ 5h almost out${E}[0m"
[ -n "$f7" ] && [ "${f7%.*}" -ge 90 ] && hint=" ${E}[31m⇄ week almost out${E}[0m"

for f in "$cache"/*.json; do
  [ -e "$f" ] || continue
  o=$(jq -r .a "$f"); [ "$o" = "$acct" ] && continue
  if [ "$(jq -r '.r.seven_day // empty' "$f")" = "" ]; then out="$out | [$o] 7d ?"; continue; fi
  o5=$(jq -r '.r.five_hour.used_percentage // empty' "$f"); o5r=$(jq -r '.r.five_hour.resets_at // 0' "$f")
  o7=$(jq -r '.r.seven_day.used_percentage // empty' "$f"); o7r=$(jq -r '.r.seven_day.resets_at // 0' "$f")
  [ "$o5r" -lt "$now" ] && o5=0
  [ "$o7r" -gt 0 ] && [ "$o7r" -lt "$now" ] && { o7=0; while [ "$o7r" -lt "$now" ]; do o7r=$((o7r + 7*86400)); done; }
  out="$out | [$o] 5h $(fmt "${o5:-0}") · 7d $(fmt "${o7:-0}" "$o7r")"
done
# Suggest switching: the account whose weekly window resets soonest and still has room (< 95%).
best=""; bestr=9999999999
for f in "$cache"/*.json; do
  [ -e "$f" ] || continue
  a=$(jq -r .a "$f")
  p7=$(jq -r '.r.seven_day.used_percentage // 0' "$f"); rr=$(jq -r '.r.seven_day.resets_at // 0' "$f")
  p5=$(jq -r '.r.five_hour.used_percentage // 0' "$f"); r5x=$(jq -r '.r.five_hour.resets_at // 0' "$f")
  [ "$rr" -lt "$now" ] && { p7=0; rr=$((now + 7*86400)); }
  [ "$r5x" -lt "$now" ] && p5=0
  [ "${p7%.*}" -ge 95 ] && continue
  [ "${p5%.*}" -ge 95 ] && continue
  [ "$rr" -lt "$bestr" ] && { best=$a; bestr=$rr; }
done
[ -z "$hint" ] && [ -n "$best" ] && [ "$best" != "$acct" ] && hint=" ${E}[33m⇄ [$best]${E}[0m"

# Project: shell alias that cd's into the project root (from ~/.zshrc / ~/.bashrc) or folder name,
# plus the current subfolder when Claude has cd'ed below the root.
dir=$(echo "$in" | jq -r '.workspace.current_dir // .cwd // empty')
root=$(echo "$in" | jq -r '.workspace.project_dir // empty')
[ -z "$root" ] && root="$dir"
proj=""
if [ -n "$root" ]; then
  al=$(grep -hE "^alias [A-Za-z0-9_-]+=[\"']cd ${root//\//\\/}/?[\"']\$" "$HOME/.zshrc" "$HOME/.bashrc" 2>/dev/null | head -1 | sed -E 's/^alias ([^=]+)=.*/\1/')
  name=$(clean "${al:-$(basename "$root")}")
  [ -n "$dir" ] && [ "$dir" != "$root" ] && name="$name($(clean "$(basename "$dir")"))"
  proj="${E}[36m${name}${E}[0m  "
fi

br=""
[ -n "$dir" ] && b=$(git -C "$dir" branch --show-current 2>/dev/null) && b=$(clean "$b") && [ -n "$b" ] && br="${E}[34m⎇ ${b}${E}[0m  "

model=$(echo "$in" | jq -r '.model.display_name // .model.id // empty'); model=$(clean "$model")
cx=$(echo "$in" | jq -r '.context_window.used_percentage // empty')
mi=""
[ -n "$model" ] && mi="${E}[35m${model}${E}[0m"
if [ -n "$cx" ]; then
  cp=${cx%.*}; cc="${E}[32m"; [ "$cp" -ge 60 ] && cc="${E}[33m"; [ "$cp" -ge 80 ] && cc="${E}[31m"
  mi="$mi ${cc}ctx ${cp}%${E}[0m"
fi
[ -n "$mi" ] && mi="$mi  "

printf "%s\n" "$proj$br$mi$out$hint"
