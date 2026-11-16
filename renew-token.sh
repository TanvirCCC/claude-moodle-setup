#!/bin/bash
# renew-token.sh — swap an expired Moodle token for a fresh one in Claude's config.
#
# Before running: get a fresh moodlemobile://token=... URL with the Safari console
# method in README Step 1 and copy it (or the whole console warning line).
#
# Run in Terminal (NOT the Safari console):
#   bash <(curl -fsSL https://raw.githubusercontent.com/TanvirCCC/claude-moodle-setup/main/renew-token.sh)
#
# What it does:
#   1. Decodes the token (middle field of signature:::token[:::privatetoken])
#   2. Tests it against Moodle — nothing is changed if Moodle rejects it
#   3. Replaces the old token in Claude Desktop's config (backup kept as .bak)
#   4. Does the same in Claude Code's ~/.claude.json if it holds the same old token
# The token itself is never printed.

CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
CODE_CFG="$HOME/.claude.json"

if [ ! -f "$CFG" ]; then
  echo "❌ Claude Desktop config not found at: $CFG"; exit 1
fi

URL=$(plutil -extract mcpServers.moodle.env.MOODLE_URL raw -o - "$CFG" 2>/dev/null)
OLD=$(plutil -extract mcpServers.moodle.env.MOODLE_TOKEN raw -o - "$CFG" 2>/dev/null)
if [ -z "$URL" ] || [ -z "$OLD" ]; then
  echo "❌ No mcpServers.moodle entry with MOODLE_URL and MOODLE_TOKEN in the config. Do Step 3 of the README first."; exit 1
fi

printf 'Paste the moodlemobile://token=... URL or the console warning line\n(or just press Enter to use what is on your clipboard): '
read -r RAW
[ -z "$RAW" ] && RAW=$(pbpaste)

# Pull out just the base64 part — tolerates the surrounding console text and trailing full stop
B64=$(printf '%s' "$RAW" | tr -d '\n' | sed -E 's/.*token=([A-Za-z0-9+\/=]+).*/\1/')
NEW=$(printf '%s' "$B64" | base64 --decode 2>/dev/null | awk -F':::' '{print $2}')

if ! printf '%s' "$NEW" | grep -Eq '^[A-Za-z0-9]{20,}$'; then
  echo "❌ Couldn't find a token in what you pasted. It should contain moodlemobile://token=..."; exit 1
fi
if [ "$NEW" = "$OLD" ]; then
  echo "ℹ️  That's the same token already in your config — nothing to change."; exit 0
fi

RES=$(curl -s "$URL/webservice/rest/server.php?wstoken=$NEW&wsfunction=core_webservice_get_site_info&moodlewsrestformat=json")
if ! printf '%s' "$RES" | grep -q '"sitename"'; then
  echo "❌ Moodle rejected the new token — config NOT changed:"
  printf '%s' "$RES" | grep -o '"\(errorcode\|message\)":"[^"]*"'
  exit 1
fi

cp "$CFG" "$CFG.bak" && sed -i '' "s/$OLD/$NEW/" "$CFG" \
  && echo "✅ Token valid — Claude Desktop config updated (backup: claude_desktop_config.json.bak)"

if [ -f "$CODE_CFG" ]; then
  if grep -q "$OLD" "$CODE_CFG"; then
    cp "$CODE_CFG" "$CODE_CFG.bak" && sed -i '' "s/$OLD/$NEW/g" "$CODE_CFG" \
      && echo "✅ Claude Code (~/.claude.json) updated too"
  elif grep -q '"moodle"' "$CODE_CFG"; then
    echo "ℹ️  Claude Code has a moodle server with a different token — re-add it with README Step 5."
  fi
fi

echo
echo "Now fully quit Claude (Cmd+Q) and reopen it. Restart Claude Code too if you use it."
