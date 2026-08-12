import AppKit
import CtrlgrpCore

/// A borderless, non-activating overlay listing the current slots. It must
/// never take focus: the point is to look at it while another app stays
/// frontmost.
@MainActor
final class HUDPanel {
    // Built once and kept for the process lifetime. NSApplication retains
    // every NSPanel in its window list once created, ordered in or out,
    // regardless of external references, so a fresh panel per toggle would
    // never be released: in a daemon that runs for weeks that is an
    // unbounded leak of the whole view tree, not a one-off allocation.
    private var panel: NSPanel?

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle(bindings: [Slot: String]) {
        if isVisible {
            hide()
        } else {
            show(bindings: bindings)
        }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    /// Rebuilds the visible content in place. A no-op while hidden: there is
    /// nothing on screen to refresh, and showing the panel here would react
    /// to a bind the user did not ask the HUD to appear for.
    func refresh(bindings: [Slot: String]) {
        guard let panel, panel.isVisible else { return }
        apply(bindings: bindings, to: panel)
        panel.orderFrontRegardless()
        panel.invalidateShadow()
    }

    private func show(bindings: [Slot: String]) {
        let panel = panel ?? makePanel()
        self.panel = panel
        apply(bindings: bindings, to: panel)
        // orderFrontRegardless, not makeKeyAndOrderFront: showing the HUD must
        // not change which app is frontmost.
        panel.orderFrontRegardless()
        panel.invalidateShadow()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        return panel
    }

    private func apply(bindings: [Slot: String], to panel: NSPanel) {
        let content = makeContentView(bindings: bindings)
        // Measure BEFORE handing the view over. Assigning contentView resizes
        // that view to the window's current content rect, which is zero on a
        // freshly built panel, so measuring afterwards yields zero and the
        // panel ends up an invisible 0x0 window.
        let size = content.frame.size
        if size.width == 0 || size.height == 0 {
            Log.warn("hud content measured \(size), the panel would be invisible")
        }
        panel.setFrame(centeredFrame(size: size), display: false)
        panel.contentView = content
    }

    private func centeredFrame(size: NSSize) -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else {
            return NSRect(origin: .zero, size: size)
        }
        return NSRect(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func makeContentView(bindings: [Slot: String]) -> NSView {
        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 16
        // cornerRadius alone does not clip a visual effect view's backdrop
        // sublayer; masksToBounds is what actually rounds the rendered material.
        background.layer?.masksToBounds = true

        let row = NSStackView(views: Slot.all.map { cell(for: $0, bundleID: bindings[$0]) })
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        background.addSubview(row)
        let padding: CGFloat = 18
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: padding),
            row.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -padding),
            row.topAnchor.constraint(equalTo: background.topAnchor, constant: padding),
            row.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -padding),
        ])
        // The caller reads this view's frame right after this call returns to
        // size the panel, so it must already be laid out and sized here
        // rather than left for a layout pass that may never happen.
        background.layoutSubtreeIfNeeded()
        background.frame = NSRect(origin: .zero, size: background.fittingSize)
        return background
    }

    private func cell(for slot: Slot, bundleID: String?) -> NSView {
        let iconView = NSImageView()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),
        ])

        let label = NSTextField(labelWithString: slot.description)
        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        label.alignment = .center
        label.textColor = bundleID == nil ? .tertiaryLabelColor : .labelColor

        if let bundleID {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                iconView.image = NSWorkspace.shared.icon(forFile: url.path())
            } else {
                // Bound to something that is not installed any more.
                iconView.image = NSImage(
                    systemSymbolName: "questionmark.square.dashed",
                    accessibilityDescription: nil
                )
                iconView.contentTintColor = .tertiaryLabelColor
            }
        } else {
            iconView.image = NSImage(
                systemSymbolName: "square.dashed",
                accessibilityDescription: nil
            )
            iconView.contentTintColor = .quaternaryLabelColor
        }

        let cell = NSStackView(views: [iconView, label])
        cell.orientation = .vertical
        cell.spacing = 6
        cell.alignment = .centerX
        return cell
    }
}
