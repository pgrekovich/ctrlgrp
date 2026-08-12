# ctrlgrp

RTS-style control groups for macOS apps. Bind applications to number keys and
switch with one keystroke.

- `option+N` focuses the app in slot N. Not running, it launches. Already
  frontmost, focus goes back to the app you came from. Going back never starts
  anything: if that app is gone, or there is no previous app yet, you stay put.
- `option+shift+N` binds the frontmost app to slot N for this session, and pops
  the HUD up so you can see the new binding alongside the others.
- `option` plus the backtick key toggles the HUD, a strip in the top right
  listing the slots that are bound. It hides itself after two seconds; pressing
  again hides it at once.

Slots are the digits 1-9 and 0. Hotkeys are bound to physical keys, so they
behave the same on any keyboard layout. While ctrlgrp runs, those combinations
no longer type their special characters.

## Install

Requires macOS 14 or newer. Universal binary, Apple silicon and Intel.

Grab the disk image from the [latest release][releases], drag ctrlgrp into
Applications, and launch it. Builds are signed ad hoc rather than with an Apple
Developer ID, so macOS quarantines the download and will claim the app is
damaged. Clear that once:

```bash
xattr -dr com.apple.quarantine /Applications/ctrlgrp.app
```

Or build it yourself, which skips the quarantine entirely:

```bash
make install
open /Applications/ctrlgrp.app
```

It registers itself as a login item on first launch from `/Applications`. No
Accessibility or Input Monitoring permission is needed.

[releases]: ../../releases/latest

A small menu bar item offers Reload Config, Edit Config, Reveal in Finder, and
Quit. Menu bar managers like Bartender hide new items by default, so if the
icon is missing, look in the manager's hidden section first. The item can be
turned off entirely with `"menubar": { "enabled": false }` in the config, read
at launch.

To remove ctrlgrp, quit it from the menu bar item (or `pkill ctrlgrp` if the
item is disabled), then:

```bash
make uninstall
```

Then remove ctrlgrp from System Settings > General > Login Items. Uninstalling
deletes the app bundle but cannot unregister the login item, since that
registration lives at the OS level and survives the bundle it points to.

## Configure

Create `~/.config/ctrlgrp/config.json`:

```json
{
  "defaults": {
    "1": "com.google.Chrome",
    "3": "com.googlecode.iterm2"
  },
  "hud": { "enabled": true },
  "menubar": { "enabled": true }
}
```

`defaults` are the bindings restored on every launch. Edits are picked up
immediately, no restart needed, except for `hud.enabled` and
`menubar.enabled`, which are read at launch.

Bindings made with `option+shift+N` live in memory only and are gone after a
restart, leaving the defaults in place. ctrlgrp never writes this file, with
one exception: clicking Create Config in the menu bar item when no config
exists yet writes a starter file. An existing config is never touched.

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

## Release

Releases are cut by pushing a tag. The tag is the version: nothing in the repo
needs editing first.

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow runs the tests, builds a universal disk image, checks the binary
really carries both architectures, writes release notes from the commit
subjects since the previous tag, and publishes it all as a GitHub release.

To see what the notes will say before tagging:

```bash
scripts/release-notes.sh v0.1.0
```

To build the same disk image locally:

```bash
make dmg VERSION=0.1.0
```
