#!/bin/bash
# diagnose.sh — find out why the Moodle MCP server won't start.
#
# Run in Terminal:
#   bash <(curl -fsSL https://raw.githubusercontent.com/TanvirCCC/claude-moodle-setup/main/diagnose.sh)
#
# Checks the paths in Claude Desktop's config, tests the token against Moodle,
# and shows the end of the server log. The token itself is never printed.

CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
LOG="$HOME/Library/Logs/Claude/mcp-server-moodle.log"
get() { plutil -extract "mcpServers.moodle.$1" raw -o - "$CFG" 2>/dev/null; }

CMD=$(get command); ARG=$(get args.0); URL=$(get env.MOODLE_URL); TOK=$(get env.MOODLE_TOKEN)

echo "== command in config: $CMD"
ls -l "$CMD" 2>&1
echo "== server.js in config: ${ARG:-<none>}"
[ -n "$ARG" ] && ls -l "$ARG" 2>&1
echo "== npm's current location: $(npm root -g 2>/dev/null)/moodle-mcp/dist/server.js"

echo "== token check against $URL:"
curl -s "$URL/webservice/rest/server.php?wstoken=$TOK&wsfunction=core_webservice_get_site_info&moodlewsrestformat=json" \
  | grep -o '"\(sitename\|errorcode\|message\)":"[^"]*"'

echo "== last lines of $LOG:"
tail -n 15 "$LOG" 2>&1

cat <<'EOF'

How to read this:
  "No such file or directory" above  -> node or server.js moved. Redo README Steps 2-3 with the new paths.
  "errorcode":"invalidtoken"          -> token expired. Get a new one (Step 1) and run renew-token.sh.
  "sitename":...                      -> token is fine; the log lines show the real error.
EOF
