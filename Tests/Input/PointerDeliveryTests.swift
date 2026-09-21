import AppKit

private final class ClickTarget: NSObject {
    var clicks = 0
    @objc func clicked(_ sender: Any?) { clicks += 1 }
}

@main
struct PointerDeliveryTests {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let window = NSWindow(contentRect: NSRect(x: -640, y: 120, width: 640, height: 480),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let target = InputBlocker.MouseTarget(windowNumber: window.windowNumber,
                                              frame: window.frame, desktopTop: 1080)
        let receiver = ClickTarget()
        let button = NSButton(title: "Cancel", target: receiver, action: #selector(ClickTarget.clicked))
        button.frame = NSRect(x: 200, y: 160, width: 120, height: 32)
        window.contentView!.addSubview(button)
        // Literal global point maps to (260, 176), inside Cancel on the left-hand display.
        let source = CGEventSource(stateID: .privateState)!
        func pointer(_ type: CGEventType, at point: CGPoint = CGPoint(x: -380, y: 784)) -> CGEvent {
            let event = CGEvent(mouseEventSource: source, mouseType: type,
                                mouseCursorPosition: point, mouseButton: .left)!
            event.flags = []
            event.setIntegerValueField(.mouseEventClickState, value: 1)
            return event
        }
        let down = target.event(from: pointer(.leftMouseDown))!
        assert(down.windowNumber == window.windowNumber, "Mouse input must explicitly target the Blackout window")
        assert(down.window === window)
        assert(down.locationInWindow == NSPoint(x: 260, y: 176), "Quartz points must become window-local AppKit points")
        let up = target.event(from: pointer(.leftMouseUp))!
        let modified = pointer(.rightMouseDown)
        modified.flags = [.maskShift, .maskAlternate]
        modified.timestamp = 12_500_000_000
        modified.setIntegerValueField(.mouseEventClickState, value: 2)
        let right = target.event(from: modified)!
        assert(right.type == .rightMouseDown && right.clickCount == 2)
        assert(right.modifierFlags == [.shift, .option] && right.timestamp == 12.5)
        let keyboard = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)!
        assert(target.event(from: keyboard) == nil, "The pointer bridge must not convert keyboard input")
        let scroll = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 1,
                             wheel1: 1, wheel2: 0, wheel3: 0)!
        assert(target.event(from: scroll) == nil, "The unlock form has no scroll destination")

        // NSButton owns its tracking loop. Its release must arrive even while the main
        // thread is inside mouseDown, rather than waiting for a main-queue callback.
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            app.postEvent(up, atStart: false)
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            fputs("Native pointer tracking timed out\n", stderr)
            exit(1)
        }
        button.mouseDown(with: down)
        assert(receiver.clicks == 1, "Native Cancel button must act after a delayed mouseUp")

        // Releasing over another display must finish tracking without clicking Cancel.
        // Clipping this release to the target frame would strand the native tracking loop.
        let outside = CGPoint(x: 20, y: 100)
        let drag = target.event(from: pointer(.leftMouseDragged, at: outside))!
        let outsideUp = target.event(from: pointer(.leftMouseUp, at: outside))!
        assert(outsideUp.windowNumber == window.windowNumber)
        assert(outsideUp.locationInWindow == NSPoint(x: 660, y: 860))
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            app.postEvent(drag, atStart: false)
            app.postEvent(outsideUp, atStart: false)
        }
        button.mouseDown(with: down)
        assert(receiver.clicks == 1, "Releasing outside Cancel must not invoke its action")
        assert(!window.isVisible, "The regression must never show a window")
        print("Native pointer delivery checks passed")
    }
}
