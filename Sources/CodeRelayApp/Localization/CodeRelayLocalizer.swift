import CodeRelayCodex
import CodeRelayCore
import Foundation

public enum AppLanguage: String, CaseIterable, Equatable, Sendable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    public static let defaultValue: Self = .simplifiedChinese

    public var id: String {
        self.rawValue
    }
}

public enum CodeRelayLocalizer {
    public static func text(_ key: String, language: AppLanguage) -> String {
        let primary = self.localizedString(key, bundle: self.bundle(for: language))
        if primary != key {
            return primary
        }
        return self.localizedString(key, bundle: .module)
    }

    public static func format(_ key: String, language: AppLanguage, _ arguments: CVarArg...) -> String {
        String(format: self.text(key, language: language), locale: self.locale(for: language), arguments: arguments)
    }

    public static func languageOptionLabel(_ option: AppLanguage, language: AppLanguage) -> String {
        self.text("app.language.option.\(option.rawValue)", language: language)
    }

    public static func supportLabel(_ state: AccountSupportState, language: AppLanguage) -> String {
        let kind = self.text("accounts.supportKind.\(state.kind.rawValue)", language: language)
        guard let reason = state.reason?.trimmingCharacters(in: .whitespacesAndNewlines),
              !reason.isEmpty
        else {
            return self.format("accounts.support.value", language: language, kind)
        }
        return self.format("accounts.support.withReason", language: language, kind, reason)
    }

    public static func usageSourceLabel(_ source: UsageProbeSource, language: AppLanguage) -> String {
        switch source {
        case .managedHomeOAuth:
            return self.text("accounts.source.managedHomeOAuth", language: language)
        case .cache:
            return self.text("accounts.source.cache", language: language)
        case .unknown:
            return self.text("accounts.source.unknown", language: language)
        }
    }

    public static func usageStatusLabel(_ status: UsageProbeStatus, language: AppLanguage) -> String {
        self.text("accounts.status.\(status.rawValue)", language: language)
    }

    public static func formattedDate(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = self.locale(for: language)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    public static func formattedPercent(_ value: Double, language: AppLanguage) -> String {
        let formatter = NumberFormatter()
        formatter.locale = self.locale(for: language)
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        formatter.multiplier = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))%"
    }

    private static func bundle(for language: AppLanguage) -> Bundle {
        for candidate in self.localizationFolderCandidates(for: language) {
            if let path = Bundle.module.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path)
            {
                return bundle
            }
        }
        return .module
    }

    private static func locale(for language: AppLanguage) -> Locale {
        Locale(identifier: language.rawValue)
    }

    private static func localizedString(_ key: String, bundle: Bundle) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: bundle, value: key, comment: key)
    }

    private static func localizationFolderCandidates(for language: AppLanguage) -> [String] {
        let rawValue = language.rawValue
        let lowercase = rawValue.lowercased()
        let underscore = rawValue.replacingOccurrences(of: "-", with: "_")
        let lowercaseUnderscore = lowercase.replacingOccurrences(of: "-", with: "_")
        var candidates: [String] = []

        for candidate in [rawValue, lowercase, underscore, lowercaseUnderscore] where !candidates.contains(candidate) {
            candidates.append(candidate)
        }

        return candidates
    }
}
