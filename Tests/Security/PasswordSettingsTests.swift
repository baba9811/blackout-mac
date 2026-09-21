import Foundation

@main
struct PasswordSettingsTests {
    static func main() throws {
        let suite = "local.blackout.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = PasswordSettings(defaults: defaults)
        func check(_ condition: @autoclosure () throws -> Bool) throws {
            let result = try condition()
            assert(result)
        }
        func rejected(_ operation: () throws -> Void) {
            do { try operation(); fatalError("Expected rejection") } catch { }
        }

        // Independent hashlib.pbkdf2_hmac SHA-256 vector, 600,000 rounds.
        let vectorHex = "cae9c801374596f17de48ba4ed7061692b5d0ab433932a7d3cdf698dfd8bb3e8"
        let vectorBytes = stride(from: 0, to: vectorHex.count, by: 2).map { offset -> UInt8 in
            let start = vectorHex.index(vectorHex.startIndex, offsetBy: offset)
            let end = vectorHex.index(start, offsetBy: 2)
            return UInt8(vectorHex[start..<end], radix: 16)!
        }
        assert(UnlockPassword(salt: Data(0..<16), digest: Data(vectorBytes)).matches("test-password"))
        let normalized = try UnlockPassword.create("café")
        assert(normalized.matches("cafe\u{301}"))
        let withNull = try UnlockPassword.create("before\0after")
        assert(!withNull.matches("before"))
        assert(withNull.matches("before\0after"))
        rejected { _ = try UnlockPassword.create(String(repeating: "x", count: 1_025)) }

        assert(!settings.isEnabled)
        try check(try settings.load() == nil)
        rejected { try settings.update(enabled: true, current: "", new: "", confirmation: "") }
        rejected { try settings.update(enabled: true, current: "", new: "secret", confirmation: "different") }
        assert(!settings.isEnabled)
        try settings.update(enabled: true, current: "", new: "비밀 🔑", confirmation: "비밀 🔑")
        let original = try settings.load()!
        assert(original.matches("비밀 🔑"))
        assert(!original.matches("wrong"))
        assert(!original.matches(""))
        assert(!String(data: defaults.data(forKey: PasswordSettings.key)!, encoding: .utf8)!.contains("비밀"))
        let samePassword = try UnlockPassword.create("비밀 🔑")
        assert(original.salt != samePassword.salt)
        assert(original.digest != samePassword.digest)
        let reloaded = PasswordSettings(defaults: UserDefaults(suiteName: suite)!)
        try check(try reloaded.load()!.matches("비밀 🔑"))
        rejected { try settings.update(enabled: false, current: "wrong", new: "", confirmation: "") }
        rejected { try settings.update(enabled: true, current: "wrong", new: "changed", confirmation: "changed") }
        try check(try settings.load()!.matches("비밀 🔑"))
        try settings.update(enabled: true, current: "비밀 🔑", new: "changed", confirmation: "changed")
        try check(try settings.load()!.matches("changed"))
        rejected { try settings.update(enabled: true, current: "changed", new: "", confirmation: "") }
        try check(try settings.load()!.matches("changed"))
        try check(try !settings.load()!.matches("비밀 🔑"))
        // An active blackout retains its original credential until unlocked.
        assert(original.matches("비밀 🔑"))
        try settings.update(enabled: false, current: "changed", new: "", confirmation: "")
        assert(!settings.isEnabled)
        defaults.set(Data("broken".utf8), forKey: PasswordSettings.key)
        assert(settings.isEnabled)
        rejected { _ = try settings.load() }
        defaults.set("wrong type", forKey: PasswordSettings.key)
        rejected { _ = try settings.load() }
        defaults.set(try JSONEncoder().encode(UnlockPassword(salt: Data(), digest: Data())), forKey: PasswordSettings.key)
        rejected { _ = try settings.load() }

        // Owner-authenticated recovery clears even corrupt credentials, leaving other preferences intact.
        defaults.set("ko", forKey: "appLanguage")
        defaults.set(true, forKey: "unrelatedPreference")
        for damaged: Any in [Data("broken".utf8), "wrong type"] {
            defaults.set(damaged, forKey: PasswordSettings.key)
            assert(settings.resetAfterOwnerAuthentication(ifUnchanged: settings.revision))
            assert(!settings.isEnabled)
            try check(try settings.load() == nil)
            assert(defaults.string(forKey: "appLanguage") == "ko")
            assert(defaults.bool(forKey: "unrelatedPreference"))
        }
        try settings.update(enabled: true, current: "", new: "forgotten", confirmation: "forgotten")
        let pendingResetRevision = settings.revision
        try settings.update(enabled: true, current: "forgotten", new: "newer", confirmation: "newer")
        assert(!settings.resetAfterOwnerAuthentication(ifUnchanged: pendingResetRevision))
        try check(try settings.load()!.matches("newer"))
        assert(settings.resetAfterOwnerAuthentication(ifUnchanged: settings.revision))
        assert(!settings.isEnabled)
        assert(defaults.string(forKey: "appLanguage") == "ko")
        assert(defaults.bool(forKey: "unrelatedPreference"))
        try settings.update(enabled: true, current: "", new: "fresh", confirmation: "fresh")
        try check(try settings.load()!.matches("fresh"))
        print("Password settings checks passed")
    }
}
