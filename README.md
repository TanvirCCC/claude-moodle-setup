# Claude + Moodle via MCP — Full Setup Guide (including SSO)

> Based on [moodle-mcp](https://github.com/1alexandrer/moodle-mcp) by [@1alexandrer](https://github.com/1alexandrer).  
> This guide documents the full setup process including the SSO token extraction
> workaround I figured out for schools using Microsoft/Google login.

---

## What this does

Connects Claude Desktop (and Claude Code) directly to your university Moodle.
You can then ask Claude things like:

- "What assignments do I have due this week?"
- "Summarise my Derivatives course"
- "Build me a linked Obsidian study vault from all my course notes"

---

## Prerequisites

- [Claude Desktop](https://claude.ai/download) installed
- [Node.js](https://nodejs.org) installed — check with `node --version`
- A university Moodle account

---

## Step 1 — Get your Moodle token

### If your school uses a regular username/password login

Go to this URL while logged into Moodle in your browser:

```
https://moodle.yourschool.edu/user/managetoken.php
```

Copy the **Moodle mobile web service** token. Done.

---

### If your school uses SSO (Microsoft/Google login) ← the tricky one

The standard token page won't show the mobile web service token for SSO schools.
The Moodle app "tap version number 5 times" trick also doesn't work on newer app versions.

Here's what actually works:

**1.** Make sure you're logged into Moodle in **Safari** on your Mac.

**2.** Open this URL in Safari (swap in your school's Moodle domain):

```
https://moodle.yourschool.edu/admin/tool/mobile/launch.php?service=moodle_mobile_app&passport=12345&urlscheme=moodlemobile
```

**3.** Safari will try to open a `moodlemobile://` URL and fail — a blank or "Untitled" tab will appear. Click the **address bar** of that tab. It will show a long URL starting with `moodlemobile://token=...`

**4.** Select all and copy the full URL.

**5.** Grab just the base64 string after `token=` (everything up to and including the `==`).

**6.** Decode it in Terminal:

```bash
echo "YOUR_BASE64_STRING==" | base64 --decode
```

The output looks like:

```
abc123:::dc4e68b94090f96b619adee1b07e658b
```

Your token is the part **after** `:::`.

**7.** Verify it works:

```bash
curl "https://moodle.yourschool.edu/webservice/rest/server.php?wstoken=YOUR_TOKEN&wsfunction=core_webservice_get_site_info&moodlewsrestformat=json"
```

If it returns your name and site info, the token is valid.

---

## Step 2 — Install moodle-mcp globally

```bash
npm install -g moodle-mcp
which moodle-mcp   # note the path, e.g. /opt/anaconda3/bin/moodle-mcp
```

---

## Step 3 — Configure Claude Desktop

Open the config file:

```bash
open -e ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

Add the `mcpServers` block. Use the **full path** from `which moodle-mcp`:

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

Save, then fully quit Claude Desktop (`Cmd+Q`) and reopen it.

> **Why the full path?** Claude Desktop doesn't inherit your shell's PATH, so
> `npx` or `moodle-mcp` alone won't resolve if Node is installed via Anaconda
> or any non-standard location.

---

## Step 4 — Verify the connection

In Claude Desktop, click the **+** button in the chat input → **Connectors** → confirm Moodle is toggled on.

Try asking: *"What courses am I enrolled in?"*

---

## Step 5 (optional) — Use with Claude Code

To use Moodle tools in the Claude Code CLI:

```bash
claude mcp add moodle /opt/anaconda3/bin/moodle-mcp \
  -e MOODLE_URL=https://moodle.yourschool.edu \
  -e MOODLE_TOKEN=your_token_here
```

Restart Claude Code after running this.

---

## Building an Obsidian study vault

Once connected, run Claude Code in your terminal and ask:

```
Pull all my Moodle courses and build a linked Obsidian vault at
/Users/yourname/Desktop/Study Notes — one note per topic with [[wikilinks]]
between related concepts, a MOC.md index, and tags for each section.
```

> Use **Claude Code** (not Claude Desktop chat) for this — it can write files
> directly to your filesystem. Claude Desktop chat runs in a sandbox and cannot.

---

## Tested on

| | |
|---|---|
| **School** | City St George's, University of London (`moodle4.city.ac.uk`) |
| **Login** | Microsoft SSO |
| **OS** | macOS (Apple Silicon) |
| **Moodle version** | 4.5.8 |
| **moodle-mcp version** | 0.2.0 |

---

## Credit

All credit for the MCP server goes to [@1alexandrer](https://github.com/1alexandrer) —
[github.com/1alexandrer/moodle-mcp](https://github.com/1alexandrer/moodle-mcp).

This repo just documents the full end-to-end setup and the SSO token workaround
that isn't covered in the original README.
