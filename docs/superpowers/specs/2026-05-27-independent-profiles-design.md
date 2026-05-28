# Independent Profiles — Design Spec

**Date:** 2026-05-27  
**Status:** Approved

## Problem

`cca add` currently symlinks shared items (`settings.json`, `commands`, `skills`, etc.) from `~/.claude/` into each profile dir. This means profiles are not truly independent — a change to `~/.claude/settings.json` affects every profile instantly. Users cannot have per-profile settings, custom skills, or different command sets.

## Goal

Profiles are fully isolated directories. When creating a profile, the user selects which items to **copy** from `~/.claude/` via an interactive multi-select CLI. After creation, each profile's files are independent.

---

## 1. Renamed Constant

`SHARED_ITEMS` → `COPYABLE_ITEMS`. The array contents stay the same; the name reflects that items are copied, not linked.

---

## 2. `_multi_picker` Function

**Signature:**
```
_multi_picker <title> <item1> [item2 ...]
```

**Stdout:** space-separated list of selected item names (empty if nothing selected).  
**Return code:** 0 on Enter confirm, 1 on Esc/q cancel.

**Terminal rendering (one row per item):**
```
Copy to personal:
❯ [✓] settings.json          ← cursor row, orange ❯, bold
  [✓] commands
  [ ] skills
  [✓] hooks
  ↑/↓ move · space toggle · enter confirm · esc/q cancel
```

**Key bindings:**
| Key | Action |
|-----|--------|
| ↑ / ↓ | Move cursor |
| Space | Toggle selected/deselected |
| Enter | Emit selected items, return 0 |
| Esc / q | Return 1 (cancel) |

**Non-TTY behavior:** When stdin or stderr is not a TTY, skip the UI and print all items on stdout (copy-all silent mode for scripts/pipes).

**Initial state:** All items start selected (`[✓]`).

**Empty confirm:** If the user deselects everything and presses Enter, that is valid — the profile is created empty. A note is printed: `Profile created with no items copied. Run 'cca sync <name>' to add items later.`

---

## 3. `cmd_add` Changes

**Steps:**
1. Validate name, create dir, write marker file, create `projects/` as before.
2. Collect `existing_items`: filter `COPYABLE_ITEMS` to those that exist in `~/.claude/`.
3. If `existing_items` is empty: skip picker, print "Nothing to copy from ~/.claude/ — profile created empty."
4. Otherwise: call `_multi_picker "Copy to <name>:" "${existing_items[@]}"`.
   - On confirm (return 0): `cp -r "$CLAUDE_HOME/$item" "$dir/$item"` for each selected item.
   - On cancel (return 1): copy nothing, print "Picker cancelled — profile created empty. Run 'cca sync <name>' to add items later."
5. Print "Created profile <name> at <dir>" and "Next: cca login <name>" as before.

**Removed:** the symlink loop (`ln -s`).

---

## 4. `cmd_sync` (replaces `cmd_refresh`)

`cca sync <name>` — interactive multi-select to copy items from `~/.claude/` into an **existing** profile, overwriting any already-present items.

**Steps:**
1. Validate profile exists.
2. Collect `existing_items` from `~/.claude/` (same filter as `cmd_add`).
3. Call `_multi_picker "Sync to <name>:" "${existing_items[@]}"`.
4. On confirm: `cp -rf "$CLAUDE_HOME/$item" "$dir/$item"` for each selected item.
5. On cancel: print "Cancelled — no changes made."

**Backward compat:** `cca refresh <name>` dispatches to `cmd_sync` with a deprecation note printed to stderr:
```
cca: 'refresh' is now 'sync'. Running cca sync <name>...
```

---

## 5. Help Text Changes

**Description paragraph** (remove symlink reference, add independence note):
```
Run multiple Claude Code (CLI) subscriptions side by side. Each profile is
fully independent — copy what you need at creation time, or add more later
with `cca sync`.
```

**Command table:** Replace `cca refresh <name>` row with:
```
cca sync <name>        copy items from ~/.claude/ into an existing profile
```

---

## 6. Non-Goals

- Syncing changes back from a profile to `~/.claude/` (profiles are one-way copies).
- Diffing or merging per-profile files against `~/.claude/`.
- Changing auth isolation — that's untouched.

---

## 7. Testing Considerations

The script is pure bash with no test harness. Manual verification:
- `cca add <name>`: picker appears, space toggles, Enter copies only selected items, no symlinks in the resulting dir.
- `cca sync <name>`: overwrites selected items in existing profile.
- `cca refresh <name>`: deprecation message + delegates to sync.
- Non-TTY (`echo "" | cca add <name>`): copies all existing items silently.
- Profile created with zero items: subsequent `cca sync` correctly populates it.
