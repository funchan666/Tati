import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english = "en", chinese = "zh-Hans", spanish = "es"
    case french = "fr", german = "de", japanese = "ja"

    var id: String { rawValue }
    var nativeName: String {
        switch self {
        case .system: return "System default"
        case .english: return "English"
        case .chinese: return "简体中文"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .japanese: return "日本語"
        }
    }
    static func preference(_ saved: String?) -> Self {

        guard let saved else { return .english }
        if let language = Self(rawValue: saved) { return language }

        return allCases.first { $0.nativeName == saved } ?? .english
    }
    var resolved: Self {
        guard self == .system else { return self }
        for code in Locale.preferredLanguages {
            if code.hasPrefix("zh") { return .chinese }
            if let language = Self(rawValue: String(code.prefix(2))), language != .system { return language }
        }
        return .english
    }
    var locale: Locale { Locale(identifier: resolved.rawValue) }

    func text(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: resolved.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }
}
