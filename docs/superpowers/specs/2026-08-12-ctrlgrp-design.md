# ctrlgrp - Design

RTS-style control groups for macOS apps. A tiny native daemon that binds
applications to number keys: `option+N` focuses (or launches) the bound app,
`option+shift+N` binds the frontmost app to slot N at runtime.

Date: 2026-08-12. Status: approved by Pavel, pre-implementation.

## Goal

Switch between apps with one keystroke, RTS control-group style, with dynamic
runtime rebinding - the feature missing from Karabiner/Raycast static configs.

Priorities: maximum performance (instant reaction, negligible resident
footprint), zero external dependencies, zero macOS permission prompts.

## Non-goals

- Window-level binding (two Chrome windows on different slots). App-level only.
- Any settings UI, menu bar item, dock icon, animations.
- Multi-user / multi-machine sync, CLI management commands.

## Behavior

Slots: `1..9` and `0` - ten slots, mapped to physical digit keys.

| Input | Action |
|---|---|
| `option+N` | Activate app bound to slot N. Not running → launch it. Already frontmost → activate previous frontmost app (toggle-back). Slot empty → nothing. |
| `option+shift+N` | Bind current frontmost app to slot N in the session overlay. Overwrites silently. |
| HUD hotkey (default `option+backtick`) | Toggle the HUD panel. |

### Two-layer binding model

- **Defaults**: `slot → bundle id` map in the config file, edited by hand only.
  Survives reboots; this is the "after reboot everything is auto-bound" set.
- **Session overlay**: in-memory map written by `option+shift+N`. Lives until
  the daemon exits (reboot, restart). Never persisted.
- Effective binding = overlay value if present, else default.
- Unbinding a default = edit the config. Resetting an overlay = restart daemon
  (or rebind over it).
- The daemon never writes the config file.

### Config

Single JSON file at `~/.config/ctrlgrp/config.json`, read on start and watched
for changes (reload on the fly; overlay is preserved across reloads). Example:

```json
{
  "defaults": {
    "1": "com.google.Chrome",
    "3": "com.googlecode.iterm2"
  },
  "hud": {
    "enabled": true
  }
}
```

Missing file → daemon runs with empty defaults and logs a hint with the path.
Malformed JSON → log to stderr, keep the last valid config.

v1 keeps hotkey modifiers hardcoded (option / option+shift / option+backtick).
A `hotkeys` config section can be added later if a real conflict shows up.

### HUD

Non-activating borderless `NSPanel`, a single row of 10 cells: digit + app icon
(via `NSWorkspace`, from the effective binding's bundle id). Empty slot →
dimmed digit; bound but app missing on disk → digit + "?". No animations.
Toggled by hotkey; `hud.enabled=false` unregisters the hotkey and never creates
the panel.

## Architecture

SwiftPM executable package (no Xcode required, builds with CLT; Swift 6.3 /
macOS 26 host). No third-party dependencies. Frameworks: AppKit, Carbon
(hotkeys only).

Components (one file each):

- **`Config`** - Codable model; load, validate, file watcher
  (`DispatchSource.makeFileSystemObjectSource`). Exposes
  `defaults: [Slot: BundleID]` and settings. Pure logic, unit-testable.
- **`Bindings`** - the two-layer model: holds defaults (from Config) + overlay;
  `effective(slot)`, `bind(slot, bundleID)`. Pure logic, unit-testable.
- **`HotkeyManager`** - registers Carbon hotkeys via `RegisterEventHotKey`
  using physical key codes (`kVK_ANSI_1`…`kVK_ANSI_0`, backtick), so behavior
  is identical on EN/RU/PL layouts. Registered hotkeys consume the keystroke:
  no "™/¡" leaking into text fields, and (accepted trade-off) those
  option+digit characters can't be typed while the daemon runs. Dispatches
  slot/bind/hud callbacks.
- **`Switcher`** - activation logic. Tracks previous frontmost app via
  `NSWorkspace.didActivateApplicationNotification`. On activate: find
  `NSRunningApplication` by bundle id → `activate()`; not running →
  `NSWorkspace.openApplication(at:)` with
  `urlForApplication(withBundleIdentifier:)`; app not on disk → log, skip;
  target already frontmost → activate previous app. NSWorkspace access behind
  a protocol so the toggle/launch decision tree is unit-testable.
- **`HUD`** - the panel described above.
- **`main.swift`** - wiring; `NSApplication` with activation policy
  `.accessory` (no dock icon, no menu bar).

Data flow: hotkey → HotkeyManager callback → Bindings lookup → Switcher action.
Bind flow: hotkey → frontmost bundle id → Bindings overlay. No polling
anywhere; the daemon is fully event-driven.

## Packaging, autostart & install

The build artifact is a proper app bundle, `ctrlgrp.app`, so distribution is
"drag into /Applications". SwiftPM produces the binary; the `Makefile`
assembles the bundle:

- `make build` - `swift build -c release`.
- `make app` - assemble `ctrlgrp.app` (binary into `Contents/MacOS/`,
  generated `Info.plist` with `LSUIElement=true` + bundle id
  `com.pgrekovich.ctrlgrp`, optional icns) and ad-hoc sign (`codesign -s -`).
- `make install` - copy the bundle to `/Applications`.

Autostart via `SMAppService.mainApp.register()` on first launch (standard
login item, visible in System Settings). Logs via `os_log` (Console.app).

Distribution levels, by intent:
- Personal use: ad-hoc signing is enough. This is v1.
- Public download (dmg/zip without Gatekeeper warnings): requires Apple
  Developer ID ($99/yr) + notarization - a signing/CI step, no code changes.
- App Store: possible (all APIs used are sandbox-compatible; rcmd ships this
  way), but out of scope for v1.

## Permissions

None. App-level activation (`NSRunningApplication.activate`) and Carbon hotkey
registration require neither Accessibility nor Input Monitoring. First-run
experience is: install, it works.

## Error handling summary

- Empty slot pressed → no-op.
- Bound app deleted from disk → log, no-op (HUD shows "?").
- Config missing/broken → empty/last-valid config + stderr log.
- Hotkey registration failure (conflict with another app's global hotkey) →
  log which slot failed, continue with the rest.

## Testing

- Unit tests (XCTest, `swift test`): Config parsing (valid, missing, broken,
  unknown keys), Bindings two-layer semantics (overlay wins, reload preserves
  overlay), Switcher decision tree via mocked workspace protocol
  (running/not-running/frontmost/missing-on-disk).
- Manual E2E checklist for what can't be automated headlessly: hotkeys fire,
  keystroke consumed, toggle-back, launch, HUD rendering, config hot-reload,
  LaunchAgent autostart after reboot.

## Known risks

- **macOS 14+ cooperative activation**: activating another app from a
  background daemon may need care (`activate()` behavior changed). All app
  switchers solve this; verify first, at project start, since it is the core.
- Carbon hotkey API is old but not deprecated-for-removal; it remains the only
  permission-free global hotkey mechanism. If it ever dies, fallback is
  CGEventTap + Input Monitoring permission (explicit non-goal for v1).
