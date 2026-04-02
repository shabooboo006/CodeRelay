import CodeRelayCore
import Foundation

enum CodeRelayLaunchMode: Equatable {
    case setupWindow
    case menuBar
}

enum CodeRelayMenuPresentation {
    static func launchMode(for state: AccountsFeature.State) -> CodeRelayLaunchMode {
        state.rows.isEmpty ? .setupWindow : .menuBar
    }

    static func headerTitle(for state: AccountsFeature.State) -> String {
        guard let primaryRow = self.primaryRow(in: state) else {
            return CodeRelayLocalizer.text("menu.header.noAccounts", language: state.selectedLanguage)
        }
        return primaryRow.email
    }

    static func detailLines(for state: AccountsFeature.State) -> [String] {
        guard let primaryRow = self.primaryRow(in: state) else {
            return [CodeRelayLocalizer.text("menu.detail.setupRequired", language: state.selectedLanguage)]
        }

        var lines: [String] = []
        if primaryRow.isActive, primaryRow.isLive {
            lines.append(CodeRelayLocalizer.text("menu.detail.activeAndLive", language: state.selectedLanguage))
        } else if primaryRow.isActive {
            lines.append(CodeRelayLocalizer.text("menu.detail.activeOnly", language: state.selectedLanguage))
        } else if primaryRow.isLive {
            lines.append(CodeRelayLocalizer.text("menu.detail.liveOnly", language: state.selectedLanguage))
        }

        if let fiveHourWindow = primaryRow.fiveHourWindow {
            lines.append(CodeRelayLocalizer.format(
                "menu.detail.fiveHourRemaining",
                language: state.selectedLanguage,
                CodeRelayLocalizer.formattedPercent(fiveHourWindow.remainingPercent, language: state.selectedLanguage)))
        }

        if let weeklyWindow = primaryRow.weeklyWindow {
            lines.append(CodeRelayLocalizer.format(
                "menu.detail.weeklyRemaining",
                language: state.selectedLanguage,
                CodeRelayLocalizer.formattedPercent(weeklyWindow.remainingPercent, language: state.selectedLanguage)))
        }

        lines.append(CodeRelayLocalizer.format(
            "menu.detail.status",
            language: state.selectedLanguage,
            AccountsCopy.status(primaryRow, language: state.selectedLanguage)))

        if let lastUsageRefreshAt = primaryRow.lastUsageRefreshAt {
            lines.append(CodeRelayLocalizer.format(
                "menu.detail.lastRefreshed",
                language: state.selectedLanguage,
                CodeRelayLocalizer.formattedDate(lastUsageRefreshAt, language: state.selectedLanguage)))
        }

        return lines
    }

    static func primaryRow(in state: AccountsFeature.State) -> AccountProjectionRow? {
        state.rows.first(where: { $0.isActive }) ?? state.rows.first
    }

    static func iconStatus(for state: AccountsFeature.State) -> UsageProbeStatus {
        self.primaryRow(in: state)?.usageStatus ?? .unknown
    }
}
