import AppKit

@main
struct PasswordSheetTests {
    @MainActor static func main() throws {
        // Construct native forms without showing windows, activating the app, or authenticating.
        NSApplication.shared.setActivationPolicy(.prohibited)
        let suite = "local.blackout.sheet-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("ko", forKey: "appLanguage")
        let passwords = PasswordSettings(defaults: defaults)
        let cases: [(PasswordSheetController.Mode, [String])] = [
            (.set, ["New password", "Confirm new password"]),
            (.change, ["Current password", "New password", "Confirm new password"]),
            (.turnOff, ["Current password"])
        ]
        for (mode, expectedFields) in cases {
            defaults.removeObject(forKey: PasswordSettings.key)
            if mode != .set {
                try passwords.update(enabled: true, current: "", new: "existing", confirmation: "existing")
            }
            let credential = defaults.data(forKey: PasswordSettings.key)
            let sheet = PasswordSheetController(passwords: passwords, mode: mode)
            let window = sheet.window!
            let content = window.contentView!
            content.layoutSubtreeIfNeeded()
            let stack = content.subviews.first as! NSStackView
            let fields = stack.arrangedSubviews.compactMap { $0 as? NSSecureTextField }
            assert(fields.map(\.placeholderString) == expectedFields.map { Optional(L($0)) })
            assert(!window.isVisible)
            for field in fields {
                assert(field.frame.width > 0 && field.frame.height > 0)
                assert(content.bounds.contains(field.convert(field.bounds, to: content)))
                field.stringValue = "unsaved secret"
            }
            func descendants(_ view: NSView) -> [NSView] {
                view.subviews + view.subviews.flatMap(descendants)
            }
            let buttons = descendants(stack).compactMap { $0 as? NSButton }
            let cancel = buttons.first { $0.title == L("Cancel") }!
            let submit = buttons.first { $0 !== cancel }!
            let cancelFrame = cancel.convert(cancel.bounds, to: content)
            let submitFrame = submit.convert(submit.bounds, to: content)
            assert(abs(cancelFrame.midY - submitFrame.midY) < 1)
            // Native button frames include OS-dependent margins beyond their alignment rectangles.
            assert(cancelFrame.midX < submitFrame.midX)
            cancel.performClick(nil)
            assert(fields.allSatisfy { $0.stringValue.isEmpty })
            assert(defaults.data(forKey: PasswordSettings.key) == credential)
            assert(defaults.string(forKey: "appLanguage") == "ko")
            assert(!window.isVisible)
        }
        print("Password form checks passed: field sets, offscreen layout, cancellation and preference preservation.")
    }
}
