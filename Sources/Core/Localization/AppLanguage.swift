import Foundation

extension Notification.Name {
    static let appLanguageChanged = Notification.Name("BlackoutAppLanguageChanged")
}

enum AppLanguage {
    static let defaultsKey = "appLanguage"
    static let supported: [(code: String, name: String)] = [
        ("en", "English"), ("ko", "한국어"), ("ja", "日本語"),
        ("zh-Hans", "简体中文"), ("zh-Hant", "繁體中文"), ("es", "Español"),
        ("fr", "Français"), ("de", "Deutsch"), ("it", "Italiano"),
        ("pt-BR", "Português (Brasil)"), ("pt-PT", "Português (Portugal)"),
        ("ru", "Русский"), ("uk", "Українська"), ("pl", "Polski"), ("nl", "Nederlands"),
        ("sv", "Svenska"), ("da", "Dansk"), ("nb", "Norsk bokmål"), ("fi", "Suomi"),
        ("cs", "Čeština"), ("sk", "Slovenčina"), ("hu", "Magyar"), ("ro", "Română"),
        ("tr", "Türkçe"), ("ar", "العربية"), ("he", "עברית"), ("hi", "हिन्दी"),
        ("th", "ไทย"), ("vi", "Tiếng Việt"), ("id", "Bahasa Indonesia"),
        ("ms", "Bahasa Melayu"), ("el", "Ελληνικά")
    ]

    static var selection: String {
        get {
            let value = UserDefaults.standard.string(forKey: defaultsKey) ?? "system"
            return supported.contains { $0.code == value } ? value : "system"
        }
        set {
            if supported.contains(where: { $0.code == newValue }) {
                UserDefaults.standard.set(newValue, forKey: defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            }
            NotificationCenter.default.post(name: .appLanguageChanged, object: nil)
        }
    }

    static var currentCode: String {
        resolvedCode(override: selection, preferredLanguages: Locale.preferredLanguages)
    }

    static func resolvedCode(override: String?, preferredLanguages: [String]) -> String {
        if let override, supported.contains(where: { $0.code == override }) { return override }
        return Bundle.preferredLocalizations(
            from: supported.map(\.code), forPreferences: preferredLanguages
        ).first ?? "en"
    }

    static func localized(_ key: String, code: String, bundle: Bundle = .main) -> String {
        let english = bundle.path(forResource: "en", ofType: "lproj")
            .flatMap(Bundle.init(path:))?.localizedString(forKey: key, value: key, table: nil) ?? key
        return bundle.path(forResource: code, ofType: "lproj")
            .flatMap(Bundle.init(path:))?.localizedString(forKey: key, value: english, table: nil) ?? english
    }
}

func L(_ key: String) -> String {
    AppLanguage.localized(key, code: AppLanguage.currentCode)
}
