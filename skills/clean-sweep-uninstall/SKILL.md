---
name: clean-sweep-uninstall
description: >-
  Completely remove a macOS application including all auxiliary files (caches,
  preferences, application support, containers, launch agents, and dotfiles).
  Use when the user asks to "completely remove", "uninstall", "clean sweep", or
  "fully delete" a Mac app and its leftover files.
license: MIT
compatibility: pi, claude-code, any agent-skills-compatible harness
requires: macOS
metadata:
  author: Milo Z.
  version: "1.0.0"
  status: stable
---
# Clean sweep: uninstall a macOS app and all auxiliary files

Goal: remove an app *and everything it left behind*, verifying nothing remains.
macOS apps scatter files across `~/Library`, sometimes `~/`, and occasionally
system `/Library`. A "complete" removal must sweep all of them by **bundle
identifier**, not just app name.

This is destructive and hard to reverse. Proceed only when the user explicitly
asks for a complete/full removal. Investigate before deleting — never `rm -rf`
a path you haven't inspected.

## 1. Locate the app and its bundle identifier

```bash
ls -la /Applications "$HOME/Applications" 2>/dev/null | grep -i <name>
/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" \
  "/Applications/<App>.app/Contents/Info.plist"
```

The bundle id (e.g. `com.vendor.appname`) is the key to finding auxiliary files.
Note it — most Library files are named after it, not the app.

## 2. Determine the install method

Prefer the package manager's own uninstall — it's cleaner and reversible-ish.

```bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
brew list --cask 2>/dev/null | grep -i <name>   # Homebrew cask?
```

- **Homebrew cask** → use `brew uninstall --cask --zap <name>` (step 4). The
  `--zap` runs the cask's cleanup stanza, removing most auxiliary files for you.
- **Mac App Store / manual** → trash the `.app` yourself, then sweep manually.

## 3. Quit the app if running

```bash
osascript -e 'quit app "<App>"'; sleep 2
pgrep -il <name> && { pkill -x <name>; sleep 1; }
pgrep -il <name> || echo "app quit"
```

Deleting files while the app runs leaves locks and half-written state.

## 4. Uninstall

```bash
# Homebrew cask (preferred):
brew uninstall --cask --zap <name>

# Manual install:
rm -rf "/Applications/<App>.app"
```

## 5. Sweep auxiliary locations by bundle id

Even after `--zap`, some files survive (dotfiles, crash reporters, third-party
caches). Sweep every location. Replace `<bundleid>`, `<name>`, `<App>`:

```bash
# Broad discovery first — see what's actually there before deleting
find "$HOME/Library" -maxdepth 4 \
  \( -iname "*<name>*" -o -iname "*<bundleid>*" \) 2>/dev/null
```

Common locations (check each; delete what matches):

| Location | Typical name |
|---|---|
| `~/Library/Application Support/` | `<bundleid>` |
| `~/Library/Caches/` | `<bundleid>` |
| `~/Library/HTTPStorages/` | `<bundleid>` (+ `.binarycookies`) |
| `~/Library/Preferences/` | `<bundleid>.plist` |
| `~/Library/Saved Application State/` | `<bundleid>.savedState` |
| `~/Library/Containers/` | `<bundleid>` |
| `~/Library/Group Containers/` | `<team>.<bundleid>` |
| `~/Library/Logs/` | `<App>` or `<bundleid>` |
| `~/Library/WebKit/` | `<bundleid>` |
| `~/Library/Caches/SentryCrash/` | `<App>` (crash reporter) |
| `~/Library/LaunchAgents/` | `<bundleid>.plist` |
| `/Library/LaunchAgents`, `/Library/LaunchDaemons` | system-wide (needs sudo) |
| `~/.<name>` | app config dotfile in home |
| `~/Library/Caches/Homebrew/{Cask,downloads}/` | leftover installer dmgs |

Do NOT let the app-name grep swallow similarly-named unrelated apps
(e.g. `supacode` vs `supabase`) — filter with `grep -iv <other>` when in doubt.

## 6. Verify

```bash
find "$HOME/Library" "$HOME/.<name>" /Applications -maxdepth 4 \
  -iname "*<name>*" 2>/dev/null | grep -iv <unrelated> \
  || echo "clean — no files remain"
brew list --cask 2>/dev/null | grep -i <name> || echo "cask no longer tracked"
```

## Related cleanup, if any

- **Claude Code skills** the app shipped live at `~/.claude/skills/<skill>/` —
  remove the directory if the app is gone.
- **Managed hooks** in `~/.claude/settings.json` — some apps inject hooks tagged
  with a trailing comment (e.g. `# <app>-managed-hook`). Point these out to the
  user, but only remove them if they confirm — hooks can be shared or intentional.
