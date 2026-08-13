<img src="design/logo.png" align="right" width="140" height="140" alt="ctrlgrp icon: the digit 3 inside selection brackets">

# ctrlgrp

**Control groups for macOS.** Bind apps to number keys and switch with one
keystroke, the way RTS players have always done it.

[![CI](https://github.com/pgrekovich/ctrlgrp/actions/workflows/ci.yml/badge.svg)](https://github.com/pgrekovich/ctrlgrp/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/pgrekovich/ctrlgrp)](https://github.com/pgrekovich/ctrlgrp/releases/latest)

* **Instant.** Event-driven from the keypress down, no polling anywhere, a few
  megabytes resident.
* **Zero permissions.** No Accessibility, no Input Monitoring, no prompts at
  all. Install it and it works.
* **Dynamic.** Rebind on the fly with a hotkey, the thing static tools like
  Karabiner and Raycast keybindings cannot do.
* **Layout-proof.** Hotkeys bind to physical keys, so they behave identically
  on English, Russian, Polish, or any other layout.
* **Two layers.** Hand-written defaults survive reboots; hotkey bindings live
  until the session ends, like control groups in a match.
* **Tiny.** One universal binary, zero dependencies, open source.

## Hotkeys

| Keys | Action |
| --- | --- |
| `⌥` `1`&hellip;`9` `0` | Focus the app in that slot. Not running? It launches. Already frontmost? Focus returns to the app you came from (never relaunching one you quit). |
| `⌥` `⇧` `1`&hellip;`9` `0` | Bind the frontmost app to that slot for this session. |
| `⌥` `` ` `` | Toggle the HUD. |

While ctrlgrp runs, these combinations no longer type their special
characters. Everything else about your keyboard is untouched.

## HUD

A strip in the top right corner shows what is bound where. It pops up when you
bind a slot, hides itself after two seconds, and never steals focus.

<img src="design/hud.png" width="290" alt="The HUD: a compact dark strip listing bound slots as digit plus app icon">

## Install

Requires macOS 14 or newer. Universal binary, Apple silicon and Intel.

Grab the disk image from the [latest release][releases] and drag ctrlgrp into
Applications. Builds are signed ad hoc rather than with an Apple Developer ID,
so macOS quarantines the download and will claim the app is damaged. Clear
that once:

```bash
xattr -dr com.apple.quarantine /Applications/ctrlgrp.app
```

Or build from source, which skips the quarantine entirely:

```bash
git clone https://github.com/pgrekovich/ctrlgrp.git
cd ctrlgrp && make install
open /Applications/ctrlgrp.app
```

On first launch from `/Applications` it registers itself as a login item.
That is the entire setup.

[releases]: ../../releases/latest

## Configure

Defaults live in `~/.config/ctrlgrp/config.json` (the menu bar item's
Create Config makes a starter file if you have none):

```json
{
  "defaults": {
    "1": "com.brave.Browser",
    "3": "com.mitchellh.ghostty"
  },
  "hud": { "enabled": true },
  "menubar": { "enabled": true }
}
```

* Edits are picked up immediately, no restart needed. The two `enabled`
  switches are the exception: they are read at launch.
* Bindings made with `⌥⇧N` live in memory only and vanish on restart, leaving
  the defaults in place. ctrlgrp never rewrites this file.
* Find an app's bundle id with:

```bash
osascript -e 'id of app "Google Chrome"'
```

## Menu bar

A small template icon with Reload Config, Edit Config, Reveal in Finder, and
Quit. Menu bar managers like Bartender hide new items by default, so if you do
not see it, check the manager's hidden section. Disable it entirely with
`"menubar": { "enabled": false }`.

To uninstall: quit ctrlgrp from that menu (or `pkill ctrlgrp`), run
`make uninstall`, and remove ctrlgrp from System Settings > General > Login
Items. The login item registration lives at the OS level and survives the
bundle it points to, so that last step is manual.

## Development

```bash
make test   # unit tests for the pure logic
make run    # build the bundle and run it in the foreground
```

Logs go to the unified log and to stderr:

```bash
log stream --predicate 'subsystem == "com.pgrekovich.ctrlgrp"' --level info
```

Releases are cut by pushing a tag; the tag is the version. CI builds a
universal disk image, generates release notes from the commit subjects since
the previous tag, and publishes the GitHub release:

```bash
git tag v0.3.0 && git push origin v0.3.0
```

Preview the notes first with `scripts/release-notes.sh v0.3.0`, or build the
same disk image locally with `make dmg VERSION=0.3.0`.
