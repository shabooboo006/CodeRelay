import CodeRelayCore
import Foundation

enum WarningCopy {
    static func sectionTitle(for warning: ActiveWarning, language: AppLanguage) -> String {
        let key = switch warning.severity {
        case .thresholdBreached:
            "warnings.title.thresholdBreached"
        case .monitoringRisk:
            "warnings.title.monitoringRisk"
        }
        return CodeRelayLocalizer.text(key, language: language)
    }

    static func summary(for warning: ActiveWarning, language: AppLanguage) -> String {
        let thresholdPercent = Int(warning.thresholdPercent)
        let key = switch warning.cause {
        case .fiveHour:
            "warnings.summary.fiveHour"
        case .weekly:
            "warnings.summary.weekly"
        case .both:
            "warnings.summary.both"
        case .stale:
            "warnings.summary.stale"
        case .error:
            "warnings.summary.error"
        case .unknown:
            "warnings.summary.unknown"
        }

        switch warning.cause {
        case .fiveHour, .weekly, .both:
            return CodeRelayLocalizer.format(key, language: language, thresholdPercent)
        case .stale, .error, .unknown:
            return CodeRelayLocalizer.text(key, language: language)
        }
    }

    static func notificationTitle(for warning: ActiveWarning, language: AppLanguage) -> String {
        CodeRelayLocalizer.format(
            "warnings.notification.title",
            language: language,
            warning.activeAccountEmail)
    }

    static func notificationBody(for warning: ActiveWarning, language: AppLanguage) -> String {
        let causeSummary = self.summary(for: warning, language: language)
        guard let suggestionsLine = self.suggestionsLine(for: warning, language: language) else {
            return causeSummary
        }
        return "\(causeSummary) \(suggestionsLine)"
    }

    static func suggestionsLine(for warning: ActiveWarning, language: AppLanguage) -> String? {
        guard warning.severity == .thresholdBreached else {
            return nil
        }

        let suggestedEmails = warning.suggestions.prefix(2).map(\.email)
        guard !suggestedEmails.isEmpty else {
            return CodeRelayLocalizer.text("warnings.suggestions.none", language: language)
        }

        return CodeRelayLocalizer.format(
            "warnings.suggestions.some",
            language: language,
            suggestedEmails.joined(separator: ", "))
    }

    static func menuLines(for warning: ActiveWarning, language: AppLanguage) -> [String] {
        var lines = [
            CodeRelayLocalizer.format(
                "menu.detail.warning",
                language: language,
                self.summary(for: warning, language: language))
        ]

        if let suggestionsLine = self.suggestionsLine(for: warning, language: language) {
            lines.append(suggestionsLine)
        }

        return lines
    }

    static func refreshCadenceLabel(_ cadence: WarningRefreshCadence, language: AppLanguage) -> String {
        CodeRelayLocalizer.text("warnings.refreshCadence.\(cadence.rawValue)", language: language)
    }
}
