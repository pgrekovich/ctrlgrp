import AppKit
import CtrlgrpCore

/// A borderless, non-activating overlay listing the current slots. It must
/// never take focus: the point is to look at it while another app stays
/// frontmost.
@MainActor
final class HUDPanel {
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
        panel = nil
    }

    private func show(bindings: [Slot: String]) {
        let content = makeContentView(bindings: bindings)
        let size = content.frame.size
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = content
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.setFrame(centeredFrame(size: size), display: false)
        // orderFrontRegardless, not makeKeyAndOrderFront: showing the HUD must
        // not change which app is frontmost.
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func centeredFrame(size: NSSize) -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
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
        // Resolve the constraints now: fittingSize is only meaningful after a
        // layout pass, and a zero-sized panel would be invisible.
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
