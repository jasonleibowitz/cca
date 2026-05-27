<div align="center">
    <img src="assets/cca-logo.png" alt="cca logo" width="256" height="256">
    <h1>cca (Claude Code Accounts)</h1>
</div>

> Run multiple Claude Code subscriptions side-by-side, one per terminal — no
> re-login dance.

## Why does this exist?

Most people who use Claude Code at work also pay for a personal Pro/Max
subscription. Today, switching between them means `claude /logout`, browser
login, repeat — every time. Worse, you can only have **one** account active
at a time, so a quick personal experiment derails your work session.

`cca` lets each terminal authenticate as a **different** Anthropic account at
the same time. Open a work terminal — billed to your employer's Max plan.
Open a personal terminal next to it — billed to your own Max. No switching,
no re-login, no contamination.

**Built for:**

- 👩‍💻 Engineers with an employer-provided subscription (Anthropic Teams/Enterprise) **and** a personal Max plan
- 💼 Consultants/contractors juggling multiple client subscriptions
- 🧪 Anyone testing different settings/CLAUDE.md/plugins per profile while keeping the rest shared

## Features

- 🔀 **Parallel subscriptions** — work and personal accounts active in different terminals simultaneously, no re-login.
- 🪶 **Single bash script** — no Go binary, no Node runtime, no npm install. Just `claude`, `python3`, and `curl`.
- 🔒 **Auth isolation that actually works on macOS** — uses `CLAUDE_CODE_OAUTH_TOKEN` (per Anthropic's documented auth precedence) so each shell beats the global Keychain entry.
- 🪞 **Shared customisation** — settings, skills, plugins, hooks, agents are symlinked from your main `~/.claude/`. Edit once, applies everywhere.
- 📊 **`/stats`-style usage view** — 12-month activity heatmap + summary card per profile, built from local session transcripts. No API calls, no external CLI deps.
- 🎨 **Native-feeling CLI** — Claude-orange accents, interactive profile picker, shell wrapper auto-install.
- 🏷️ **Renamable profiles** — including the default "main" profile (label-only rename, dir stays put).
- 🛡️ **Safe by default** — per-profile token files are mode `0600`; profile-marker file means cca only touches the dirs it created.

## Quick Start

### Installation

```bash
git clone https://github.com/jasonleibowitz/cca.git
cd cca
./install.sh
```

`install.sh` symlinks `cca` into `~/.local/bin/`. Make sure that's on your
`$PATH` (most modern shells already include it).

One-time shell integration so `cca switch X` directly affects your current
shell:

```bash
cca init       # interactive install of a tiny shell wrapper
exec $SHELL    # reload so this shell picks it up
```

`cca init` is idempotent — running it again does nothing.

### Switching profiles

```bash
# interactive picker
➜ cca
❯ main (current)
  personal
↑/↓ navigate · enter to select · esc / q to cancel
```

```bash
cca switch personal       # switch this shell to "personal"
cca switch main           # back to main (Keychain auth)
cca active                # which profile is active in this shell?
cca ls                    # list all profiles + their auth state
```

### Add a new profile

```bash
# 1. Create the profile dir (symlinks shared items from ~/.claude/)
cca add personal

# 2. Generate a long-lived OAuth token (opens browser — log in to the
#    target account, then paste the printed token back into cca)
cca login personal

# 3. Switch to it
cca switch personal
```

> **Tip**: to log in as a _different_ Anthropic account, log out of
> claude.ai in your browser first (or open the OAuth URL in a private
> window) — otherwise `claude setup-token` issues a token for whoever's
> currently logged in there.

### View usage

```bash
cca usage                 # heatmap + summary for the active profile
cca usage personal        # for a specific profile
cca usage --all           # every profile, one after another
```

`cca usage` reads your local session transcripts (`projects/*.jsonl`) — no
API calls, works offline, scoped per profile.

## Commands

| Command                    | Description                                                                   |
| -------------------------- | ----------------------------------------------------------------------------- |
| `cca`                      | Interactive profile picker — pick one, switch this shell to it                |
| `cca ls`                   | List profiles; marks the active one, shows where its auth lives               |
| `cca active`               | Print the active profile name                                                 |
| `cca add <name>`           | Create a new profile (mkdir + symlink shared items)                           |
| `cca login <name>`         | Run `claude setup-token` and save the resulting token                         |
| `cca switch <name>`        | Switch the active profile in this shell                                       |
| `cca rename <old> <new>`   | Rename a profile (alias: `cca mv`); supports renaming "main" via a label file |
| `cca rm <name>`            | Delete a profile (confirms first)                                             |
| `cca refresh <name>`       | Re-create symlinks (useful after adding new items in `~/.claude/`)            |
| `cca usage [name]`         | Heatmap + summary for one profile (defaults to active)                        |
| `cca usage --all`          | Same, for every profile                                                       |
| `cca init`                 | Install the shell wrapper into `~/.zshrc` / `~/.bashrc`                       |
| `cca init -y`              | Non-interactive install                                                       |
| `cca init --print`         | Print the wrapper instead of installing                                       |
| `cca init zsh\|bash`       | Force shell type if `$SHELL` is wrong                                         |
| `cca version` / `cca help` | Self-explanatory                                                              |

## How auth isolation works under the hood

[Anthropic's docs](https://code.claude.com/docs/en/iam#credential-management):

> On macOS, credentials are stored in the encrypted macOS Keychain.
> If you've set the `CLAUDE_CONFIG_DIR` environment variable **on Linux or
> Windows**, the `.credentials.json` file lives under that directory instead.

So `CLAUDE_CONFIG_DIR` does **not** isolate auth on macOS — the Keychain
entry is global. The only way to override it per shell is via the documented
auth precedence: `CLAUDE_CODE_OAUTH_TOKEN` (priority #5) beats the Keychain
entry (priority #6).

`cca` uses two env vars together:

| Var                       | What it isolates                                                 |
| ------------------------- | ---------------------------------------------------------------- |
| `CLAUDE_CONFIG_DIR`       | settings, skills, plugins, hooks (via the symlinked profile dir) |
| `CLAUDE_CODE_OAUTH_TOKEN` | **auth**                                                         |

`cca login <name>` runs `claude setup-token` (Anthropic's documented way to
mint a 1-year token) and stores the result at `~/.claude-<name>/.cca-token`
with mode `0600`. `cca switch <name>` exports both vars in your shell.

## What gets shared vs kept per-profile

**Shared** (symlinked from `~/.claude/`):

- `settings.json`, `keybindings.json`, `mcp.json`
- `CLAUDE.md`
- `hooks/`, `agents/`, `commands/`, `skills/`, `plugins/`
- `statusline.sh`, `rules/`
- Any custom dirs you add to `SHARED_ITEMS` in the `cca` script

**Per-profile** (never symlinked):

- `.cca-token` — the OAuth token
- `.credentials.json` (Linux/Windows) — if Claude Code writes one
- `projects/`, `sessions/`, `history.jsonl`, etc. — session state stays
  isolated so `claude --resume` only shows that profile's conversations

## Caveats

- **OAuth tokens last ~1 year.** Re-run `cca login <name>` to refresh.
- **`claude --bare` doesn't read `CLAUDE_CODE_OAUTH_TOKEN`.** For scripted
  bare-mode usage, set `ANTHROPIC_API_KEY` instead.
- **Remote Control** sessions need full-scope OAuth (the long-lived tokens
  are "scoped to inference only" per Anthropic). Use your Keychain account
  for those.
- **Claude Desktop is out of scope.** This tool only manages CLI auth.

## License

MIT — see [LICENSE](LICENSE).
