import AppKit
import CtrlgrpCore

/// The menu bar item: a template glyph with a small menu for the few actions a
/// daemon with no windows otherwise has no surface for (reload, edit the
/// config, quit). NSObject because NSMenuItem's target/action and NSMenuDelegate
/// require one.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let configURL: URL
    private let onReload: () -> Void
    // NSStatusBar does not retain handed-out items; dropping this reference
    // would remove the icon from the bar.
    private var statusItem: NSStatusItem?
    private let editItem = NSMenuItem()

    init(configURL: URL, onReload: @escaping () -> Void) {
        self.configURL = configURL
        self.onReload = onReload
        super.init()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            if let url = Bundle.main.url(forResource: "menubar", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                // Template rendering is what makes the glyph follow the menu
                // bar's light/dark appearance instead of staying black.
                image.isTemplate = true
                image.size = NSSize(width: 18, height: 18)
                button.image = image
            } else {
                button.image = NSImage(systemSymbolName: "3.square", accessibilityDescription: "ctrlgrp")
            }
            button.toolTip = "ctrlgrp"
        }

        let menu = NSMenu()
        menu.delegate = self

        let reload = NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "")
        reload.target = self
        menu.addItem(reload)

        editItem.action = #selector(editConfig)
        editItem.target = self
        menu.addItem(editItem)

        let reveal = NSMenuItem(title: "Reveal in Finder", action: #selector(revealConfig), keyEquivalent: "")
        reveal.target = self
        menu.addItem(reveal)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit ctrlgrp", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quit.target = NSApp
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
        // Logged because this path has no other observable from outside: a
        // created-but-hidden item and code that never ran look identical.
        Log.info("menu bar item installed (button: \(item.button == nil ? "missing" : "present"))")
    }

    /// The edit item's label tells the truth about what the click will do,
    /// re-checked every time the menu opens rather than cached at launch.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let exists = FileManager.default.fileExists(atPath: configURL.path(percentEncoded: false))
        editItem.title = exists ? "Edit Config..." : "Create Config..."
    }

    @objc private func reloadConfig() {
        onReload()
    }

    @objc private func editConfig() {
        createStarterConfigIfMissing()
        NSWorkspace.shared.open(configURL)
    }

    @objc private func revealConfig() {
        createStarterConfigIfMissing()
        NSWorkspace.shared.activateFileViewerSelecting([configURL])
    }

    /// The one sanctioned write to the config file: the daemon itself never
    /// touches it, but an explicit menu click on a machine with no config yet
    /// should produce something to edit rather than a blank editor buffer.
    /// Existing files are never rewritten, so hand edits stay safe.
    private func createStarterConfigIfMissing() {
        let path = configURL.path(percentEncoded: false)
        guard !FileManager.default.fileExists(atPath: path) else { return }
        let starter = """
        {
          "defaults": {
            "1": "com.apple.Safari"
          },
          "hud": { "enabled": true },
          "menubar": { "enabled": true },
          "toggleBack": { "enabled": true }
        }
        """
        do {
            try FileManager.default.createDirectory(
                at: configURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(starter.utf8).write(to: configURL)
            Log.info("created starter config at \(path)")
        } catch {
            Log.warn("could not create starter config: \(error.localizedDescription)")
        }
    }
}
