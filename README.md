# ctrlgrp

RTS-style control groups for macOS apps. Bind applications to number keys and
switch with one keystroke.

- `option+N` focuses the app in slot N. Not running, it launches. Already
  frontmost, focus goes back to the app you came from.
- `option+shift+N` binds the frontmost app to slot N for this session.
- `option` plus the backtick key toggles a HUD showing all ten slots.

Slots are the digits 1-9 and 0. Hotkeys are bound to physical keys, so they
behave the same on any keyboard layout. While ctrlgrp runs, those combinations
no longer type their special characters.

## Install

Requires macOS 14 or newer.

```bash
make install
open /Applications/ctrlgrp.app
```

It registers itself as a login item on first launch from `/Applications`. No
Accessibility or Input Monitoring permission is needed.

To remove it: quit the app, then `make uninstall`.

## Configure

Create `~/.config/ctrlgrp/config.json`:

```json
{
  "defaults": {
    "1": "com.google.Chrome",
    "3": "com.googlecode.iterm2"
  },
  "hud": { "enabled": true }
}
```

`defaults` are the bindings restored on every launch. Edits are picked up
immediately, no restart needed, except for `hud.enabled` which is read at
launch.

Bindings made with `option+shift+N` live in memory only and are gone after a
restart, leaving the defaults in place. ctrlgrp never writes this file.

Find an app's bundle id with:

```bash
osascript -e 'id of app "Google Chrome"'
```

## Develop

```bash
make test   # unit tests for the pure logic
make run    # build the bundle and run it in the foreground
```

Logs go to the unified log and to stderr:

```bash
log stream --predicate 'subsystem == "com.pgrekovich.ctrlgrp"' --level info
```
