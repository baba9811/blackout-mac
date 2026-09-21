import AppKit
import CoreGraphics
import Carbon.HIToolbox
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var panels: [BlackoutWindow] = []
    private var inputTimer: Timer?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandlerRef: EventHandlerRef?
    private var isBlack = false
    private var unlockPromptAvailableAt: TimeInterval = 0
    private var cursorHidden = false
    private let passwords = PasswordSettings()
    private lazy var settings: SettingsWindowController = {
        let controller = SettingsWindowController(passwords: passwords)
        controller.onPasswordSettingsChanged = { [weak self] in self?.updateStatusIcon() }
        controller.onClose = { NSApp.setActivationPolicy(.accessory) }
        return controller
    }()
    private var requiredPassword: UnlockPassword?
    private var unlockView: NSView?
    private var unlockField: NSSecureTextField?
    private var unlockError: NSTextField?
    private var nextUnlockAttempt: TimeInterval = 0
    private var sessionSuspended = false
    private var previousPresentation: NSApplication.PresentationOptions = []
    private lazy var inputBlocker: InputBlocker = {
        let blocker = InputBlocker()
        blocker.onWake = { [weak self] in self?.requestUnlock() }
        blocker.onFailure = { [weak self] in self?.inputBlockingFailed() }
        blocker.onInputSourceChange = { [weak self] in self?.switchInputSource() }
        blocker.onEmergencyExit = { [weak self] in self?.endBlackout(terminate: false) }
        return blocker
    }()

    private let hotKeySignature: OSType = 0x424C4B54 // "BLKT"
    private let hotKeyID: UInt32 = 1

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildStatusMenu()
        buildMainMenu()
        installGlobalHotKey()
        NotificationCenter.default.addObserver(
            self, selector: #selector(languageChanged), name: .appLanguageChanged, object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(sessionDidResignActive),
            name: NSWorkspace.sessionDidResignActiveNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(sessionDidBecomeActive),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        endBlackout(terminate: false)
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let ref = hotKeyHandlerRef { RemoveEventHandler(ref) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isBlack, requiredPassword != nil {
            requestUnlock()
            return .terminateCancel
        }
        return .terminateNow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    @objc private func languageChanged() {
        // Keep the same status item; only replace its translated menu.
        statusItem?.menu = nil
        buildStatusMenu()
        buildMainMenu()
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "Blackout")
        let settingsItem = appMenu.addItem(withTitle: L("Settings…"), action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("Quit Blackout"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: L("Edit"))
        for (title, action, key) in [
            (L("Cut"), #selector(NSText.cut(_:)), "x"),
            (L("Copy"), #selector(NSText.copy(_:)), "c"),
            (L("Paste"), #selector(NSText.paste(_:)), "v"),
            (L("Select All"), #selector(NSText.selectAll(_:)), "a")
        ] {
            editMenu.addItem(withTitle: title, action: action, keyEquivalent: key)
        }
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }

    private func buildStatusMenu() {
        if statusItem == nil { statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength) }
        updateStatusIcon()

        let menu = NSMenu()
        menu.delegate = self
        let blackoutItem = NSMenuItem(title: L("Blackout Now"), action: #selector(blackoutFromMenu), keyEquivalent: "")
        blackoutItem.target = self
        menu.addItem(blackoutItem)

        let shortcutInfo = NSMenuItem(title: L("Shortcut: ⌃⌥B"), action: nil, keyEquivalent: "")
        shortcutInfo.isEnabled = false
        menu.addItem(shortcutInfo)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: L("Settings…"), action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: L("Quit Blackout"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        let protected = passwords.isEnabled
        let state = protected ? L("Password protection is on.") : L("Password protection is off.")
        button.image = makeStatusIcon(passwordProtected: protected, description: state)
        button.title = ""
        button.toolTip = "Blackout — \(state)"
        button.setAccessibilityLabel("Blackout — \(state)")
    }

    func menuWillOpen(_ menu: NSMenu) { updateStatusIcon() }

    func applicationDidBecomeActive(_ notification: Notification) {
        updateStatusIcon()
        guard isBlack, !sessionSuspended else { return }
        if let field = unlockField { panels.first?.makeFirstResponder(field) }
        refreshInputFocus()
    }

    private func installGlobalHotKey() {
        let hotKeyIDStruct = EventHotKeyID(signature: hotKeySignature, id: hotKeyID)
        let modifiers = UInt32(controlKey | optionKey)
        let result = RegisterEventHotKey(
            UInt32(kVK_ANSI_B),
            modifiers,
            hotKeyIDStruct,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard result == noErr else {
            showError(String(format: L("Could not register ⌃⌥B (error %d). Another app may already use that shortcut."), result))
            return
        }

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var pressedID = EventHotKeyID()
                let getResult = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &pressedID
                )
                guard getResult == noErr else { return getResult }

                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                if pressedID.signature == delegate.hotKeySignature && pressedID.id == delegate.hotKeyID {
                    DispatchQueue.main.async {
                        delegate.toggleBlackout()
                    }
                }
                return noErr
            },
            1,
            &eventSpec,
            pointer,
            &hotKeyHandlerRef
        )
    }

    @objc private func blackoutFromMenu() {
        beginBlackout()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func showSettings() {
        guard !isBlack else { requestUnlock(); return }
        NSApp.setActivationPolicy(.regular)
        if settings.window?.isVisible == true {
            NSApp.activate(ignoringOtherApps: true)
            settings.window?.makeKeyAndOrderFront(nil)
            return
        }
        settings.show()
    }

    private func toggleBlackout() {
        isBlack ? requestUnlock() : beginBlackout()
    }

    private func beginBlackout() {
        guard !isBlack else { return }
        settings.cancelPendingPasswordChanges()
        do {
            requiredPassword = try passwords.load()
        } catch {
            showError(error.localizedDescription)
            return
        }
        settings.close()
        guard startInputBlocking() else { requiredPassword = nil; return }
        previousPresentation = NSApp.presentationOptions
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching, .disableHideApplication]
        isBlack = true
        unlockPromptAvailableAt = ProcessInfo.processInfo.systemUptime + 0.35

        // Activate first so every per-display window is attached to the
        // currently visible Spaces before it is ordered to the front.
        NSApp.activate(ignoringOtherApps: true)
        createPanels()
        guard !panels.isEmpty else { endBlackout(terminate: false); return }
        installInputDetection()

        panels.first?.makeKeyAndOrderFront(nil)
        panels.forEach { $0.orderFrontRegardless() }

        NSCursor.hide()
        cursorHidden = true
    }

    private func createPanels() {
        destroyPanels()

        // maximumWindow is intentionally used here rather than the ordinary
        // screen-saver level. This keeps the black overlay above Dock, menu
        // bar, notification banners, and normal application/full-screen UI.
        // macOS security/login UI remains outside our control.
        let blackoutLevel = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.maximumWindow))
        )

        let screens = NSScreen.screens

        for screen in screens {
            let frame = screen.frame
            let panel = BlackoutWindow(
                contentRect: frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )

            // Explicitly set the global screen frame. This matters when a
            // secondary display is to the left/above the main display and has
            // a negative global coordinate.
            panel.setFrame(frame, display: true)
            // Only the display hosting the unlock form may take keyboard focus.
            panel.acceptsKeyboardInput = panels.isEmpty
            panel.delegate = self
            panel.backgroundColor = .black
            panel.isOpaque = true
            panel.hasShadow = false
            panel.level = blackoutLevel
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = false
            panel.acceptsMouseMovedEvents = true
            panel.isReleasedWhenClosed = false
            panel.animationBehavior = .none
            panel.tabbingMode = .disallowed
            panel.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .stationary,
                .ignoresCycle
            ]

            let blackView = NSView(frame: NSRect(origin: .zero, size: frame.size))
            blackView.wantsLayer = true
            blackView.layer?.backgroundColor = NSColor.black.cgColor
            panel.contentView = blackView

            panel.orderFrontRegardless()
            panels.append(panel)
        }
    }

    private func destroyPanels() {
        unlockField?.stringValue = ""
        unlockView = nil
        unlockField = nil
        unlockError = nil
        inputBlocker.setPrompting(false)
        panels.forEach { $0.orderOut(nil); $0.close() }
        panels.removeAll()
    }

    private func installInputDetection() {
        inputTimer?.invalidate()
        inputTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, self.isBlack, !self.sessionSuspended else { return }
            guard self.inputBlocker.isRunning, self.panels.first?.contentView != nil else {
                self.inputBlockingFailed()
                return
            }
            self.refreshInputFocus()
            self.panels.forEach { $0.orderFrontRegardless() }
        }
        RunLoop.main.add(inputTimer!, forMode: .common)
    }

    private var gracePeriodEnded: Bool {
        ProcessInfo.processInfo.systemUptime >= unlockPromptAvailableAt
    }

    private func removeInputDetection() {
        inputTimer?.invalidate()
        inputTimer = nil
        inputBlocker.stop()
    }

    private func inputBlockingFailed() {
        guard isBlack, !sessionSuspended else { return }
        endBlackout(terminate: false)
        showError(L("Input blocking stopped. Blackout has ended to avoid hiding another app while input is unprotected."))
    }

    private func startInputBlocking() -> Bool {
        guard AXIsProcessTrusted() else {
            let alert = NSAlert()
            alert.messageText = "Blackout"
            alert.informativeText = L("Input blocking requires permission to control keyboard and mouse input. Open System Settings and enable Blackout, then try again.")
            alert.addButton(withTitle: L("Open System Settings"))
            alert.addButton(withTitle: L("Cancel"))
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
            return false
        }
        guard inputBlocker.start() else {
            showError(L("Input blocking could not start. The screen has not been covered."))
            return false
        }
        return true
    }

    func applicationDidResignActive(_ notification: Notification) {
        guard isBlack, !sessionSuspended else { return }
        inputBlocker.setPrompting(unlockView != nil, acceptingInput: false)
        // Reactivate after AppKit finishes deactivation. Until then, input is consumed.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isBlack, !self.sessionSuspended else { return }
            NSApp.activate(ignoringOtherApps: true)
            self.panels.first?.makeKeyAndOrderFront(nil)
        }
    }

    func windowDidBecomeKey(_ notification: Notification) { refreshInputFocus() }
    func windowDidResignKey(_ notification: Notification) { refreshInputFocus() }

    private func refreshInputFocus() {
        guard isBlack, !sessionSuspended else { return }
        let mouseTarget = panels.first.map {
            InputBlocker.MouseTarget(windowNumber: $0.windowNumber, frame: $0.frame,
                                     desktopTop: NSScreen.screens.first?.frame.maxY ?? 0)
        }
        inputBlocker.setPrompting(unlockView != nil,
                                  acceptingInput: NSApp.isActive && panels.first?.isKeyWindow == true,
                                  mouseTarget: mouseTarget)
    }

    private func requestUnlock() {
        guard isBlack, !sessionSuspended, gracePeriodEnded else { return }
        guard requiredPassword != nil else { endBlackout(terminate: false); return }
        guard let panel = panels.first, let content = panel.contentView else {
            endBlackout(terminate: false)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        if let field = unlockField {
            panel.makeFirstResponder(field)
            refreshInputFocus()
            return
        }

        let title = NSTextField(labelWithString: L("Unlock Blackout"))
        title.font = .boldSystemFont(ofSize: 22)
        title.textColor = .white
        let field = NSSecureTextField()
        field.placeholderString = L("Password")
        field.setAccessibilityLabel(L("Unlock password"))
        field.target = self
        field.action = #selector(submitUnlock)
        let error = NSTextField(wrappingLabelWithString: L("Enter your password to restore the screen."))
        error.textColor = .white
        error.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        let unlock = NSButton(title: L("Unlock"), target: self, action: #selector(submitUnlock))
        unlock.bezelStyle = .rounded
        unlock.keyEquivalent = "\r"
        let cancel = NSButton(title: L("Cancel"), target: self, action: #selector(cancelUnlock))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [cancel, unlock])
        buttons.spacing = 12
        let stack = NSStackView(views: [title, field, error, buttons])
        let direction: NSUserInterfaceLayoutDirection = ["ar", "he"].contains(AppLanguage.currentCode) ? .rightToLeft : .leftToRight
        for view in [stack, title, field, error, buttons, cancel, unlock] {
            view.userInterfaceLayoutDirection = direction
        }
        stack.orientation = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.appearance = NSAppearance(named: .darkAqua)
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            stack.widthAnchor.constraint(equalToConstant: 320),
            field.widthAnchor.constraint(equalTo: stack.widthAnchor),
            error.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        unlockView = stack
        unlockField = field
        unlockError = error
        if cursorHidden { NSCursor.unhide(); cursorHidden = false }
        panel.makeFirstResponder(field)
        refreshInputFocus()
    }

    private func switchInputSource() {
        guard isBlack, unlockView != nil else { return }
        let filter = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as Any,
            kTISPropertyInputSourceIsSelectCapable as String: true
        ] as CFDictionary
        guard let sources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
              !sources.isEmpty, let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return }
        let currentIndex = sources.firstIndex { CFEqual($0, current) } ?? -1
        TISSelectInputSource(sources[(currentIndex + 1) % sources.count])
    }

    @objc private func submitUnlock() {
        guard isBlack, let password = requiredPassword, let field = unlockField else { return }
        guard ProcessInfo.processInfo.systemUptime >= nextUnlockAttempt else { return }
        if password.matches(field.stringValue) {
            endBlackout(terminate: false)
        } else {
            nextUnlockAttempt = ProcessInfo.processInfo.systemUptime + 1
            field.stringValue = ""
            unlockError?.stringValue = L("Incorrect password. Please wait a moment and try again.")
            panels.first?.makeFirstResponder(field)
        }
    }

    @objc private func cancelUnlock() {
        unlockField?.stringValue = ""
        unlockView?.removeFromSuperview()
        unlockView = nil
        unlockField = nil
        unlockError = nil
        inputBlocker.setPrompting(false)
        unlockPromptAvailableAt = ProcessInfo.processInfo.systemUptime + 2
        if !cursorHidden { NSCursor.hide(); cursorHidden = true }
    }

    private func endBlackout(terminate: Bool) {
        guard isBlack || !panels.isEmpty else {
            if terminate { NSApp.terminate(nil) }
            return
        }

        isBlack = false
        NSApp.presentationOptions = previousPresentation
        requiredPassword = nil
        sessionSuspended = false
        nextUnlockAttempt = 0
        removeInputDetection()
        destroyPanels()
        if cursorHidden {
            NSCursor.unhide()
            cursorHidden = false
        }
        if terminate { NSApp.terminate(nil) }
    }

    @objc private func sessionDidResignActive() {
        // Never try to sit above the macOS login/lock UI.
        guard isBlack, requiredPassword != nil else { endBlackout(terminate: false); return }
        sessionSuspended = true
        NSApp.presentationOptions = previousPresentation
        removeInputDetection()
        destroyPanels()
        if cursorHidden { NSCursor.unhide(); cursorHidden = false }
    }

    @objc private func sessionDidBecomeActive() {
        guard isBlack, sessionSuspended else { return }
        guard startInputBlocking() else { endBlackout(terminate: false); return }
        sessionSuspended = false
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching, .disableHideApplication]
        unlockPromptAvailableAt = ProcessInfo.processInfo.systemUptime + 0.35
        createPanels()
        guard !panels.isEmpty else { endBlackout(terminate: false); return }
        installInputDetection()
        panels.first?.makeKeyAndOrderFront(nil)
        if !cursorHidden { NSCursor.hide(); cursorHidden = true }
    }

    @objc private func screenConfigurationChanged() {
        guard isBlack, !sessionSuspended else { return }
        let wasPrompting = unlockView != nil
        createPanels()
        guard !panels.isEmpty else { endBlackout(terminate: false); return }
        panels.first?.makeKeyAndOrderFront(nil)
        panels.forEach { $0.orderFrontRegardless() }
        if wasPrompting { requestUnlock() }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Blackout"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
