import AppKit

final class BlackoutWindow: NSWindow {
    var acceptsKeyboardInput = false
    override var canBecomeKey: Bool { acceptsKeyboardInput }
    override var canBecomeMain: Bool { acceptsKeyboardInput }
}
