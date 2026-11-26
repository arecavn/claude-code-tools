#!/bin/bash
# Install: curl -fsSL https://raw.githubusercontent.com/arecavn/claude-code-tools/main/statusline-quota/install.sh | bash
set -e
command -v jq >/dev/null || { echo "Need jq: brew install jq  (or: sudo apt install jq)"; exit 1; }
dst="$HOME/.claude/claude-statusline-quota.sh"; set_="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"
curl -fsSL "${SRC:-https://raw.githubusercontent.com/arecavn/claude-code-tools/main/statusline-quota/statusline.sh}" -o "$dst"
chmod +x "$dst"
[ -f "$set_" ] || echo '{}' > "$set_"
cp "$set_" "$set_.bak-$(date +%Y%m%d%H%M%S)"
jq '.statusLine = {type:"command", command:"~/.claude/claude-statusline-quota.sh", refreshInterval:60}' "$set_" > "$set_.tmp" && mv "$set_.tmp" "$set_"
echo "Done. Restart Claude Code (or open a new session) to see the status line."
