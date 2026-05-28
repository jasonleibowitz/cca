# Independent Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace symlink-based profile sharing with a section-by-section interactive multi-select picker that copies individual items from `~/.claude/` into new and existing profiles.

**Architecture:** All changes live in the single `cca` bash script. New pure helper functions (`_extract_description`, `_collect_items_for_section`, `_copy_item`, `_multi_picker`) are added above the existing command functions. `cmd_add` is rewritten to loop through sections using these helpers. `cmd_sync` is introduced as the replacement for `cmd_refresh`, which becomes a deprecated alias.

**Tech Stack:** Bash 3.2+ (macOS system bash), no external dependencies, ANSI terminal codes via `tput`.

---

## File Structure

**Single file modified:** `cca`

New functions inserted between the existing helpers and `_picker` (in this order):
- `_extract_description` — extracts ≤60-char description from a file or directory
- `_collect_items_for_section` — emits `name|description` lines for a given section type
- `_copy_item` — copies one named item into a profile directory
- `_multi_picker` — interactive multi-select terminal widget (section-by-section)

Modified functions:
- `cmd_add` — rewritten; no more symlinks, uses section picker
- `cmd_refresh` — becomes a one-liner deprecation shim to `cmd_sync`
- `cmd_help` — updated description paragraph and command table

New function:
- `cmd_sync` — interactive section-by-section copy into an existing profile

Updated constant: `SHARED_ITEMS` → `COPYABLE_ITEMS` (3 occurrences)

---

## Task 1: Rename constant, add `cmd_sync` stub, update dispatch and help

**Files:**
- Modify: `cca`

- [ ] **Step 1: Rename `SHARED_ITEMS` → `COPYABLE_ITEMS` (3 occurrences)**

```bash
# Line ~18: declaration
COPYABLE_ITEMS=(
  CLAUDE.md
  agents
  commands
  hooks
  keybindings.json
  mcp.json
  plugins
  rules
  settings.json
  skills
  statusline.sh
)

# In cmd_add loop (was: for item in "${SHARED_ITEMS[@]}"; do)
for item in "${COPYABLE_ITEMS[@]}"; do

# In cmd_refresh loop (was: for item in "${SHARED_ITEMS[@]}"; do)
for item in "${COPYABLE_ITEMS[@]}"; do
```

- [ ] **Step 2: Add `cmd_sync` stub immediately before `cmd_refresh`**

```bash
cmd_sync() {
  local name="${1:-}"
  [ -n "$name" ] || _die "usage: cca sync <name>"
  local dir
  dir="$(_profile_dir "$name")"
  [ -d "$dir" ] || _die "no such profile: $name (run: cca add $name)"
  _info "cca sync: not yet implemented — coming in next task"
}
```

- [ ] **Step 3: Replace `cmd_refresh` body with deprecation shim**

```bash
cmd_refresh() {
  local name="${1:-}"
  [ -n "$name" ] || _die "usage: cca sync <name>  (refresh has been renamed to sync)"
  _warn "'refresh' is now 'sync'. Running: cca sync $name"
  cmd_sync "$name"
}
```

- [ ] **Step 4: Add `sync` to the `main` dispatch (before `refresh`)**

```bash
    sync)                 cmd_sync "$@" ;;
    refresh)              cmd_refresh "$@" ;;
```

- [ ] **Step 5: Update `cmd_help` — description paragraph**

Replace the paragraph starting "Run multiple Claude Code" with:

```bash
  cat <<EOF
${B}${C}cca${R} ${D}— Claude Code Accounts (${VERSION})${R}

Run multiple Claude Code (CLI) subscriptions side by side. Each profile is
fully independent — copy exactly what you need at creation time, or add
more later with ${C}cca sync${R}.

${D}Scope: Claude Code CLI only — Claude Desktop / Cowork is not managed by cca.${R}
EOF
```

- [ ] **Step 6: Update `cmd_help` — replace `refresh` row with `sync`**

```bash
  # OLD:
  ${C}cca refresh${R} <name>      re-create symlinks for an existing profile
  # NEW:
  ${C}cca sync${R} <name>         copy items from ~/.claude/ into a profile
```

- [ ] **Step 7: Syntax check**

```bash
bash -n cca && echo "OK"
```

Expected: `OK`

- [ ] **Step 8: Smoke test**

```bash
./cca help | grep -c sync        # Expected: 2 (in table + switching section)
./cca help | grep symlink        # Expected: (no output)
./cca sync nonexistent 2>&1      # Expected: "no such profile: nonexistent"
./cca refresh nonexistent 2>&1   # Expected: "'refresh' is now 'sync'" then error
```

- [ ] **Step 9: Commit**

```bash
git add cca
git commit -m "refactor: rename SHARED_ITEMS, stub cmd_sync, update help"
```

---

## Task 2: Add `_extract_description`

**Files:**
- Modify: `cca` — insert before `_picker` (around line 153)

- [ ] **Step 1: Insert `_extract_description`**

```bash
# Extract a short description (≤60 chars) from a file or directory.
# type: command | agent | skill | rule | hook
_extract_description() {
  local type="$1" path="$2" desc=""

  case "$type" in
    command|agent)
      if [ -f "$path" ]; then
        desc=$(grep -m1 '^description:' "$path" 2>/dev/null \
               | sed 's/^description:[[:space:]]*//' \
               | tr -d '"'"'")
        if [ -z "$desc" ]; then
          desc=$(grep -v '^[[:space:]]*$' "$path" 2>/dev/null \
                 | grep -v '^---' | grep -v '^#' \
                 | head -1 | sed 's/^[[:space:]]*//')
        fi
      fi
      ;;
    skill)
      local sf=""
      [ -f "$path/SKILL.md" ] && sf="$path/SKILL.md"
      if [ -z "$sf" ]; then
        sf=$(find "$path" -maxdepth 1 -name "*.md" 2>/dev/null | sort | head -1)
      fi
      if [ -n "$sf" ]; then
        desc=$(grep -m1 '^description:' "$sf" 2>/dev/null \
               | sed 's/^description:[[:space:]]*//' \
               | tr -d '"'"'")
      fi
      ;;
    rule)
      [ -f "$path" ] && desc=$(grep -vm1 '^[[:space:]]*$' "$path" 2>/dev/null \
                               | head -1 | sed 's/^#[[:space:]]*//')
      ;;
    hook)
      if [ -f "$path" ]; then
        desc=$(grep -m1 '^#[^!]' "$path" 2>/dev/null | sed 's/^#[[:space:]]*//')
      elif [ -d "$path" ]; then
        desc="hook directory"
      fi
      ;;
  esac

  printf '%s' "${desc:0:60}"
}
```

- [ ] **Step 2: Syntax check**

```bash
bash -n cca && echo "OK"
```

Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add cca
git commit -m "feat: add _extract_description helper"
```

---

## Task 3: Add `_multi_picker`

**Files:**
- Modify: `cca` — insert after `_extract_description`, before `_picker`

- [ ] **Step 1: Insert `_multi_picker`**

```bash
# Interactive multi-select widget for one section of cca add/sync.
# Usage: _multi_picker <title> <"name|description"> ...
# Stdout: space-separated selected names (empty string if none selected)
# Returns: 0=confirmed  1=skip section (esc/q)  2=abort entirely (Q)
_multi_picker() {
  local title="$1"
  shift
  local items=("$@")
  local n=${#items[@]}

  # Non-TTY or empty section: emit all names silently.
  if [ ! -t 0 ] || [ ! -t 2 ] || [ "$n" -eq 0 ]; then
    local item
    for item in "${items[@]}"; do
      printf '%s ' "${item%%|*}"
    done
    return 0
  fi

  local names=() descs=()
  local item
  for item in "${items[@]}"; do
    names+=("${item%%|*}")
    descs+=("${item#*|}")
  done

  # All items start selected.
  local selected=()
  local i
  for ((i=0; i<n; i++)); do selected+=(1); done

  local sel=0

  # Column width: longest name + 2 spaces gap.
  local max_name=4
  for ((i=0; i<n; i++)); do
    [ ${#names[$i]} -gt $max_name ] && max_name=${#names[$i]}
  done

  tput civis >&2 2>/dev/null || true
  local _mpick_restored=0
  _mpicker_cleanup() {
    [ "$_mpick_restored" -eq 1 ] && return
    _mpick_restored=1
    tput cnorm >&2 2>/dev/null || true
  }
  trap _mpicker_cleanup EXIT INT TERM

  # Reserve lines: title + n items + hint.
  local total=$((n + 2))
  for ((i=0; i<total; i++)); do printf '\n' >&2; done

  local k r1 r2
  while true; do
    tput cuu "$total" >&2

    tput el >&2
    printf '  %s%s%s\n' "$BOLD" "$title" "$RESET" >&2

    for ((i=0; i<n; i++)); do
      tput el >&2
      local chk pad spaces
      if [ "${selected[$i]}" -eq 1 ]; then
        chk="${GREEN}[✓]${RESET}"
      else
        chk="${DIM}[ ]${RESET}"
      fi
      pad=$(( max_name - ${#names[$i]} + 2 ))
      spaces="$(printf '%*s' "$pad" '')"
      if [ "$i" -eq "$sel" ]; then
        printf '%s❯%s %s %s%s%s%s%s%s\n' \
          "$ORANGE" "$RESET" "$chk" \
          "$BOLD" "${names[$i]}" "$RESET" \
          "$spaces" "${DIM}${descs[$i]}${RESET}" "$RESET" >&2
      else
        printf '  %s %s%s%s%s\n' \
          "$chk" "${names[$i]}" \
          "$spaces" "${DIM}${descs[$i]}${RESET}" "$RESET" >&2
      fi
    done

    tput el >&2
    printf '  %s↑/↓ move · space toggle · enter confirm · esc skip · Q quit%s\n' \
      "$DIM" "$RESET" >&2

    r1=''; r2=''
    IFS= read -rsn1 k
    case "$k" in
      $'\033')
        IFS= read -rsn1 -t 1 r1 2>/dev/null || r1=''
        if [ "$r1" = "[" ]; then
          IFS= read -rsn1 -t 1 r2 2>/dev/null || r2=''
          case "$r2" in
            A) sel=$(( (sel + n - 1) % n )) ;;
            B) sel=$(( (sel + 1) % n )) ;;
          esac
        else
          _mpicker_cleanup; trap - EXIT INT TERM; return 1
        fi
        ;;
      ' ')
        if [ "${selected[$sel]}" -eq 1 ]; then
          selected[$sel]=0
        else
          selected[$sel]=1
        fi
        ;;
      '')
        _mpicker_cleanup; trap - EXIT INT TERM
        local out=''
        for ((i=0; i<n; i++)); do
          [ "${selected[$i]}" -eq 1 ] && out="${out}${names[$i]} "
        done
        printf '%s' "${out% }"
        return 0
        ;;
      q)
        _mpicker_cleanup; trap - EXIT INT TERM; return 1
        ;;
      Q)
        _mpicker_cleanup; trap - EXIT INT TERM; return 2
        ;;
    esac
  done
}
```

- [ ] **Step 2: Syntax check**

```bash
bash -n cca && echo "OK"
```

Expected: `OK`

- [ ] **Step 3: Smoke test the picker in isolation**

Create and run a test script:

```bash
cat > /tmp/test_picker.sh << 'EOF'
#!/usr/bin/env bash
BOLD="$(tput bold)"; DIM="$(tput dim)"; GREEN="$(tput setaf 2)"
ORANGE="$(tput setaf 208 2>/dev/null || tput setaf 3)"; RESET="$(tput sgr0)"

# Extract just _multi_picker from cca and eval it
eval "$(sed -n '/^_multi_picker/,/^}/p' /Users/jason.leibowitz/code/cca/cca)"

result="$(_multi_picker "Pick items" \
  "alpha|First item description" \
  "beta|Second item description" \
  "gamma|Third item description")"
rc=$?
printf '\nExit=%d  Selected=[%s]\n' "$rc" "$result"
EOF
chmod +x /tmp/test_picker.sh
/tmp/test_picker.sh
```

Expected behaviours to verify:
- Picker renders with title, three `[✓]` rows, and hint line
- ↑/↓ moves orange `❯` cursor
- Space toggles `[✓]` → `[ ]` and back
- Enter: `Exit=0  Selected=[alpha beta gamma]` (or whichever are checked)
- Esc / `q`: `Exit=1  Selected=[]`
- `Q`: `Exit=2  Selected=[]`

- [ ] **Step 4: Commit**

```bash
git add cca
git commit -m "feat: add _multi_picker interactive multi-select widget"
```

---

## Task 4: Add `_collect_items_for_section` and `_copy_item`

**Files:**
- Modify: `cca` — insert both functions after `_multi_picker`, before `_picker`

- [ ] **Step 1: Insert `_collect_items_for_section`**

```bash
# Emit "name|description" lines for a given section type.
# Prints nothing when the section has no items available.
# Types: config | commands | skills | rules | hooks | agents | plugins
_collect_items_for_section() {
  local type="$1"
  local item desc
  case "$type" in
    config)
      for item in settings.json CLAUDE.md mcp.json keybindings.json statusline.sh; do
        [ -e "$CLAUDE_HOME/$item" ] || continue
        case "$item" in
          settings.json)    desc="Claude Code settings (theme, model, allowed tools)" ;;
          CLAUDE.md)        desc="Project-level instructions for Claude" ;;
          mcp.json)         desc="MCP server configurations" ;;
          keybindings.json) desc="Custom keyboard shortcuts" ;;
          statusline.sh)    desc="Custom status line script" ;;
        esac
        printf '%s|%s\n' "$item" "$desc"
      done
      ;;
    commands)
      [ -d "$CLAUDE_HOME/commands" ] || return 0
      local f
      for f in "$CLAUDE_HOME"/commands/*.md; do
        [ -f "$f" ] || continue
        item="$(basename "$f")"
        desc="$(_extract_description command "$f")"
        printf '%s|%s\n' "$item" "$desc"
      done
      ;;
    skills)
      [ -d "$CLAUDE_HOME/skills" ] || return 0
      local d
      for d in "$CLAUDE_HOME"/skills/*/; do
        [ -d "$d" ] || continue
        item="$(basename "$d")"
        desc="$(_extract_description skill "$d")"
        printf '%s|%s\n' "$item" "$desc"
      done
      ;;
    rules)
      [ -d "$CLAUDE_HOME/rules" ] || return 0
      local f
      for f in "$CLAUDE_HOME"/rules/*; do
        [ -f "$f" ] || continue
        item="$(basename "$f")"
        desc="$(_extract_description rule "$f")"
        printf '%s|%s\n' "$item" "$desc"
      done
      ;;
    hooks)
      [ -d "$CLAUDE_HOME/hooks" ] || return 0
      local entry
      for entry in "$CLAUDE_HOME"/hooks/*; do
        [ -e "$entry" ] || continue
        item="$(basename "$entry")"
        desc="$(_extract_description hook "$entry")"
        printf '%s|%s\n' "$item" "$desc"
      done
      ;;
    agents)
      [ -d "$CLAUDE_HOME/agents" ] || return 0
      local f
      for f in "$CLAUDE_HOME"/agents/*.md; do
        [ -f "$f" ] || continue
        item="$(basename "$f")"
        desc="$(_extract_description agent "$f")"
        printf '%s|%s\n' "$item" "$desc"
      done
      ;;
    plugins)
      [ -d "$CLAUDE_HOME/plugins" ] || return 0
      printf 'plugins|Installed plugins and marketplace configuration\n'
      ;;
  esac
}
```

- [ ] **Step 2: Insert `_copy_item` immediately after `_collect_items_for_section`**

```bash
# Copy one item from ~/.claude/ into a profile directory.
# force=1 uses cp -rf (overwrite); force=0 (default) uses cp without -f.
# Plugins are copied selectively — ephemeral cache/data/repos dirs excluded.
_copy_item() {
  local type="$1" name="$2" dst_dir="$3" force="${4:-0}"
  local src="$CLAUDE_HOME"

  case "$type" in
    config)
      if [ "$force" -eq 1 ]; then cp -f  "$src/$name"          "$dst_dir/$name"
      else                         cp     "$src/$name"          "$dst_dir/$name"; fi
      ;;
    commands)
      mkdir -p "$dst_dir/commands"
      if [ "$force" -eq 1 ]; then cp -f  "$src/commands/$name" "$dst_dir/commands/$name"
      else                         cp     "$src/commands/$name" "$dst_dir/commands/$name"; fi
      ;;
    skills)
      mkdir -p "$dst_dir/skills"
      if [ "$force" -eq 1 ]; then cp -rf "$src/skills/$name"   "$dst_dir/skills/$name"
      else                         cp -r  "$src/skills/$name"   "$dst_dir/skills/$name"; fi
      ;;
    rules)
      mkdir -p "$dst_dir/rules"
      if [ "$force" -eq 1 ]; then cp -f  "$src/rules/$name"    "$dst_dir/rules/$name"
      else                         cp     "$src/rules/$name"    "$dst_dir/rules/$name"; fi
      ;;
    hooks)
      mkdir -p "$dst_dir/hooks"
      if [ "$force" -eq 1 ]; then cp -rf "$src/hooks/$name"    "$dst_dir/hooks/$name"
      else                         cp -r  "$src/hooks/$name"    "$dst_dir/hooks/$name"; fi
      ;;
    agents)
      mkdir -p "$dst_dir/agents"
      if [ "$force" -eq 1 ]; then cp -f  "$src/agents/$name"   "$dst_dir/agents/$name"
      else                         cp     "$src/agents/$name"   "$dst_dir/agents/$name"; fi
      ;;
    plugins)
      mkdir -p "$dst_dir/plugins"
      local pf
      for pf in installed_plugins.json config.json known_marketplaces.json \
                 blocklist.json plugin-catalog-cache.json; do
        [ -f "$src/plugins/$pf" ] || continue
        if [ "$force" -eq 1 ]; then cp -f  "$src/plugins/$pf" "$dst_dir/plugins/$pf"
        else                         cp     "$src/plugins/$pf" "$dst_dir/plugins/$pf"; fi
      done
      if [ -d "$src/plugins/marketplaces" ]; then
        if [ "$force" -eq 1 ]; then cp -rf "$src/plugins/marketplaces" "$dst_dir/plugins/"
        else                         cp -r  "$src/plugins/marketplaces" "$dst_dir/plugins/"; fi
      fi
      ;;
  esac
}
```

- [ ] **Step 3: Syntax check**

```bash
bash -n cca && echo "OK"
```

Expected: `OK`

- [ ] **Step 4: Test `_collect_items_for_section` output**

```bash
bash -c '
  eval "$(sed -n "/^_extract_description/,/^}/p" ./cca)"
  eval "$(sed -n "/^_collect_items_for_section/,/^}/p" ./cca)"
  CLAUDE_HOME="$HOME/.claude"
  echo "--- config ---"
  _collect_items_for_section config
  echo "--- commands ---"
  _collect_items_for_section commands
  echo "--- skills (first 3) ---"
  _collect_items_for_section skills | head -3
  echo "--- plugins ---"
  _collect_items_for_section plugins
'
```

Expected: lines in `name|description` format for each section, e.g.:
```
--- config ---
settings.json|Claude Code settings (theme, model, allowed tools)
CLAUDE.md|Project-level instructions for Claude
mcp.json|MCP server configurations
--- commands ---
create-implementation-plan.md|Export our current plan to a markdown file
dump-context.md|Branch context from one Claude Code agent to be used by others.
...
--- plugins ---
plugins|Installed plugins and marketplace configuration
```

- [ ] **Step 5: Commit**

```bash
git add cca
git commit -m "feat: add _collect_items_for_section and _copy_item helpers"
```

---

## Task 5: Rewrite `cmd_add`

**Files:**
- Modify: `cca` — replace `cmd_add` entirely

- [ ] **Step 1: Replace the entire `cmd_add` function**

```bash
cmd_add() {
  local name="${1:-}"
  [ -n "$name" ] || _die "usage: cca add <name>"
  [ "$name" != "main" ] && [ "$name" != "default" ] || _die "reserved name: $name"
  local dir
  dir="$(_profile_dir "$name")"
  if [ -d "$dir" ]; then
    _die "profile already exists with name '$name' at $dir"
  fi
  [ ! -e "$dir" ] || _die "profile already exists: $dir"

  mkdir -p "$dir"
  : > "$dir/$PROFILE_MARKER_NAME"
  mkdir -p "$dir/projects"

  local sections=(
    "config:Config Files"
    "commands:Commands"
    "skills:Skills"
    "rules:Rules"
    "hooks:Hooks"
    "agents:Agents"
    "plugins:Plugins"
  )
  local total_copied=0
  local section_def type title items_raw selected name_sel rc

  for section_def in "${sections[@]}"; do
    type="${section_def%%:*}"
    title="${section_def#*:}"

    items_raw=()
    while IFS= read -r line; do
      [ -n "$line" ] && items_raw+=("$line")
    done < <(_collect_items_for_section "$type")
    [ ${#items_raw[@]} -eq 0 ] && continue

    selected="$(_multi_picker "$title" "${items_raw[@]}")"
    rc=$?

    if [ "$rc" -eq 2 ]; then
      rm -rf "$dir"
      _info "cca: add aborted — no profile created."
      return 1
    fi
    [ "$rc" -eq 1 ] && continue

    if [ -n "$selected" ]; then
      for name_sel in $selected; do
        _copy_item "$type" "$name_sel" "$dir" 0
        total_copied=$((total_copied + 1))
      done
    fi
  done

  printf 'Created profile %s at %s\n' "$name" "$dir"
  if [ "$total_copied" -eq 0 ]; then
    printf '%s(no items copied — run: cca sync %s)%s\n' "$DIM" "$name" "$RESET"
  fi
  printf 'Next: cca login %s\n' "$name"
}
```

- [ ] **Step 2: Syntax check**

```bash
bash -n cca && echo "OK"
```

Expected: `OK`

- [ ] **Step 3: Create a test profile interactively**

Run in a terminal (not piped):

```bash
./cca add testprofile123
```

Walk through each section: navigate ↑/↓, toggle some items with space, press Enter to proceed. On the final section confirm with Enter.

Then verify no symlinks were created:

```bash
ls -la ~/.claude-testprofile123/
# Every entry should be a regular file or directory — no `->` symlinks.

file ~/.claude-testprofile123/settings.json 2>/dev/null
# Expected: "ASCII text" or similar — a real file, not a symlink.
```

- [ ] **Step 4: Test Q abort mid-way**

```bash
./cca add aborttest
# On the first section, press Q
ls ~/.claude-aborttest 2>&1
# Expected: "No such file or directory" — directory was cleaned up.
```

- [ ] **Step 5: Test non-TTY copy-all (pipe to suppress picker)**

```bash
echo "" | ./cca add silenttest
ls ~/.claude-silenttest/
# Expected: profile created with all existing items copied (no picker appeared).
# No symlinks.
./cca rm silenttest
```

- [ ] **Step 6: Clean up**

```bash
./cca rm testprofile123
```

- [ ] **Step 7: Commit**

```bash
git add cca
git commit -m "feat: rewrite cmd_add with section-by-section copy picker"
```

---

## Task 6: Implement `cmd_sync` fully

**Files:**
- Modify: `cca` — replace the `cmd_sync` stub

- [ ] **Step 1: Replace the `cmd_sync` stub with the full implementation**

```bash
cmd_sync() {
  local name="${1:-}"
  [ -n "$name" ] || _die "usage: cca sync <name>"
  local dir
  dir="$(_profile_dir "$name")"
  [ -d "$dir" ] || _die "no such profile: $name (run: cca add $name)"

  local sections=(
    "config:Config Files"
    "commands:Commands"
    "skills:Skills"
    "rules:Rules"
    "hooks:Hooks"
    "agents:Agents"
    "plugins:Plugins"
  )
  local total_copied=0
  local section_def type title items_raw selected name_sel rc

  for section_def in "${sections[@]}"; do
    type="${section_def%%:*}"
    title="${section_def#*:}"

    items_raw=()
    while IFS= read -r line; do
      [ -n "$line" ] && items_raw+=("$line")
    done < <(_collect_items_for_section "$type")
    [ ${#items_raw[@]} -eq 0 ] && continue

    selected="$(_multi_picker "$title" "${items_raw[@]}")"
    rc=$?

    if [ "$rc" -eq 2 ]; then
      _info "cca: sync cancelled — no changes made."
      return 1
    fi
    [ "$rc" -eq 1 ] && continue

    if [ -n "$selected" ]; then
      for name_sel in $selected; do
        _copy_item "$type" "$name_sel" "$dir" 1
        total_copied=$((total_copied + 1))
      done
    fi
  done

  if [ "$total_copied" -eq 0 ]; then
    printf 'cca: nothing synced.\n'
  else
    printf 'Synced %d item(s) to profile %s\n' "$total_copied" "$name"
  fi
}
```

- [ ] **Step 2: Syntax check**

```bash
bash -n cca && echo "OK"
```

Expected: `OK`

- [ ] **Step 3: Create an empty profile then sync into it**

```bash
# Create profile with nothing copied (Esc through every section)
./cca add synctest
# Press Esc on every section to skip all

ls ~/.claude-synctest/
# Expected: only .cca-profile and projects/ — no settings, commands, etc.

# Now sync specific items
./cca sync synctest
# Select settings.json in Config Files, one command, one skill. Enter through rest.

ls ~/.claude-synctest/
# Expected: settings.json and the chosen commands/ + skills/ entries are present.
# Verify they are real files, not symlinks:
file ~/.claude-synctest/settings.json
```

- [ ] **Step 4: Test overwrite behaviour**

```bash
# Corrupt a file in the profile, then sync to restore it
echo '{"broken": true}' > ~/.claude-synctest/settings.json
./cca sync synctest
# Select settings.json, Enter through all other sections

diff ~/.claude/settings.json ~/.claude-synctest/settings.json
# Expected: no diff — original content restored (cp -rf overwrote it)
```

- [ ] **Step 5: Test `cca refresh` deprecation shim**

```bash
./cca refresh synctest 2>&1 | head -1
# Expected: "cca: 'refresh' is now 'sync'. Running: cca sync synctest"
```

- [ ] **Step 6: Test Q cancels without changes**

```bash
cp ~/.claude-synctest/settings.json /tmp/settings_before.json
./cca sync synctest
# Press Q on the first section

diff /tmp/settings_before.json ~/.claude-synctest/settings.json
# Expected: no diff — nothing was modified
```

- [ ] **Step 7: Clean up**

```bash
./cca rm synctest
rm /tmp/settings_before.json
```

- [ ] **Step 8: Final end-to-end check — verify no symlinks anywhere**

```bash
# Create a real profile, populate it, inspect
echo "" | ./cca add finalcheck
find ~/.claude-finalcheck -maxdepth 3 -type l
# Expected: (no output) — zero symlinks

./cca rm finalcheck
```

- [ ] **Step 9: Commit**

```bash
git add cca
git commit -m "feat: implement cmd_sync (section-by-section copy into existing profile)"
```
