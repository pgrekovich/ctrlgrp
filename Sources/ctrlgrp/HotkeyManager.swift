import Carbon.HIToolbox
import CtrlgrpCore

/// Registers the global hotkeys through Carbon, which is the only mechanism
/// that grabs keys system-wide without asking for Accessibility or Input
/// Monitoring permission. Registered combinations are consumed, so option+1
/// no longer types a special character while ctrlgrp runs.
@MainActor
final class HotkeyManager {
    enum Trigger: Equatable {
        case focus(Slot)
        case bind(Slot)
        case toggleHUD
    }

    private static let signature = OSType(0x4347_5250) // 'CGRP'
    private static let bindIDOffset: UInt32 = 100
    private static let hudID: UInt32 = 200

    private let onTrigger: (Trigger) -> Void
    private var hotkeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?

    init(onTrigger: @escaping (Trigger) -> Void) {
        self.onTrigger = onTrigger
    }

    /// Registers every hotkey and returns the ones that failed, described the
    /// way a user would recognise them. A collision with another app's global
    /// hotkey must not take down the remaining slots.
    func register(includeHUD: Bool) -> [String] {
        installHandlerIfNeeded()

        var failures: [String] = []
        for slot in Slot.all {
            guard let keyCode = KeyCodes.digits[slot.digit] else { continue }
            if !register(keyCode: keyCode, modifiers: UInt32(optionKey), id: UInt32(slot.digit)) {
                failures.append("option+\(slot)")
            }
            if !register(
                keyCode: keyCode,
                modifiers: UInt32(optionKey | shiftKey),
                id: Self.bindIDOffset + UInt32(slot.digit)
            ) {
                failures.append("option+shift+\(slot)")
            }
        }

        if includeHUD,
           !register(keyCode: KeyCodes.grave, modifiers: UInt32(optionKey), id: Self.hudID) {
            failures.append("option+`")
        }

        return failures
    }

    func unregisterAll() {
        for ref in hotkeyRefs { UnregisterEventHotKey(ref) }
        hotkeyRefs.removeAll()
    }

    private func register(keyCode: Int, modifiers: UInt32, id: UInt32) -> Bool {
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            modifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return false }
        hotkeyRefs.append(ref)
        return true
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let context = Unmanaged.passUnretained(self).toOpaque()

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }

                var hotkeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )
                guard status == noErr else { return status }
                // Without this, any other app's Carbon hotkey handler
                // sharing this event class would be misrouted into ours.
                guard hotkeyID.signature == HotkeyManager.signature else {
                    return OSStatus(eventNotHandledErr)
                }

                // Carbon delivers hot-key events on the main run loop.
                MainActor.assumeIsolated {
                    Unmanaged<HotkeyManager>.fromOpaque(userData)
                        .takeUnretainedValue()
                        .handle(id: hotkeyID.id)
                }
                return noErr
            },
            1,
            &spec,
            context,
            &eventHandler
        )
        // A failure here means every RegisterEventHotKey call below will
        // still report success while nothing ever dispatches, so this must
        // be surfaced rather than silently ignored.
        if installStatus != noErr {
            Log.warn("could not install hotkey event handler (status \(installStatus)); hotkeys will not fire")
        }
    }

    private func handle(id: UInt32) {
        if id == Self.hudID {
            onTrigger(.toggleHUD)
            return
        }
        if id >= Self.bindIDOffset {
            guard let slot = Slot(digit: Int(id - Self.bindIDOffset)) else { return }
            onTrigger(.bind(slot))
            return
        }
        guard let slot = Slot(digit: Int(id)) else { return }
        onTrigger(.focus(slot))
    }
}
