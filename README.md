# Claude + Moodle MCP — Setup Guide

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Moodle](https://img.shields.io/badge/Moodle-4.5.8-orange.svg)
![Platform](https://img.shields.io/badge/Platform-macOS-lightgrey.svg)
![moodle-mcp](https://img.shields.io/badge/moodle--mcp-0.2.0-green.svg)

> A complete end-to-end guide for connecting Claude Desktop and Claude Code to your university Moodle — including a workaround for schools that use **Microsoft/Google SSO login**, where the standard token method doesn't work.
>
> Built on top of [moodle-mcp](https://github.com/1alexandrer/moodle-mcp) by [@1alexandrer](https://github.com/1alexandrer). All credit for the MCP server goes to them — this repo documents the full setup process and the SSO token workaround that isn't in the original README.

---

## What you can do once connected

- *"What assignments do I have due this week?"*
- *"Summarise my Derivatives course"*
- *"What are my grades so far?"*
- *"Build me a linked Obsidian study vault from all my course notes"*

Claude gets live access to your courses, assignments, grades, deadlines, and files — all through natural conversation.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step 1 — Get your Moodle token](#step-1--get-your-moodle-token)
   - [Standard login](#standard-usernamepassword-login)
   - [SSO login (Microsoft/Google)](#sso-microsoftgoogle-login--the-tricky-one)
3. [Step 2 — Install moodle-mcp](#step-2--install-moodle-mcp)
4. [Step 3 — Configure Claude Desktop](#step-3--configure-claude-desktop)
5. [Step 4 — Verify the connection](#step-4--verify-the-connection)
6. [Step 5 — Use with Claude Code](#step-5-optional--use-with-claude-code)
7. [Bonus — Build an Obsidian study vault](#bonus--build-an-obsidian-study-vault)
8. [Troubleshooting](#troubleshooting)
9. [Tested on](#tested-on)

---

## Prerequisites

| Requirement | Check |
|---|---|
| [Claude Desktop](https://claude.ai/download) | Installed and logged in |
| [Node.js](https://nodejs.org) (LTS) | `node --version` → should return a version number |
| University Moodle account | Any school running Moodle 4.x |

---

## Step 1 — Get your Moodle token

### Standard username/password login

Navigate to this URL while logged into Moodle in your browser:

```
https://moodle.yourschool.edu/user/managetoken.php
```

Copy the **Moodle mobile web service** token and skip to [Step 2](#step-2--install-moodle-mcp).

---

### SSO (Microsoft/Google) login — the tricky one

If your school uses SSO, the token page only shows an RSS token — not the one you need. The Moodle app "tap the version number 5 times" trick also no longer works on newer app versions.

Here's the method that actually works:

**1. Log into Moodle in Safari** on your Mac (must be Safari, not Chrome/Firefox).

**2. Open this URL** — swap in your school's Moodle domain:

```
https://moodle.yourschool.edu/admin/tool/mobile/launch.php?service=moodle_mobile_app&passport=12345&urlscheme=moodlemobile
```

**3.** Safari will try (and fail) to open a `moodlemobile://` URL. A blank "Untitled" tab will appear. **Click the address bar of that tab** — it shows a long URL starting with `moodlemobile://token=...`

**4.** Select all (`Cmd+A`) and copy the full URL.

**5.** Extract the base64 string — it's everything after `token=`, including the trailing `==`.

**6.** Decode it in Terminal:

```bash
echo "YOUR_BASE64_STRING==" | base64 --decode
```

The output is colon-separated. Depending on your Moodle version it has **two or three** fields:

```
# two-field format (older Moodle):
<signature>:::<token>

# three-field format (newer Moodle — this is what City St George's returns):
<signature>:::<token>:::<privatetoken>
```

> **Your web service token is the _middle_ field** — the value between the first and second `:::`.
> - The **first** field is a passport signature, not a token.
> - The optional **third** field is a "private token" used only for the Moodle mobile app's auto-login — you don't need it here.
>
> ⚠️ Don't just copy "everything after `:::`". If you get three fields there are two separators, and the **last** field is the wrong one. Take the field in the middle.

**7.** Verify the token works:

```bash
curl "https://moodle.yourschool.edu/webservice/rest/server.php?wstoken=YOUR_TOKEN&wsfunction=core_webservice_get_site_info&moodlewsrestformat=json"
```

A successful response returns your name, username, and site info as JSON. If you see that, your token is valid.

> 🔒 **Treat this token like a password.** It grants full access to your Moodle account — your courses, grades, personal details, and messages. Anyone who has it can act as you.
> - Never commit it to a public repo, paste it into a chat, or share a screenshot of it.
> - If it's ever exposed, generate a fresh one by repeating the SSO steps above — doing so invalidates the previous token.
> - The `your_token_here` placeholders in the config examples below are intentional. Put your real token only in your local config files, never anywhere public.

---

## Step 2 — Install moodle-mcp

Install the package globally so Claude Desktop can find it without needing to fetch it on every start:

```bash
npm install -g moodle-mcp
```

Then grab the two paths you'll need in the next step — the absolute path to `node`, and the absolute path to the server script:

```bash
which node
# e.g. /opt/anaconda3/bin/node

echo "$(npm root -g)/moodle-mcp/dist/server.js"
# e.g. /opt/anaconda3/lib/node_modules/moodle-mcp/dist/server.js
```

> **Why not just point Claude at `moodle-mcp` directly?** The `moodle-mcp` command is a small wrapper whose first line is `#!/usr/bin/env node` — meaning "find `node` on the PATH." Claude Desktop launches MCP servers with a **minimal PATH** that often does *not* include your Node install directory (very common with Anaconda/nvm). When that happens the wrapper can't find `node`, exits instantly, and Claude reports **"Server disconnected."** Pointing the config straight at the `node` binary with the script as an argument sidesteps the PATH lookup entirely and is far more robust. See [Troubleshooting](#troubleshooting).

---

## Step 3 — Configure Claude Desktop

Open the Claude Desktop config file:

```bash
open -e ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

Merge in the `mcpServers` block below. Set `command` to your absolute **node** path and put the **server.js** path in `args` — use the two values you got from Step 2. Do not write `moodle-mcp`, `npx`, or a bare `node`:

```json
{
  "mcpServers": {
    "moodle": {
      "command": "/opt/anaconda3/bin/node",
      "args": [
        "/opt/anaconda3/lib/node_modules/moodle-mcp/dist/server.js"
      ],
      "env": {
        "MOODLE_URL": "https://moodle.yourschool.edu",
        "MOODLE_TOKEN": "your_token_here"
      }
    }
  }
}
```

> **Older guides (and the original README) tell you to set `command` to the `moodle-mcp` wrapper directly.** That works *only if* Claude Desktop happens to see `node` on its PATH — which frequently it doesn't. The node + `server.js` form above is the reliable version and is what fixed a stubborn "Server disconnected" loop on a fresh install. If you'd rather try the shorter form first, it's `"command": "/opt/anaconda3/bin/moodle-mcp", "args": []` — just switch to the form above the moment you see "Server disconnected."

Save the file (`Cmd+S`), then **fully quit** Claude Desktop (`Cmd+Q`, not just closing the window) and reopen it.

---

## Step 4 — Verify the connection

In a new Claude Desktop chat, click the **+** button in the input box → **Connectors** → confirm Moodle shows a blue toggle.

Test it by asking: *"What courses am I enrolled in?"*

---

## Step 5 (optional) — Use with Claude Code

To use the same Moodle tools inside the Claude Code CLI, run this once (same node + `server.js` form as Step 3):

```bash
claude mcp add moodle /opt/anaconda3/bin/node \
  "$(npm root -g)/moodle-mcp/dist/server.js" \
  -e MOODLE_URL=https://moodle.yourschool.edu \
  -e MOODLE_TOKEN=your_token_here
```

Restart Claude Code for the change to take effect.

---

## Bonus — Build an Obsidian study vault

With Claude Code running locally, you can pull all your course materials and have them written as a fully linked [Obsidian](https://obsidian.md) vault directly to your machine:

```
Pull all my Moodle courses and build a linked Obsidian vault at
/Users/yourname/Desktop/Study Notes — one note per topic with [[wikilinks]]
between related concepts, a MOC.md index, and tags for each section.
```

> **Important:** Use **Claude Code** (not Claude Desktop chat) for this. Claude Desktop runs in a sandbox and cannot write to your local filesystem. Claude Code runs natively on your machine and writes files directly.

---

## Troubleshooting

**"Server disconnected" in Claude Desktop** *(the most common issue)*

This almost always means the server process crashed on launch — **not** a token problem. The usual cause: Claude Desktop launches MCP servers with a minimal `PATH`, and the `moodle-mcp` wrapper's shebang (`#!/usr/bin/env node`) can't find `node` on it, so it exits before it can even talk to Moodle.

The fix is the config form in [Step 3](#step-3--configure-claude-desktop): set `command` to your absolute `node` path and pass `.../moodle-mcp/dist/server.js` in `args`. This skips the PATH lookup entirely.

To confirm this is what's happening, run the wrapper under a stripped-down PATH — if you see `env: node: No such file or directory`, that's it:

```bash
env -i PATH="/usr/bin:/bin" $(which moodle-mcp) </dev/null
```

Then verify the node + script form starts cleanly (it should sit and wait for input rather than exit):

```bash
env -i PATH="/usr/bin:/bin" $(which node) "$(npm root -g)/moodle-mcp/dist/server.js"
# Press Ctrl+C to stop — no error output means it's healthy.
```

The **View Logs** button under the server entry in Claude Desktop's MCP settings shows the exact error if you need to dig deeper.

> **Tip:** If the token is genuinely expired you'll see `invalidtoken` in the logs (not "Server disconnected") — regenerate it via [Step 1](#step-1--get-your-moodle-token). SSO Moodle tokens expire periodically, so this is normal maintenance, not a broken setup.

**Token page only shows RSS token**

Your school's mobile web service token isn't exposed on the standard token page. Use the [SSO method above](#sso-microsoftgoogle-login--the-tricky-one) to extract it via the browser redirect.

**`fetch failed` error in MCP logs**

This usually means the token is being rejected. Verify it with the `curl` command in Step 1 before adding it to the config.

**Hammer/tools icon not showing in Claude Desktop**

It's hidden behind the **+** button in the input box → click **Connectors**.

---

## Tested on

| | |
|---|---|
| **School** | City St George's, University of London (`moodle4.city.ac.uk`) |
| **Login** | Microsoft SSO |
| **OS** | macOS (Apple Silicon) |
| **Moodle version** | 4.5.8 (Build 20251208) |
| **moodle-mcp version** | 0.2.0 |
| **Node.js version** | v22.6.0 |

---

## Credit

All credit for the MCP server goes to [@1alexandrer](https://github.com/1alexandrer) — [github.com/1alexandrer/moodle-mcp](https://github.com/1alexandrer/moodle-mcp).

This guide documents the full end-to-end setup and the SSO workaround discovered while setting it up at City St George's, University of London.
