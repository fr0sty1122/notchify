import Carbon
import Foundation

final class HotKeyController {
    private let handler: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let signature = OSType(0x4D4E5443)
    private let hotKeyID = UInt32(1)

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    func register() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var pressedID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &pressedID)
                let controller = Unmanaged<HotKeyController>.fromOpaque(userData).takeUnretainedValue()
                if pressedID.id == controller.hotKeyID {
                    controller.handler()
                }
                return noErr
            },
            1,
            &eventType,
            pointer,
            &eventHandler
        )

        let id = EventHotKeyID(signature: signature, id: hotKeyID)
        RegisterEventHotKey(UInt32(49), UInt32(cmdKey | optionKey), id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}

