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

Output will look like:

```
abc123:::dc4e68b94090f96b619adee1b07e658b
```

> Your token is the part **after** `:::` — ignore everything before it.

**7.** Verify the token works:

```bash
curl "https://moodle.yourschool.edu/webservice/rest/server.php?wstoken=YOUR_TOKEN&wsfunction=core_webservice_get_site_info&moodlewsrestformat=json"
```

A successful response returns your name, username, and site info as JSON. If you see that, your token is valid.

---

## Step 2 — Install moodle-mcp

Install the package globally so Claude Desktop can find it without needing to fetch it on every start:

```bash
npm install -g moodle-mcp
```

Then note the full path — you'll need this in the next step:

```bash
which moodle-mcp
# e.g. /opt/anaconda3/bin/moodle-mcp
```

---

## Step 3 — Configure Claude Desktop

Open the Claude Desktop config file:

```bash
open -e ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

Merge in the `mcpServers` block below. **Use the full path** from `which moodle-mcp` — do not just write `moodle-mcp` or `npx`:

```json
{
  "mcpServers": {
    "moodle": {
      "command": "/opt/anaconda3/bin/moodle-mcp",
      "args": [],
      "env": {
        "MOODLE_URL": "https://moodle.yourschool.edu",
        "MOODLE_TOKEN": "your_token_here"
      }
    }
  }
}
```

Save the file (`Cmd+S`), then **fully quit** Claude Desktop (`Cmd+Q`) and reopen it.

---

## Step 4 — Verify the connection

In a new Claude Desktop chat, click the **+** button in the input box → **Connectors** → confirm Moodle shows a blue toggle.

Test it by asking: *"What courses am I enrolled in?"*

---

## Step 5 (optional) — Use with Claude Code

To use the same Moodle tools inside the Claude Code CLI, run this once:

```bash
claude mcp add moodle /opt/anaconda3/bin/moodle-mcp \
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

**"Server disconnected" in Claude Desktop**

Claude Desktop doesn't inherit your shell's `PATH`, so commands like `npx` or `moodle-mcp` won't resolve if Node is installed via Anaconda or a non-standard path. Always use the **absolute path** from `which moodle-mcp`.

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
