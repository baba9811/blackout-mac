import Foundation

final class AppPreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var unlockPromptTimeout: Int {
        get {
            let value = defaults.integer(forKey: "unlockPromptTimeout")
            return (1...300).contains(value) ? value : 10
        }
        set { defaults.set(min(300, max(1, newValue)), forKey: "unlockPromptTimeout") }
    }

    var automaticallyChecksForUpdates: Bool {
        get { defaults.object(forKey: "automaticallyChecksForUpdates") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "automaticallyChecksForUpdates") }
    }
}
