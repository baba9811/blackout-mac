import AppKit
import ApplicationServices
import ServiceManagement

private final class SettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onPasswordSettingsChanged: (() -> Void)?
    var onClose: (() -> Void)?
    private let passwords: PasswordSettings
    private let languageLabel = NSTextField(labelWithString: "")
    private let languageSelector = NSPopUpButton(frame: .zero, pullsDown: false)
    private let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    private let versionLabel = NSTextField(labelWithString: "")
    private let checkUpdates = NSButton()
    private let openRelease = NSButton()
    private let updateStatus = NSTextField(wrappingLabelWithString: "")
    private var updateTask: Task<Void, Never>?
    private var availableRelease: AppRelease?
    private var updateMessageKey: String?
    private let loginToggle = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let loginStatus = NSTextField(wrappingLabelWithString: "")
    private let loginSettings = NSButton()
    private let accessibilityLabel = NSTextField(labelWithString: "")
    private let accessibilityStatus = NSTextField(wrappingLabelWithString: "")
    private let accessibilitySettings = NSButton()
    private let passwordToggle = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let currentPassword = NSSecureTextField()
    private let newPassword = NSSecureTextField()
    private let confirmation = NSSecureTextField()
    private let save = NSButton()
    private let passwordStatus = NSTextField(wrappingLabelWithString: "")
    private let note = NSTextField(wrappingLabelWithString: "")
    private var passwordMessageKey: String?
    private var passwordError: Error?

    init(passwords: PasswordSettings) {
        self.passwords = passwords
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 700),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        window.minSize = NSSize(width: 520, height: 480)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self

        languageSelector.target = self
        languageSelector.action = #selector(changeLanguage)
        loginToggle.target = self
        loginToggle.action = #selector(changeLoginItem)
        passwordToggle.target = self
        passwordToggle.action = #selector(updatePasswordFields)
        for (button, action) in [
            (loginSettings, #selector(openLoginSettings)),
            (accessibilitySettings, #selector(openAccessibilitySettings)),
            (checkUpdates, #selector(checkForUpdates)),
            (openRelease, #selector(openReleasePage)),
            (save, #selector(savePassword))
        ] {
            button.target = self
            button.action = action
            button.bezelStyle = .rounded
        }
        for toggle in [loginToggle, passwordToggle] {
            toggle.cell?.wraps = true
            toggle.cell?.isScrollable = false
        }
        note.textColor = .secondaryLabelColor
        note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        for label in [loginStatus, accessibilityStatus, passwordStatus, updateStatus] {
            label.textColor = .secondaryLabelColor
        }
        let separators = (0..<4).map { _ -> NSBox in
            let separator = NSBox()
            separator.boxType = .separator
            return separator
        }
        let stack = NSStackView(views: [
            languageLabel, languageSelector, separators[0],
            versionLabel, checkUpdates, updateStatus, openRelease, separators[3],
            loginToggle, loginStatus, loginSettings, separators[1],
            accessibilityLabel, accessibilityStatus, accessibilitySettings, separators[2],
            passwordToggle, currentPassword, newPassword, confirmation, save, passwordStatus, note
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let document = SettingsDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        document.addSubview(stack)
        let content = window.contentView!
        content.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24)
        ])
        for view in [loginToggle, loginStatus, accessibilityStatus, passwordToggle,
                     currentPassword, newPassword, confirmation, passwordStatus, note, updateStatus] + separators {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        languageSelector.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshLanguage), name: .appLanguageChanged, object: nil
        )
        refreshLanguage()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        passwordToggle.state = passwords.isEnabled ? .on : .off
        clearPasswordFields()
        passwordMessageKey = nil
        passwordError = nil
        refreshLanguage()
        updatePasswordFields()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.contentView?.layoutSubtreeIfNeeded()
        if let scroll = window?.contentView?.subviews.first as? NSScrollView,
           let document = scroll.documentView {
            document.scroll(.zero)
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        refreshLoginStatus()
        refreshAccessibilityStatus()
    }
    func windowWillClose(_ notification: Notification) {
        clearPasswordFields()
        onClose?()
    }

    @objc private func refreshLanguage() {
        let direction: NSUserInterfaceLayoutDirection = ["ar", "he"].contains(AppLanguage.currentCode) ? .rightToLeft : .leftToRight
        if let content = window?.contentView { updateLayoutDirection(content, direction) }
        window?.title = L("Blackout Settings")
        languageLabel.stringValue = L("Language")
        languageSelector.removeAllItems()
        languageSelector.addItem(withTitle: L("System Default"))
        languageSelector.lastItem?.representedObject = "system"
        for language in AppLanguage.supported {
            languageSelector.addItem(withTitle: language.name)
            languageSelector.lastItem?.representedObject = language.code
        }
        if let item = languageSelector.itemArray.first(where: {
            $0.representedObject as? String == AppLanguage.selection
        }) { languageSelector.select(item) }
        languageSelector.setAccessibilityLabel(L("Language"))
        loginToggle.title = L("Launch at login")
        loginSettings.title = L("Open Login Settings…")
        accessibilityLabel.stringValue = L("Input Blocking")
        accessibilitySettings.title = L("Open Input Permission Settings…")
        passwordToggle.title = L("Require a password to restore the screen")
        save.title = L("Save Password Settings")
        for (field, key) in [
            (currentPassword, "Current password (required to change or disable)"),
            (newPassword, "New password"), (confirmation, "Confirm new password")
        ] {
            field.placeholderString = L(key)
            field.setAccessibilityLabel(L(key))
        }
        note.stringValue = L("Password protection is optional. Blackout covers the screen within the app and does not replace the macOS screen lock.")
        passwordStatus.stringValue = passwordError?.localizedDescription ?? L(passwordMessageKey ??
            (passwords.isEnabled ? "Password protection is on." : "Password protection is off."))
        passwordStatus.textColor = passwordError == nil ? .secondaryLabelColor : .systemRed
        refreshLoginStatus()
        refreshAccessibilityStatus()
        refreshUpdateStatus()
    }

    private func updateLayoutDirection(_ view: NSView, _ direction: NSUserInterfaceLayoutDirection) {
        view.userInterfaceLayoutDirection = direction
        if let text = view as? NSTextField {
            text.alignment = direction == .rightToLeft ? .right : .left
        }
        for child in view.subviews { updateLayoutDirection(child, direction) }
    }

    @objc private func changeLanguage() {
        AppLanguage.selection = languageSelector.selectedItem?.representedObject as? String ?? "system"
    }

    private func refreshUpdateStatus() {
        versionLabel.stringValue = String(format: L("Version %@"), currentVersion)
        checkUpdates.title = L("Check for Updates…")
        checkUpdates.isEnabled = updateTask == nil
        openRelease.title = L("Open Release Page…")
        openRelease.isHidden = availableRelease == nil
        if updateTask != nil {
            updateStatus.stringValue = L("Checking for updates…")
        } else if let release = availableRelease {
            updateStatus.stringValue = String(format: L("Version %@ is available."), release.version.string)
        } else {
            updateStatus.stringValue = updateMessageKey.map(L) ?? ""
        }
        updateStatus.isHidden = updateStatus.stringValue.isEmpty
    }

    @objc private func checkForUpdates() {
        guard updateTask == nil else { return }
        availableRelease = nil
        updateMessageKey = nil
        updateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let current = ReleaseVersion(self.currentVersion) else {
                    throw ReleaseChecker.CheckError.invalidResponse
                }
                if let release = try await ReleaseChecker.latestRelease() {
                    if release.version > current { self.availableRelease = release }
                    else { self.updateMessageKey = "You’re up to date." }
                } else {
                    self.updateMessageKey = "No releases have been published yet."
                }
            } catch {
                self.updateMessageKey = "Could not check for updates. Please try again."
            }
            self.updateTask = nil
            self.refreshUpdateStatus()
        }
        refreshUpdateStatus()
    }

    @objc private func openReleasePage() {
        if let release = availableRelease { NSWorkspace.shared.open(release.url) }
    }

    private func clearPasswordFields() {
        currentPassword.stringValue = ""
        newPassword.stringValue = ""
        confirmation.stringValue = ""
    }

    @objc private func updatePasswordFields() {
        currentPassword.isEnabled = passwords.isEnabled
        newPassword.isEnabled = passwordToggle.state == .on
        confirmation.isEnabled = passwordToggle.state == .on
    }

    @objc private func savePassword() {
        do {
            try passwords.update(
                enabled: passwordToggle.state == .on,
                current: currentPassword.stringValue,
                new: newPassword.stringValue,
                confirmation: confirmation.stringValue
            )
            clearPasswordFields()
            updatePasswordFields()
            passwordError = nil
            passwordMessageKey = passwords.isEnabled
                ? "Saved. A password will be required the next time you black out the screen."
                : "Saved. Password protection is off."
            onPasswordSettingsChanged?()
        } catch {
            passwordError = error
        }
        refreshLanguage()
    }

    private func refreshLoginStatus() {
        let status = SMAppService.mainApp.status
        loginToggle.state = status == .enabled || status == .requiresApproval ? .on : .off
        switch status {
        case .enabled: loginStatus.stringValue = L("Blackout will run in the menu bar when you log in.")
        case .requiresApproval: loginStatus.stringValue = L("Allow Blackout in the macOS login settings.")
        case .notRegistered: loginStatus.stringValue = L("Launch at login is off.")
        case .notFound: loginStatus.stringValue = L("Blackout is not registered as a login item. Enable the option to register it.")
        @unknown default: loginStatus.stringValue = L("Check the status in the macOS login settings.")
        }
    }

    private func refreshAccessibilityStatus() {
        accessibilityStatus.stringValue = AXIsProcessTrusted()
            ? L("Input control permission is enabled. Keyboard and mouse input can be blocked during blackout.")
            : L("Input control permission is required before blackout. Open the permission settings below and enable Blackout.")
    }

    @objc private func changeLoginItem() {
        do {
            if loginToggle.state == .on {
                if SMAppService.mainApp.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                } else if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
            refreshLoginStatus()
        } catch {
            refreshLoginStatus()
            loginStatus.stringValue = String(format: L("Could not change launch at login: %@"), error.localizedDescription)
        }
    }

    @objc private func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}
