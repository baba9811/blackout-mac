import AppKit

@main
struct PasswordToggleTests {
    @MainActor static func main() throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let suite = "local.blackout.toggle-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let passwords = PasswordSettings(defaults: defaults)
        let controller = SettingsWindowController(passwords: passwords)
        let window = controller.window!
        func descendants(_ view: NSView) -> [NSView] {
            let children = (view as? NSStackView)?.arrangedSubviews ?? view.subviews
            return children + children.flatMap(descendants)
        }
        let views = descendants(window.contentView!)
        guard let toggle = views.compactMap({ $0 as? NSSwitch }).first else {
            fatalError("Password protection needs a native switch")
        }
        let buttons = views.compactMap { $0 as? NSButton }
        let change = buttons.first { $0.title == L("Change Password…") }!
        let forgot = buttons.first { $0.title == L("Forgot Password…") }!
        assert(!forgot.isBordered)
        assert(toggle.accessibilityLabel() == L("Require a password to restore the screen"))
        assert(!buttons.contains { [L("Set Password…"), L("Turn Off Password…")].contains($0.title) })
        for enabled in [false, true] {
            if enabled {
                try passwords.update(enabled: true, current: "", new: "existing", confirmation: "existing")
            }
            controller.cancelPendingPasswordChanges()
            assert(toggle.state == (enabled ? .on : .off))
            assert(change.isHidden == !enabled && forgot.isHidden == !enabled)
            let credential = defaults.data(forKey: PasswordSettings.key)
            toggle.state = enabled ? .off : .on
            toggle.sendAction(toggle.action, to: toggle.target)
            // An unconfirmed toggle request must immediately reflect the saved state.
            assert(toggle.state == (enabled ? .on : .off))
            assert(defaults.data(forKey: PasswordSettings.key) == credential)
            assert(!window.isVisible)
        }
        let label = views.compactMap { $0 as? NSTextField }.first {
            $0.stringValue == L("Require a password to restore the screen")
        }!
        window.setContentSize(NSSize(width: 520, height: 480))
        label.stringValue = String(repeating: "Long translated password protection label ", count: 5)
        window.contentView!.layoutSubtreeIfNeeded()
        let row = label.superview!
        assert(label.frame.width > 0 && label.frame.height > 30, "Wrapped label: \(label.frame); row: \(row.frame)")
        // NSTextField frames include native margins outside their layout alignment rectangles.
        assert(row.bounds.contains(label.alignmentRect(forFrame: label.frame)))
        assert(toggle.frame.width > 0)
        assert(!window.isVisible)
        print("Password toggle checks passed: saved state, action visibility, accessibility and no unconfirmed changes.")
    }
}
