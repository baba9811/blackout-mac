import AppKit

final class PasswordSheetController: NSWindowController {
    enum Mode {
        case set, change, turnOff

        var titleKey: String {
            switch self {
            case .set: return "Set Password"
            case .change: return "Change Password"
            case .turnOff: return "Turn Off Password"
            }
        }
    }

    private let passwords: PasswordSettings
    private let mode: Mode
    private let currentPassword = NSSecureTextField()
    private let newPassword = NSSecureTextField()
    private let confirmation = NSSecureTextField()
    private let errorLabel = NSTextField(wrappingLabelWithString: "")
    private let stack = NSStackView()
    private var finished = false

    init(passwords: PasswordSettings, mode: Mode) {
        self.passwords = passwords
        self.mode = mode
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 240),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.title = L(mode.titleKey)
        let submit = NSButton(title: L(mode.titleKey), target: self, action: #selector(save))
        let cancel = NSButton(title: L("Cancel"), target: self, action: #selector(cancel))
        submit.bezelStyle = .rounded
        cancel.bezelStyle = .rounded
        for button in [submit, cancel] {
            button.cell?.wraps = true
            button.cell?.isScrollable = false
        }
        submit.keyEquivalent = "\r"
        cancel.keyEquivalent = "\u{1b}"
        var fields: [NSSecureTextField] = []
        if mode != .set { fields.append(currentPassword) }
        if mode != .turnOff { fields += [newPassword, confirmation] }
        let direction: NSUserInterfaceLayoutDirection = ["ar", "he"].contains(AppLanguage.currentCode) ? .rightToLeft : .leftToRight
        for (field, key) in [(currentPassword, "Current password"), (newPassword, "New password"), (confirmation, "Confirm new password")] {
            field.placeholderString = L(key)
            field.setAccessibilityLabel(L(key))
            field.userInterfaceLayoutDirection = direction
            field.alignment = direction == .rightToLeft ? .right : .left
        }
        errorLabel.textColor = .systemRed
        errorLabel.preferredMaxLayoutWidth = 432
        errorLabel.userInterfaceLayoutDirection = direction
        errorLabel.alignment = direction == .rightToLeft ? .right : .left
        errorLabel.isHidden = true
        let title = NSTextField(labelWithString: L(mode.titleKey))
        title.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        title.alignment = direction == .rightToLeft ? .right : .left
        let buttons = NSStackView(views: [cancel, submit])
        buttons.spacing = 8
        buttons.userInterfaceLayoutDirection = direction
        for view in [title] + fields + [errorLabel, buttons] { stack.addArrangedSubview(view) }
        stack.orientation = .vertical
        stack.alignment = .trailing
        stack.spacing = 12
        stack.userInterfaceLayoutDirection = direction
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = window.contentView!
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24)
        ])
        for field in fields { field.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        title.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        buttons.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor).isActive = true
        errorLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        resizeToFit()
        window.initialFirstResponder = fields.first
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func save() {
        guard !finished, window?.sheetParent != nil else { return }
        do {
            try passwords.update(enabled: mode != .turnOff, current: currentPassword.stringValue,
                                 new: newPassword.stringValue, confirmation: confirmation.stringValue)
            finish(.OK)
        } catch {
            errorLabel.stringValue = error.localizedDescription
            errorLabel.isHidden = false
            resizeToFit()
        }
    }

    @objc func cancel() { finish(.cancel) }

    private func finish(_ response: NSApplication.ModalResponse) {
        guard !finished else { return }
        finished = true
        currentPassword.stringValue = ""
        newPassword.stringValue = ""
        confirmation.stringValue = ""
        if let window { window.sheetParent?.endSheet(window, returnCode: response) }
    }

    private func resizeToFit() {
        window?.setContentSize(NSSize(width: 480, height: stack.fittingSize.height + 48))
    }
}
