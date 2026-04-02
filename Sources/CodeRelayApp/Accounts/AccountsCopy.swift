import CodeRelayCore
import Foundation

enum AccountsCopy {
    static func lastAuthenticated(_ date: Date?, language: AppLanguage) -> String {
        guard let date else {
            return CodeRelayLocalizer.text("accounts.lastAuthenticated.unavailable", language: language)
        }
        return CodeRelayLocalizer.format(
            "accounts.lastAuthenticated.value",
            language: language,
            CodeRelayLocalizer.formattedDate(date, language: language))
    }

    static func usage(window: RateWindow?, language: AppLanguage) -> String {
        guard let window else {
            return CodeRelayLocalizer.text("accounts.usage.unavailable", language: language)
        }

        let used = CodeRelayLocalizer.formattedPercent(window.usedPercent, language: language)
        let remaining = CodeRelayLocalizer.formattedPercent(window.remainingPercent, language: language)
        let reset = self.reset(window, language: language)

        if reset.isEmpty {
            return CodeRelayLocalizer.format(
                "accounts.usage.summary.noReset",
                language: language,
                used,
                remaining)
        }

        return CodeRelayLocalizer.format(
            "accounts.usage.summary.withReset",
            language: language,
            used,
            remaining,
            reset)
    }

    static func reset(_ window: RateWindow, language: AppLanguage) -> String {
        let description = window.resetDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description?.isEmpty == false ? description : nil

        if let trimmedDescription,
           let date = window.resetsAt
        {
            return "\(trimmedDescription) (\(CodeRelayLocalizer.formattedDate(date, language: language)))"
        }

        if let trimmedDescription {
            return trimmedDescription
        }

        if let date = window.resetsAt {
            return CodeRelayLocalizer.formattedDate(date, language: language)
        }

        return ""
    }

    static func lastRefreshed(_ date: Date?, language: AppLanguage) -> String {
        guard let date else {
            return CodeRelayLocalizer.text("accounts.usage.unavailable", language: language)
        }
        return CodeRelayLocalizer.formattedDate(date, language: language)
    }

    static func source(_ source: UsageProbeSource, language: AppLanguage) -> String {
        CodeRelayLocalizer.usageSourceLabel(source, language: language)
    }

    static func status(_ row: AccountProjectionRow, language: AppLanguage) -> String {
        let status = CodeRelayLocalizer.usageStatusLabel(row.usageStatus, language: language)
        guard let error = row.usageErrorDescription,
              !error.isEmpty,
              row.usageStatus != .fresh
        else {
            return status
        }
        return CodeRelayLocalizer.format("accounts.status.withReason", language: language, status, error)
    }

    static func readiness(_ row: AccountProjectionRow, language: AppLanguage) -> String {
        guard let readiness = row.alternateReadiness else {
            return CodeRelayLocalizer.text("accounts.readiness.unavailable", language: language)
        }

        switch (readiness.fiveHourRemainingPercent, readiness.weeklyRemainingPercent) {
        case let (fiveHour?, weekly?):
            return CodeRelayLocalizer.format(
                "accounts.readiness.both",
                language: language,
                CodeRelayLocalizer.formattedPercent(fiveHour, language: language),
                CodeRelayLocalizer.formattedPercent(weekly, language: language))
        case let (fiveHour?, nil):
            return CodeRelayLocalizer.format(
                "accounts.readiness.fiveHour",
                language: language,
                CodeRelayLocalizer.formattedPercent(fiveHour, language: language))
        case let (nil, weekly?):
            return CodeRelayLocalizer.format(
                "accounts.readiness.weekly",
                language: language,
                CodeRelayLocalizer.formattedPercent(weekly, language: language))
        default:
            return CodeRelayLocalizer.text("accounts.readiness.\(readiness.status.rawValue)", language: language)
        }
    }
}
