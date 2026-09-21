import AppKit

@main
struct InputBlockerTests {
    static func main() {
        let key = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
        assert(InputBlocker.route(type: .keyDown, event: key, active: false, prompting: false) == .pass)
        // A wake-up key must be consumed, not executed in the previous app.
        assert(InputBlocker.route(type: .keyDown, event: key, active: true, prompting: false) == .wake)
        assert(InputBlocker.route(type: .keyUp, event: key, active: true, prompting: false) == .discard)
        assert(InputBlocker.route(type: .leftMouseDown, event: key, active: true, prompting: false) == .wake)
        assert(InputBlocker.route(type: .mouseMoved, event: key, active: true, prompting: false) == .wake)
        assert(InputBlocker.route(type: .scrollWheel, event: key, active: true, prompting: false) == .wake)
        // Text and clicks may be delivered only to Blackout's own process.
        assert(InputBlocker.route(type: .keyDown, event: key, active: true, prompting: true) == .deliverToBlackout)
        assert(InputBlocker.route(type: .leftMouseDown, event: key, active: true, prompting: true) == .deliverToBlackout)
        key.flags = .maskCommand
        for code: Int64 in [48, 12, 49, 46] { // Cmd-Tab, Cmd-Q, Cmd-Space, Cmd-M
            key.setIntegerValueField(.keyboardEventKeycode, value: code)
            assert(InputBlocker.route(type: .keyDown, event: key, active: true, prompting: true) == .discard)
        }
        key.setIntegerValueField(.keyboardEventKeycode, value: 9) // Cmd-V stays inside Blackout.
        assert(InputBlocker.route(type: .keyDown, event: key, active: true, prompting: true) == .deliverToBlackout)
        key.flags = [.maskControl, .maskAlternate]
        assert(InputBlocker.route(type: .keyDown, event: key, active: true, prompting: true) == .discard)
        key.flags = .maskControl
        key.setIntegerValueField(.keyboardEventKeycode, value: 49)
        assert(InputBlocker.route(type: .keyDown, event: key, active: true, prompting: true) == .switchInputSource)
        assert(InputBlocker.route(type: .keyUp, event: key, active: true, prompting: true) == .discard)
        // Media/system events must not become commands in another application.
        assert(InputBlocker.route(type: CGEventType(rawValue: 14)!, event: key, active: true, prompting: true) == .discard)
        assert(InputBlocker.route(type: .keyDown, event: key, active: false, prompting: true) == .pass)
        print("Input blocking checks passed")
    }
}
