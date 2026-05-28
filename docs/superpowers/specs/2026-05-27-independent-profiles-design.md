# Independent Profiles — Design Spec

**Date:** 2026-05-27  
**Status:** Approved (updated: section-by-section picker with per-item descriptions)

## Problem

`cca add` currently symlinks shared items (`settings.json`, `commands`, `skills`, etc.) from `~/.claude/` into each profile dir. Profiles are not truly independent — a change to `~/.claude/settings.json` affects every profile instantly. Users cannot have per-profile settings, custom skills, or different command sets.

## Goal

Profiles are fully isolated directories. When creating a profile, the user selects **individual items within each category** via a section-by-section multi-select CLI. After creation, each profile's files are independent.

---

## 1. Sections

Items are presented one section at a time. Sections with nothing to show (empty dir, file absent) are silently skipped.

| Section | Source | Granularity |
|---------|--------|-------------|
| Config files | individual files at `~/.claude/` | per file |
| Commands | files in `~/.claude/commands/` | per `.md` file |
| Skills | dirs in `~/.claude/skills/` | per subdirectory |
| Rules | files in `~/.claude/rules/` | per file |
| Hooks | entries in `~/.claude/hooks/` | per file or subdir |
| Agents | files in `~/.claude/agents/` | per `.md` file |
| Plugins | `~/.claude/plugins/` | single atomic unit |

**Config file items** (static descriptions):

| Item | Description |
|------|-------------|
| `settings.json` | Claude Code settings (theme, model, allowed tools) |
| `CLAUDE.md` | Project-level instructions for Claude |
| `mcp.json` | MCP server configurations |
| `keybindings.json` | Custom keyboard shortcuts |
| `statusline.sh` | Custom status line script |

---

## 2. Description Extraction

For dynamic sections (commands, skills, rules, hooks, agents), descriptions are extracted at runtime:

- **Commands** (`.md` files): YAML frontmatter `description:` field between `---` markers; fallback to first non-empty non-`#` line, truncated to 60 chars.
- **Skills** (dirs): `description:` field from `SKILL.md` (or first `.md` found in the dir); fallback to directory name only.
- **Rules** (files): First non-empty line of the file, truncated to 60 chars.
- **Hooks** (files/dirs): First `# …` comment line, stripped of `#` and leading whitespace, truncated to 60 chars.
- **Agents** (`.md` files): YAML frontmatter `description:` field, truncated to 60 chars.
- **Plugins**: Static — "Installed plugins and marketplace configuration".

---

## 3. `_multi_picker` Function

**Signature:**
```
_multi_picker <section-title> <"name|description"> ...
```

Each argument after the title is a `name|description` pair (pipe-separated). The function renders the section, handles user input, and writes selected names (space-separated) to stdout.

**Return code:** 0 on Enter confirm, 1 on Esc/q (skip section), 2 on `Q` (abort entire add).

**Terminal rendering:**
```
── Commands ──────────────────────────────────────────
❯ [✓] create-pr          Create a GitHub pull request
  [✓] code-review        Review code for bugs and issues
  [ ] dump-context       Branch context from one Claude agent to another
  [✓] implement-plan     Execute a plan from a markdown file

  ↑/↓ move · space toggle · enter next · esc skip section · Q quit
```

- Cursor row: orange `❯`, bold name
- Description: dim, right of name, aligned to a fixed column
- Hint line always at the bottom of the widget

**Key bindings:**

| Key | Action |
|-----|--------|
| ↑ / ↓ | Move cursor |
| Space | Toggle selected/deselected |
| Enter | Emit selected names on stdout, return 0 |
| Esc / q | Skip this section, return 1 (nothing emitted) |
| Q (uppercase) | Abort entire `cca add`, return 2 |

**Initial state:** All items start selected `[✓]`.

**Non-TTY behavior:** Skip UI, emit all names (silent copy-all for scripts/pipes).

---

## 4. `cmd_add` Flow

1. Validate name, create dir, write marker, create `projects/`.
2. For each section in order:
   a. Collect available items (files/dirs that exist in `~/.claude/`).
   b. Extract descriptions.
   c. Call `_multi_picker "<Section>" <items>`.
   d. Return 0 → copy selected items into profile dir (see §5).
   e. Return 1 → skip section silently.
   f. Return 2 → clean up profile dir and abort with message.
3. After all sections: print "Created profile `<name>` at `<dir>`" and "Next: cca login `<name>`".
4. If zero items were copied across all sections: note "Profile created empty — run `cca sync <name>` to add items later."

---

## 5. Copy Operations

Items are always **copied**, never symlinked. Parent directories are created as needed.

| Category | Copy operation |
|----------|----------------|
| Config files (`settings.json` etc.) | `cp "$CLAUDE_HOME/$item" "$dir/$item"` |
| Commands (`.md` file) | `mkdir -p "$dir/commands"; cp "$CLAUDE_HOME/commands/$item" "$dir/commands/"` |
| Skills (subdir) | `mkdir -p "$dir/skills"; cp -r "$CLAUDE_HOME/skills/$item" "$dir/skills/"` |
| Rules (file) | `mkdir -p "$dir/rules"; cp "$CLAUDE_HOME/rules/$item" "$dir/rules/"` |
| Hooks (file or subdir) | `mkdir -p "$dir/hooks"; cp -r "$CLAUDE_HOME/hooks/$item" "$dir/hooks/"` |
| Agents (`.md` file) | `mkdir -p "$dir/agents"; cp "$CLAUDE_HOME/agents/$item" "$dir/agents/"` |
| Plugins (atomic) | Copy key files only — exclude `cache/`, `data/`, `repos/` (ephemeral) |

**Plugins copy** uses explicit file list to avoid copying the large cache:
```bash
for f in installed_plugins.json config.json known_marketplaces.json blocklist.json; do
  [ -f "$CLAUDE_HOME/plugins/$f" ] && cp "$CLAUDE_HOME/plugins/$f" "$dir/plugins/"
done
cp -r "$CLAUDE_HOME/plugins/marketplaces" "$dir/plugins/" 2>/dev/null || true
```

---

## 6. `cmd_sync` (replaces `cmd_refresh`)

`cca sync <name>` runs the same section-by-section picker against an **existing** profile and copies selected items in, overwriting what's already there (`cp -rf`).

- Return 2 (Q) from any section → print "Sync cancelled — no changes made." and exit.
- Esc on a section → skip that section, continue to next.

**Backward compat:** `cca refresh <name>` dispatches to `cmd_sync` with a deprecation note:
```
cca: 'refresh' is now 'sync'. Running cca sync <name>...
```

---

## 7. Renamed Constant

`SHARED_ITEMS` → `COPYABLE_ITEMS`. The array is now used only as a fallback reference for non-TTY copy-all mode; section discovery is done dynamically at runtime.

---

## 8. Help Text Changes

**Description paragraph:**
```
Run multiple Claude Code (CLI) subscriptions side by side. Each profile is
fully independent — copy exactly what you need at creation time, or add
more later with `cca sync`.
```

**Command table:** Replace `cca refresh <name>` with:
```
cca sync <name>        copy items from ~/.claude/ into an existing profile
```

---

## 9. Non-Goals

- Syncing changes back from a profile to `~/.claude/`.
- Diffing or merging per-profile files against `~/.claude/`.
- Changing auth isolation.

---

## 10. Testing Checklist

- `cca add <name>`: all sections appear in order; only non-empty sections shown; space toggles; Enter advances; Esc skips section; Q aborts and removes partial profile dir.
- Selected items are copied (not symlinked) into the correct subdirectory.
- Plugins copy excludes `cache/`, `data/`, `repos/`.
- `cca sync <name>`: overwrites selected items.
- `cca refresh <name>`: prints deprecation note, delegates to sync.
- Non-TTY: copies all items silently, no picker shown.
- Profile created with zero items: `cca sync` correctly populates it later.
