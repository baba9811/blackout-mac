import AppKit

private final class UpdateProtocol: URLProtocol {
    static var requests = 0
    static var body = "[]"
    static var status = 200
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests += 1
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: Self.status,
                                                            httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
struct UpdatePreferencesTests {
    @MainActor static func main() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let suite = "local.blackout.preference-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = AppPreferences(defaults: defaults)
        assert(preferences.unlockPromptTimeout == 10 && preferences.automaticallyChecksForUpdates)
        defaults.set(999, forKey: "unlockPromptTimeout")
        assert(preferences.unlockPromptTimeout == 10)
        preferences.unlockPromptTimeout = 0
        assert(preferences.unlockPromptTimeout == 1)
        preferences.unlockPromptTimeout = 999
        assert(preferences.unlockPromptTimeout == 300)
        preferences.unlockPromptTimeout = 30
        preferences.automaticallyChecksForUpdates = false
        let reloaded = AppPreferences(defaults: defaults)
        assert(reloaded.unlockPromptTimeout == 30 && !reloaded.automaticallyChecksForUpdates)
        let verifier = Data([1, 2, 3])
        defaults.set(verifier, forKey: PasswordSettings.key)
        defaults.set("ko", forKey: "appLanguage")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UpdateProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let controller = SettingsWindowController(passwords: PasswordSettings(defaults: defaults), preferences: preferences,
                                                  currentVersion: "1.0.0", releaseSession: session)
        func descendants(_ view: NSView) -> [NSView] {
            let children = (view as? NSStackView)?.arrangedSubviews ?? view.subviews
            return children + children.flatMap(descendants)
        }
        let views = descendants(controller.window!.contentView!)
        let buttons = views.compactMap { $0 as? NSButton }
        let automatic = buttons.first { $0.title == L("Automatically check for updates") }!
        let check = buttons.first { $0.title == L("Check for Updates…") }!
        let download = buttons.first { $0.title == L("Download Update…") }!
        let timeout = views.compactMap { $0 as? NSPopUpButton }.first {
            $0.accessibilityLabel() == L("Hide the password prompt after inactivity")
        }!
        assert(timeout.selectedItem?.representedObject as? Int == 30)
        timeout.select(timeout.itemArray.first { $0.representedObject as? Int == 60 })
        timeout.sendAction(timeout.action, to: timeout.target)
        assert(reloaded.unlockPromptTimeout == 60)
        controller.checkForUpdatesAutomatically()
        await Task.yield()
        assert(UpdateProtocol.requests == 0, "Automatic checks must respect the saved opt-out")
        var notices = 0
        controller.onUpdateAvailable = { notices += 1 }
        UpdateProtocol.body = """
        [{"tag_name":"v1.1.0","draft":false,"html_url":"https://github.com/baba9811/blackout-mac/releases/tag/v1.1.0",
          "assets":[{"name":"BlackoutMac-1.1.0-universal.dmg","size":3,"browser_download_url":"https://github.com/baba9811/blackout-mac/releases/download/v1.1.0/BlackoutMac-1.1.0-universal.dmg"},
                    {"name":"SHA256SUMS","size":196,"browser_download_url":"https://github.com/baba9811/blackout-mac/releases/download/v1.1.0/SHA256SUMS"}]}]
        """
        func finishCheck() async {
            for _ in 0..<200 {
                if check.isEnabled { return }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            fatalError("Update check did not finish")
        }
        automatic.state = .on
        automatic.sendAction(automatic.action, to: automatic.target)
        await finishCheck()
        assert(reloaded.automaticallyChecksForUpdates && notices == 1 && !download.isHidden)
        controller.checkForUpdatesAutomatically()
        await Task.yield()
        assert(UpdateProtocol.requests == 1, "Do not poll GitHub every timer tick")
        controller.checkForUpdatesAutomatically(now: Date().addingTimeInterval(86_401))
        await finishCheck()
        assert(UpdateProtocol.requests == 2 && notices == 1, "Notify once per version per launch")
        check.performClick(nil)
        await finishCheck()
        assert(UpdateProtocol.requests == 3 && notices == 1, "Manual checks work without another automatic notice")
        automatic.state = .off
        automatic.sendAction(automatic.action, to: automatic.target)
        UpdateProtocol.status = 403
        check.performClick(nil)
        await finishCheck()
        assert(UpdateProtocol.requests == 4 && notices == 1 && download.isHidden)
        let fallback = buttons.first { $0.title == L("Open Release Page…") }!
        assert(!fallback.isHidden && !reloaded.automaticallyChecksForUpdates,
               "API limits must leave a manual fallback, even with automatic checks disabled")
        controller.window!.setContentSize(NSSize(width: 520, height: 480))
        let originalLanguage = AppLanguage.selection
        defer { AppLanguage.selection = originalLanguage }
        let translations = Bundle(url: URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true))!
        for code in ["de", "ar", "he"] {
            AppLanguage.selection = code
            let direction: NSUserInterfaceLayoutDirection = code == "de" ? .leftToRight : .rightToLeft
            assert(controller.window!.contentView!.userInterfaceLayoutDirection == direction)
            for label in views.compactMap({ $0 as? NSTextField }) where label.cell?.wraps == true {
                label.stringValue = String(repeating: AppLanguage.localized("Hide the password prompt after inactivity",
                                                                            code: code, bundle: translations) + " ", count: 4)
            }
            automatic.title = AppLanguage.localized("Automatically check for updates", code: code, bundle: translations)
            controller.window!.contentView!.layoutSubtreeIfNeeded()
            assert(automatic.frame.height >= automatic.intrinsicContentSize.height && timeout.frame.width > 0,
                   "\(code): checkbox \(automatic.frame), intrinsic \(automatic.intrinsicContentSize); timeout \(timeout.frame)")
            for label in views.compactMap({ $0 as? NSTextField }) where label.cell?.wraps == true && !label.isHidden {
                assert(label.frame.height > 0 && label.alignment == (direction == .rightToLeft ? .right : .left))
            }
        }
        controller.window!.contentView!.layoutSubtreeIfNeeded()
        assert(timeout.frame.width > 0 && timeout.frame.height > 0)
        assert(defaults.data(forKey: PasswordSettings.key) == verifier && defaults.string(forKey: "appLanguage") == "ko")
        assert(!controller.window!.isVisible, "Checks must not open windows without app orchestration")
        print("Preference checks passed: persistence, timeout selection, opt-out, daily checks, notices and saved-data preservation.")
    }
}
