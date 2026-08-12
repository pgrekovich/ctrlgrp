import AppKit
import CtrlgrpCore

/// A borderless, non-activating overlay listing the current slots, parked in the
/// top right corner. It must never take focus: the point is to glance at it
/// while another app stays frontmost.
@MainActor
final class HUDPanel {
    private enum Metrics {
        static let icon: CGFloat = 18
        static let digit: CGFloat = 11
        static let cellPadH: CGFloat = 7
        static let cellPadV: CGFloat = 4
        static let cellRadius: CGFloat = 5
        static let cellGap: CGFloat = 4
        static let digitToIcon: CGFloat = 5
        /// Width of an unbound slot: a bare digit needs no room for an icon.
        static let emptyCell: CGFloat = 14
        static let containerPad: CGFloat = 6
        static let containerRadius: CGFloat = 9
        /// Gap from the screen's top right corner.
        static let screenMargin: CGFloat = 12
    }

    /// How long the HUD stays up before hiding itself. Long enough to read ten
    /// slots, short enough that it never has to be dismissed by hand.
    private static let visibleDuration: TimeInterval = 2

    // Built once and kept for the process lifetime. NSApplication retains
    // every NSPanel in its window list once created, ordered in or out,
    // regardless of external references, so a fresh panel per toggle would
    // never be released: in a daemon that runs for weeks that is an
    // unbounded leak of the whole view tree, not a one-off allocation.
    private var panel: NSPanel?
    private var autoHide: DispatchWorkItem?

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle(bindings: [Slot: String]) {
        if isVisible {
            hide()
        } else {
            show(bindings: bindings)
        }
    }

    func hide() {
        autoHide?.cancel()
        autoHide = nil
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
        scheduleAutoHide()
    }

    private func show(bindings: [Slot: String]) {
        let panel = panel ?? makePanel()
        self.panel = panel
        apply(bindings: bindings, to: panel)
        // orderFrontRegardless, not makeKeyAndOrderFront: showing the HUD must
        // not change which app is frontmost.
        panel.orderFrontRegardless()
        panel.invalidateShadow()
        scheduleAutoHide()
    }

    private func scheduleAutoHide() {
        autoHide?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.hide() }
        }
        autoHide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.visibleDuration, execute: work)
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
        panel.setFrame(topRightFrame(size: size), display: false)
        panel.contentView = content
    }

    private func topRightFrame(size: NSSize) -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else {
            return NSRect(origin: .zero, size: size)
        }
        // visibleFrame already excludes the menu bar, so this sits just below it.
        return NSRect(
            x: visible.maxX - size.width - Metrics.screenMargin,
            y: visible.maxY - size.height - Metrics.screenMargin,
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
        background.layer?.cornerRadius = Metrics.containerRadius
        // cornerRadius alone does not clip a visual effect view's backdrop
        // sublayer; masksToBounds is what actually rounds the rendered material.
        background.layer?.masksToBounds = true
        background.layer?.borderWidth = 1
        background.layer?.borderColor = NSColor.white.withAlphaComponent(0.06).cgColor

        let strip = NSStackView(views: Slot.all.map { cell(for: $0, bundleID: bindings[$0]) })
        strip.orientation = .horizontal
        strip.spacing = Metrics.cellGap
        strip.alignment = .centerY
        strip.translatesAutoresizingMaskIntoConstraints = false

        background.addSubview(strip)
        let pad = Metrics.containerPad
        NSLayoutConstraint.activate([
            strip.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: pad),
            strip.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -pad),
            strip.topAnchor.constraint(equalTo: background.topAnchor, constant: pad),
            strip.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -pad),
        ])
        // The caller reads this view's frame right after this call returns to
        // size the panel, so it must already be laid out and sized here
        // rather than left for a layout pass that may never happen.
        background.layoutSubtreeIfNeeded()
        background.frame = NSRect(origin: .zero, size: background.fittingSize)
        return background
    }

    private func digitLabel(_ slot: Slot, bound: Bool) -> NSTextField {
        let label = NSTextField(labelWithString: slot.description)
        label.font = .monospacedDigitSystemFont(ofSize: Metrics.digit, weight: .semibold)
        label.textColor = bound ? .labelColor : NSColor.labelColor.withAlphaComponent(0.35)
        label.alignment = .center
        return label
    }

    private func cell(for slot: Slot, bundleID: String?) -> NSView {
        guard let bundleID else { return emptyCell(for: slot) }

        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: Metrics.icon),
            iconView.heightAnchor.constraint(equalToConstant: Metrics.icon),
        ])

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            iconView.imageScaling = .scaleProportionallyUpOrDown
            // percentEncoded: false is load-bearing. The default encodes spaces,
            // and an app like "Brave Browser.app" then resolves to a path that
            // does not exist, which silently yields the generic document icon.
            iconView.image = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
        } else {
            // Bound to something that is not installed any more. Kept smaller
            // and dimmer than a real icon on purpose: a missing app is a quiet
            // error, it should not out-shout the slots that work.
            let symbol = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
            iconView.image = NSImage(systemSymbolName: "questionmark", accessibilityDescription: nil)?
                .withSymbolConfiguration(symbol)
            iconView.contentTintColor = NSColor.labelColor.withAlphaComponent(0.3)
            // Anything but scaleNone would blow the small glyph back up to the
            // icon box and undo the point size just set.
            iconView.imageScaling = .scaleNone
        }

        let row = NSStackView(views: [digitLabel(slot, bound: true), iconView])
        row.orientation = .horizontal
        row.spacing = Metrics.digitToIcon
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        let box = NSView()
        box.translatesAutoresizingMaskIntoConstraints = false
        box.wantsLayer = true
        box.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.10).cgColor
        box.layer?.cornerRadius = Metrics.cellRadius
        box.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: Metrics.cellPadH),
            row.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -Metrics.cellPadH),
            row.topAnchor.constraint(equalTo: box.topAnchor, constant: Metrics.cellPadV),
            row.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -Metrics.cellPadV),
        ])
        return box
    }

    /// An unbound slot is a bare dim digit with no box behind it. Dropping the
    /// placeholder artwork is most of what keeps the strip small.
    private func emptyCell(for slot: Slot) -> NSView {
        let label = digitLabel(slot, bound: false)
        label.translatesAutoresizingMaskIntoConstraints = false
        let holder = NSView()
        holder.translatesAutoresizingMaskIntoConstraints = false
        holder.addSubview(label)
        NSLayoutConstraint.activate([
            holder.widthAnchor.constraint(equalToConstant: Metrics.emptyCell),
            holder.heightAnchor.constraint(equalToConstant: Metrics.icon + Metrics.cellPadV * 2),
            label.centerXAnchor.constraint(equalTo: holder.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: holder.centerYAnchor),
        ])
        return holder
    }
}
