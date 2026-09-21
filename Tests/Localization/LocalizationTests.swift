import Foundation

// Run: swiftc Sources/Core/Localization/AppLanguage.swift Tests/Localization/LocalizationTests.swift -o /tmp/blackout-localization-tests && /tmp/blackout-localization-tests Resources/Localization
@main
struct LocalizationTests {
    static func main() throws {
        assert(AppLanguage.resolvedCode(override: nil, preferredLanguages: ["ko-KR"]) == "ko")
        assert(AppLanguage.resolvedCode(override: nil, preferredLanguages: ["es-MX"]) == "es")
        assert(AppLanguage.resolvedCode(override: nil, preferredLanguages: ["zh-TW"]) == "zh-Hant")
        assert(AppLanguage.resolvedCode(override: nil, preferredLanguages: ["zh-CN"]) == "zh-Hans")
        assert(AppLanguage.resolvedCode(override: nil, preferredLanguages: ["zh-HK"]) == "zh-Hant")
        assert(AppLanguage.resolvedCode(override: nil, preferredLanguages: ["zh-Hans-US"]) == "zh-Hans")
        assert(AppLanguage.resolvedCode(override: nil, preferredLanguages: ["pt-AO"]) == "pt-PT")
        assert(AppLanguage.resolvedCode(override: nil, preferredLanguages: ["no-NO"]) == "nb")
        assert(AppLanguage.resolvedCode(override: nil, preferredLanguages: ["pt-PT"]) == "pt-PT")
        assert(AppLanguage.resolvedCode(override: nil, preferredLanguages: ["pt-BR"]) == "pt-BR")
        assert(AppLanguage.resolvedCode(override: "ja", preferredLanguages: ["ko-KR"]) == "ja")
        assert(AppLanguage.resolvedCode(override: "invalid", preferredLanguages: ["ko-KR"]) == "ko")
        assert(AppLanguage.resolvedCode(override: "system", preferredLanguages: ["zz", "fr-CA"]) == "fr")
        assert(AppLanguage.resolvedCode(override: nil, preferredLanguages: ["zz"]) == "en")
        assert(AppLanguage.resolvedCode(override: nil, preferredLanguages: []) == "en")

        // This command-line test has its own defaults domain, separate from Blackout.app.
        let defaults = UserDefaults.standard
        let previousSelection = defaults.object(forKey: AppLanguage.defaultsKey)
        defer {
            if let previousSelection { defaults.set(previousSelection, forKey: AppLanguage.defaultsKey) }
            else { defaults.removeObject(forKey: AppLanguage.defaultsKey) }
        }
        AppLanguage.selection = "ja"
        assert(defaults.string(forKey: AppLanguage.defaultsKey) == "ja")
        assert(AppLanguage.currentCode == "ja")
        AppLanguage.selection = "invalid"
        assert(AppLanguage.selection == "system")
        assert(defaults.object(forKey: AppLanguage.defaultsKey) == nil)

        let resources = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/Localization")
        func strings(_ code: String) throws -> [String: String] {
            let data = try Data(contentsOf: resources.appendingPathComponent("\(code).lproj/Localizable.strings"))
            return try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: String]
        }
        let english = try strings("en")
        assert(english.count >= 50)
        let format = try NSRegularExpression(pattern: "%[@d]")
        func placeholders(_ value: String) -> [String] {
            format.matches(in: value, range: NSRange(value.startIndex..., in: value)).map {
                String(value[Range($0.range, in: value)!])
            }.sorted()
        }
        assert(AppLanguage.supported.count == 32)
        for language in AppLanguage.supported {
            let translations = try strings(language.code)
            assert(Set(translations.keys) == Set(english.keys), "Missing translations: \(language.code)")
            if language.code != "en" {
                // Italian “Password” is also the normal Italian word.
                assert(translations.filter { $0.key != $0.value }.count >= english.count - 1)
            }
            for (key, value) in translations {
                assert(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                assert(placeholders(key) == placeholders(value), "Invalid format: \(language.code): \(key)")
            }
        }
        let sources = resources.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources")
        let literal = try NSRegularExpression(pattern: #"L\("([^"\\]*(?:\\.[^"\\]*)*)"\)"#)
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)!
        for case let url as URL in files where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            for match in literal.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
                let key = String(source[Range(match.range(at: 1), in: source)!])
                assert(english[key] != nil, "Missing source key: \(key)")
            }
        }
        let bundle = Bundle(url: resources)!
        assert(AppLanguage.localized("Settings…", code: "ko", bundle: bundle) == "설정…")
        assert(AppLanguage.localized("Settings…", code: "missing", bundle: bundle) == "Settings…")
        assert(AppLanguage.localized("Unknown key", code: "ko", bundle: bundle) == "Unknown key")
        print("Localization checks passed: 32 languages, \(english.count) keys each, OS matching and English fallback.")
    }
}
