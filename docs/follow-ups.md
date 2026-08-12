# Follow-ups

Deliberately deferred during the initial build. Nothing here blocks using the
app; all of it was reviewed and triaged as safe to leave open.

## Settled

**Toggle-back no longer relaunches an app you quit** (decided 2026-08-12). A
direct call still launches, because asking for a slot means you want that app.
Going back never launches, because it is navigation, not a request to start
something. `Situation` carries `isPreviousRunning` and `decideSwitch` returns
`.activateIfRunning` for the toggle-back path, which refuses to launch even if
the app disappears between the decision and the action.

## Distribution

Releases are signed ad hoc, so anyone downloading the disk image has to clear
the quarantine flag by hand. Removing that step needs an Apple Developer
Program membership: sign with a Developer ID certificate and notarize in the
release workflow. That is signing configuration and four repository secrets,
not a code change, and the app itself needs nothing new for it.

## Testability

- `ConfigWatcher` lives in the executable target, so it has no unit tests. Moving
  it into `CtrlgrpCore` with an injected warning sink and an injected debounce
  interval would let a temp-directory test pin which edit methods deliver a
  callback. A test like that would have caught the in-place-edit gap that instead
  escaped to manual testing. Worth doing next time the file is touched.
- `HotkeyManager.handle(id:)` decodes a hotkey id into a trigger with pure
  arithmetic. Extracting it would give the hotkey dispatch path, currently
  verified only by hand, its first mechanical test.

## Small things

- `AppActivator` emits the same "no application installed" warning from two
  different causes, so the log does not say which path fired.
- `AppActivator.situation` does a Launch Services lookup on every keypress even
  when the target is already running and the result goes unused.
- `Config.load` treats a present-but-unreadable file (permissions, IO error) as
  a missing file, so the warning reads "no config at ..." and defaults get
  cleared. Distinguishing the two needs a third outcome case.
- `HotkeyManager.unregisterAll` does not call `RemoveEventHandler`. Harmless
  with one instance living for the whole process, a leak if that ever changes.
- The bundle id is written out in three places: the Makefile, the `Log`
  subsystem, and `Info.plist.in`.
- `ConfigWatcher` watches the config's whole directory, and kqueue cannot say
  which entry changed, so an editor's temp or backup file can trigger a
  redundant reload. Reloads are idempotent, so this is only log noise.
- The HUD reloads every icon from Launch Services on each toggle. Fine at ten
  slots; caching would matter only if the HUD grew.
