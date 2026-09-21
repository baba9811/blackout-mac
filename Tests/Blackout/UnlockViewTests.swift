import AppKit

private final class UnlockActions: NSObject {
    var unlocks = 0
    var cancellations = 0
    @objc func unlock(_ sender: Any?) { unlocks += 1 }
    @objc func cancel(_ sender: Any?) { cancellations += 1 }
}

@main
struct UnlockViewTests {
    static func main() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let actions = UnlockActions()
        let view = UnlockView(target: actions, unlockAction: #selector(UnlockActions.unlock),
                              cancelAction: #selector(UnlockActions.cancel))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 600),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView!.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: window.contentView!.centerXAnchor),
            view.centerYAnchor.constraint(equalTo: window.contentView!.centerYAnchor)
        ])
        window.contentView!.layoutSubtreeIfNeeded()
        assert(view.layer?.backgroundColor?.alpha == 1, "The glass must have an opaque backing inside Blackout")
        func descendants(_ root: NSView) -> [NSView] {
            root.subviews + root.subviews.flatMap(descendants)
        }
        let children = descendants(view)
        if #available(macOS 26, *) {
            assert(children.contains { $0 is NSGlassEffectView }, "Use native Liquid Glass where available")
        }
        let buttons = children.compactMap { $0 as? NSButton }
        assert(buttons.count == 2)
        let cancel = buttons.first { $0.keyEquivalent == "\u{1b}" }!
        let unlock = buttons.first { $0.keyEquivalent == "\r" }!
        for control in [view.passwordField, cancel, unlock] as [NSView] {
            let frame = view.convert(control.bounds, from: control)
            assert(frame.width > 20 && frame.height >= 24 && view.bounds.contains(frame))
            let center = NSPoint(x: frame.midX, y: frame.midY)
            let hit = view.hitTest(view.convert(center, to: view.superview))
            assert(hit === control || hit?.isDescendant(of: control) == true,
                   "Glass must not intercept control clicks")
        }
        assert(view.passwordField.action == #selector(UnlockActions.unlock))
        cancel.performClick(nil)
        unlock.performClick(nil)
        assert(actions.cancellations == 1 && actions.unlocks == 1)
        view.messageLabel.stringValue = String(repeating: "Long localized error message ", count: 6)
        window.contentView!.layoutSubtreeIfNeeded()
        let messageFrame = view.convert(view.messageLabel.bounds, from: view.messageLabel)
        assert(messageFrame.height > 30 && view.bounds.contains(messageFrame))
        assert(view.bounds.contains(view.convert(unlock.bounds, from: unlock)))
        assert(!window.isVisible)
        print("Unlock view checks passed: opaque backing, native glass, hit testing and actions")
    }
}
