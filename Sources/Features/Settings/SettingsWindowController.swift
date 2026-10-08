import AppKit
import ApplicationServices
import ServiceManagement
import LocalAuthentication

private final class SettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onPasswordSettingsChanged: (() -> Void)?
    var onUpdateAvailable: (() -> Void)?
    var onClose: (() -> Void)?
    private let passwords: PasswordSettings
    private let preferences: AppPreferences
    private let releaseSession: URLSession
    private let languageLabel = NSTextField(labelWithString: "")
    private let languageSelector = NSPopUpButton(frame: .zero, pullsDown: false)
    private let currentVersion: String
    private let versionLabel = NSTextField(labelWithString: "")
    private let checkUpdates = NSButton()
    private let automaticUpdates = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let updateNote = NSTextField(wrappingLabelWithString: "")
    private let openRelease = NSButton()
    private let downloadUpdate = NSButton()
    private let quitForUpdate = NSButton()
    private let updateStatus = NSTextField(wrappingLabelWithString: "")
    private var updateTask: Task<Void, Never>?
    private var downloadTask: Task<Void, Never>?
    private var downloadedInstaller: URL?
    private var availableRelease: AppRelease?
    private var updateMessageKey: String?
    private var nextAutomaticCheck = Date.distantPast
    private var notifiedVersion: ReleaseVersion?
    private let loginToggle = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let loginStatus = NSTextField(wrappingLabelWithString: "")
    private let loginSettings = NSButton()
    private let accessibilityLabel = NSTextField(labelWithString: "")
    private let accessibilityStatus = NSTextField(wrappingLabelWithString: "")
    private let accessibilitySettings = NSButton()
    private let passwordToggle = NSSwitch()
    private let passwordLabel = NSTextField(wrappingLabelWithString: "")
    private let editPassword = NSButton()
    private let resetPassword = NSButton()
    private var passwordResetContext: LAContext?
    private var passwordSheet: PasswordSheetController?
    private let passwordStatus = NSTextField(wrappingLabelWithString: "")
    private let promptTimeoutLabel = NSTextField(wrappingLabelWithString: "")
    private let promptTimeout = NSPopUpButton(frame: .zero, pullsDown: false)
    private let note = NSTextField(wrappingLabelWithString: "")
    private var passwordMessageKey: String?

    var hasPendingPasswordChanges: Bool { passwordSheet != nil || passwordResetContext != nil }

    init(passwords: PasswordSettings, preferences: AppPreferences = AppPreferences(),
         currentVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—",
         releaseSession: URLSession = .shared) {
        self.passwords = passwords
        self.preferences = preferences
        self.currentVersion = currentVersion
        self.releaseSession = releaseSession
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
        passwordToggle.action = #selector(togglePasswordProtection)
        automaticUpdates.target = self
        automaticUpdates.action = #selector(changeAutomaticUpdates)
        promptTimeout.target = self
        promptTimeout.action = #selector(changePromptTimeout)
        for (button, action) in [
            (loginSettings, #selector(openLoginSettings)),
            (accessibilitySettings, #selector(openAccessibilitySettings)),
            (checkUpdates, #selector(checkForUpdates)),
            (openRelease, #selector(openReleasePage)),
            (downloadUpdate, #selector(downloadInstaller)),
            (quitForUpdate, #selector(quitToInstall)),
            (editPassword, #selector(editPasswordSettings)),
            (resetPassword, #selector(resetForgottenPassword))
        ] {
            button.target = self
            button.action = action
            button.bezelStyle = .rounded
        }
        for toggle in [loginToggle, automaticUpdates] {
            toggle.cell?.wraps = true
            toggle.cell?.isScrollable = false
        }
        resetPassword.isBordered = false
        resetPassword.contentTintColor = .linkColor
        resetPassword.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        let passwordRow = NSStackView(views: [passwordToggle, passwordLabel])
        passwordRow.orientation = .horizontal
        passwordRow.alignment = .centerY
        passwordRow.spacing = 12
        passwordToggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        passwordLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        passwordLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        note.textColor = .secondaryLabelColor
        note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        for label in [loginStatus, accessibilityStatus, passwordStatus, updateStatus, updateNote] {
            label.textColor = .secondaryLabelColor
        }
        let separators = (0..<4).map { _ -> NSBox in
            let separator = NSBox()
            separator.boxType = .separator
            return separator
        }
        let stack = NSStackView(views: [
            languageLabel, languageSelector, separators[0],
            versionLabel, automaticUpdates, updateNote, checkUpdates, updateStatus, downloadUpdate, quitForUpdate, openRelease, separators[3],
            loginToggle, loginStatus, loginSettings, separators[1],
            accessibilityLabel, accessibilityStatus, accessibilitySettings, separators[2],
            passwordRow, passwordStatus, editPassword, resetPassword, promptTimeoutLabel, promptTimeout, note
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
        passwordRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        passwordLabel.trailingAnchor.constraint(equalTo: passwordRow.trailingAnchor).isActive = true
        for view in [loginToggle, automaticUpdates, loginStatus, accessibilityStatus, passwordStatus,
                     promptTimeoutLabel, note, updateStatus, updateNote] + separators {
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

    func show(activate: Bool = true) {
        cancelPendingPasswordChanges()
        passwordMessageKey = nil
        refreshLanguage()
        if activate {
            NSApp.activate(ignoringOtherApps: true)
            showWindow(nil)
            window?.makeKeyAndOrderFront(nil)
        } else {
            window?.orderBack(nil)
        }
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
        cancelPendingPasswordChanges()
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
        passwordLabel.stringValue = L("Require a password to restore the screen")
        passwordToggle.setAccessibilityLabel(passwordLabel.stringValue)
        promptTimeoutLabel.stringValue = L("Hide the password prompt after inactivity")
        promptTimeout.setAccessibilityLabel(promptTimeoutLabel.stringValue)
        promptTimeout.removeAllItems()
        for seconds in Set([5, 10, 15, 30, 60, 120, 300, preferences.unlockPromptTimeout]).sorted() {
            promptTimeout.addItem(withTitle: String(format: L("%d seconds"), seconds))
            promptTimeout.lastItem?.representedObject = seconds
        }
        promptTimeout.select(promptTimeout.itemArray.first {
            $0.representedObject as? Int == preferences.unlockPromptTimeout
        })
        promptTimeout.isEnabled = passwords.isEnabled
        editPassword.title = L("Change Password…")
        resetPassword.title = L("Forgot Password…")
        note.stringValue = L("Password protection is optional. Blackout covers the screen within the app and does not replace the macOS screen lock.")
            + "\n" + L("Emergency exit: hold Escape for 3 seconds. This bypasses the app password.")
        passwordStatus.stringValue = L(passwordMessageKey ??
            (passwords.isEnabled ? "Password protection is on." : "Password protection is off."))
        refreshPasswordActions()
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
        automaticUpdates.title = L("Automatically check for updates")
        automaticUpdates.state = preferences.automaticallyChecksForUpdates ? .on : .off
        updateNote.stringValue = L("Checks GitHub at launch and daily. Downloads open a DMG; replace the app to install. Settings are kept.")
        checkUpdates.title = L("Check for Updates…")
        checkUpdates.isEnabled = updateTask == nil && downloadTask == nil
        downloadUpdate.title = L(downloadedInstaller == nil ? "Download Update…" : "Open Downloaded Update…")
        downloadUpdate.isHidden = availableRelease == nil
        downloadUpdate.isEnabled = downloadTask == nil
        quitForUpdate.title = L("Quit Blackout")
        quitForUpdate.isHidden = downloadedInstaller == nil
        openRelease.title = L("Open Release Page…")
        if downloadTask != nil {
            updateStatus.stringValue = L("Downloading update…")
        } else if let key = updateMessageKey {
            updateStatus.stringValue = L(key)
        } else if updateTask != nil {
            updateStatus.stringValue = L("Checking for updates…")
        } else if let release = availableRelease {
            updateStatus.stringValue = String(format: L("Version %@ is available."), release.version.string)
        } else {
            updateStatus.stringValue = updateMessageKey.map(L) ?? ""
        }
        updateStatus.isHidden = updateStatus.stringValue.isEmpty
    }

    @objc private func checkForUpdates() {
        performUpdateCheck(automatically: false)
    }

    func checkForUpdatesAutomatically(now: Date = Date()) {
        guard preferences.automaticallyChecksForUpdates, now >= nextAutomaticCheck,
              updateTask == nil, downloadTask == nil else { return }
        nextAutomaticCheck = now.addingTimeInterval(24 * 60 * 60)
        performUpdateCheck(automatically: true)
    }

    @objc private func changeAutomaticUpdates() {
        preferences.automaticallyChecksForUpdates = automaticUpdates.state == .on
        if preferences.automaticallyChecksForUpdates {
            nextAutomaticCheck = .distantPast
            checkForUpdatesAutomatically()
        }
    }

    @objc private func changePromptTimeout() {
        if let seconds = promptTimeout.selectedItem?.representedObject as? Int {
            preferences.unlockPromptTimeout = seconds
        }
    }

    private func performUpdateCheck(automatically: Bool) {
        guard updateTask == nil, downloadTask == nil else { return }
        availableRelease = nil
        downloadedInstaller = nil
        updateMessageKey = nil
        updateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let current = ReleaseVersion(self.currentVersion) else {
                    throw ReleaseChecker.CheckError.invalidResponse
                }
                if let release = try await ReleaseChecker.latestRelease(session: self.releaseSession) {
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
            if automatically, self.preferences.automaticallyChecksForUpdates,
               let release = self.availableRelease, self.notifiedVersion != release.version {
                self.notifiedVersion = release.version
                self.onUpdateAvailable?()
            }
        }
        refreshUpdateStatus()
    }

    @objc private func openReleasePage() {
        NSWorkspace.shared.open(availableRelease?.url ?? URL(string: "https://github.com/baba9811/blackout-mac/releases")!)
    }

    @objc private func downloadInstaller() {
        guard downloadTask == nil, let release = availableRelease else { return }
        if downloadedInstaller != nil { openDownloadedInstaller(); return }
        updateMessageKey = nil
        downloadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let directory = try FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask,
                                                            appropriateFor: nil, create: true)
                self.downloadedInstaller = try await ReleaseDownloader.download(release, to: directory,
                                                                               session: self.releaseSession)
            } catch {
                self.updateMessageKey = "Download failed. Try again or open the release page."
            }
            self.downloadTask = nil
            self.refreshUpdateStatus()
            if self.window?.isVisible == true { self.openDownloadedInstaller() }
        }
        refreshUpdateStatus()
    }

    private func openDownloadedInstaller() {
        guard let installer = downloadedInstaller, window?.isVisible == true,
              !hasPendingPasswordChanges, window?.attachedSheet == nil else { return }
        if NSWorkspace.shared.open(installer) {
            updateMessageKey = "Update ready. Quit Blackout, replace the app in the same folder, and reopen it. Settings are kept."
            refreshUpdateStatus()
        } else {
            updateMessageKey = "Could not open the update. Open it from Downloads."
            refreshUpdateStatus()
        }
    }

    @objc private func quitToInstall() { NSApp.terminate(nil) }

    private func refreshPasswordActions() {
        let idle = passwordResetContext == nil && passwordSheet == nil
        passwordToggle.state = passwords.isEnabled ? .on : .off
        passwordToggle.isEnabled = idle
        editPassword.isEnabled = idle
        resetPassword.isEnabled = idle
        editPassword.isHidden = !passwords.isEnabled
        resetPassword.isHidden = !passwords.isEnabled
    }

    @objc private func editPasswordSettings() {
        guard passwords.isEnabled else { return }
        showPasswordSheet(.change)
    }

    @objc private func togglePasswordProtection() {
        let enabled = passwords.isEnabled
        passwordToggle.state = enabled ? .on : .off
        guard passwordResetContext == nil, passwordSheet == nil else { return }
        showPasswordSheet(enabled ? .turnOff : .set)
    }

    private func showPasswordSheet(_ mode: PasswordSheetController.Mode) {
        guard passwordResetContext == nil, passwordSheet == nil, let window, window.isVisible else { return }
        let sheet = PasswordSheetController(passwords: passwords, mode: mode)
        passwordSheet = sheet
        refreshPasswordActions()
        window.beginSheet(sheet.window!) { [weak self] response in
            guard let self, self.passwordSheet === sheet else { return }
            self.passwordSheet = nil
            if response == .OK {
                self.passwordMessageKey = self.passwords.isEnabled
                    ? "Saved. A password will be required the next time you black out the screen."
                    : "Saved. Password protection is off."
                self.onPasswordSettingsChanged?()
            }
            self.refreshLanguage()
        }
    }

    func cancelPendingPasswordChanges() {
        let sheet = passwordSheet
        passwordSheet = nil
        sheet?.cancel()
        let context = passwordResetContext
        passwordResetContext = nil
        context?.invalidate()
        refreshPasswordActions()
    }

    @objc private func resetForgottenPassword() {
        guard passwordResetContext == nil, passwordSheet == nil, passwords.isEnabled, window?.isVisible == true else { return }
        let context = LAContext()
        passwordMessageKey = "Password reset was not completed. Your password is unchanged."
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            refreshLanguage()
            return
        }
        let revision = passwords.revision
        passwordResetContext = context
        passwordMessageKey = "Authenticate with macOS to reset your Blackout password."
        refreshPasswordActions()
        refreshLanguage()
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: L("Authenticate with macOS to reset your Blackout password.")) { [weak self] success, _ in
            DispatchQueue.main.async {
                guard let self, self.passwordResetContext === context, self.window?.isVisible == true else { return }
                self.passwordResetContext = nil
                context.invalidate()
                if success, self.passwords.resetAfterOwnerAuthentication(ifUnchanged: revision) {
                    self.passwordMessageKey = "Password reset. Password protection is off."
                    self.onPasswordSettingsChanged?()
                } else {
                    self.passwordMessageKey = "Password reset was not completed. Your password is unchanged."
                }
                self.refreshLanguage()
            }
        }
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
