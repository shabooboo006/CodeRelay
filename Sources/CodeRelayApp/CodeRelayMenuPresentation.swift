import CodeRelayCore
import Foundation

enum CodeRelayLaunchMode: Equatable {
    case setupWindow
    case menuBar
}

enum CodeRelayMenuPresentation {
    struct Summary: Equatable {
        struct Badge: Equatable {
            enum Kind: Equatable {
                case active
                case live
            }

            let text: String
            let kind: Kind
        }

        struct Metric: Equatable {
            let id: String
            let title: String
            let detail: String
            let value: String
            let remainingPercent: Double
        }

        struct Detail: Equatable {
            let id: String
            let label: String
            let value: String
        }

        struct Notice: Equatable {
            let title: String
            let body: String
        }

        let iconName: String
        let title: String
        let subtitle: String
        let badges: [Badge]
        let metrics: [Metric]
        let details: [Detail]
        let notice: Notice?
    }

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

        if let activeWarning = state.activeWarning {
            lines.append(contentsOf: WarningCopy.menuLines(for: activeWarning, language: state.selectedLanguage))
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

    static func summary(for state: AccountsFeature.State) -> Summary {
        let language = state.selectedLanguage

        guard let primaryRow = self.primaryRow(in: state) else {
            return Summary(
                iconName: "tray",
                title: CodeRelayLocalizer.text("menu.header.noAccounts", language: language),
                subtitle: CodeRelayLocalizer.text("menu.detail.setupRequired", language: language),
                badges: [],
                metrics: [],
                details: [],
                notice: nil)
        }

        var badges: [Summary.Badge] = []
        if primaryRow.isActive {
            badges.append(.init(
                text: CodeRelayLocalizer.text("accounts.badge.active", language: language),
                kind: .active))
        }
        if primaryRow.isLive {
            badges.append(.init(
                text: CodeRelayLocalizer.text("accounts.badge.live", language: language),
                kind: .live))
        }

        var metrics: [Summary.Metric] = []
        if let fiveHourWindow = primaryRow.fiveHourWindow {
            metrics.append(.init(
                id: "fiveHour",
                title: CodeRelayLocalizer.text("menu.metric.session", language: language),
                detail: AccountsCopy.usage(window: fiveHourWindow, language: language),
                value: CodeRelayLocalizer.formattedPercent(fiveHourWindow.remainingPercent, language: language),
                remainingPercent: fiveHourWindow.remainingPercent))
        }
        if let weeklyWindow = primaryRow.weeklyWindow {
            metrics.append(.init(
                id: "weekly",
                title: CodeRelayLocalizer.text("menu.metric.weekly", language: language),
                detail: AccountsCopy.usage(window: weeklyWindow, language: language),
                value: CodeRelayLocalizer.formattedPercent(weeklyWindow.remainingPercent, language: language),
                remainingPercent: weeklyWindow.remainingPercent))
        }

        let details = [
            Summary.Detail(
                id: "status",
                label: CodeRelayLocalizer.text("menu.meta.status", language: language),
                value: AccountsCopy.status(primaryRow, language: language)),
            Summary.Detail(
                id: "updated",
                label: CodeRelayLocalizer.text("menu.meta.updated", language: language),
                value: AccountsCopy.lastRefreshed(primaryRow.lastUsageRefreshAt, language: language)),
        ]

        let notice: Summary.Notice?
        if let activeWarning = state.activeWarning {
            let body = [WarningCopy.summary(for: activeWarning, language: language),
                        WarningCopy.suggestionsLine(for: activeWarning, language: language)]
                .compactMap { $0 }
                .joined(separator: " ")
            notice = .init(
                title: WarningCopy.sectionTitle(for: activeWarning, language: language),
                body: body)
        } else {
            notice = nil
        }

        return Summary(
            iconName: primaryRow.isActive ? "bolt.horizontal.circle.fill" : "person.crop.circle",
            title: primaryRow.email,
            subtitle: self.primarySubtitle(for: primaryRow, language: language),
            badges: badges,
            metrics: metrics,
            details: details,
            notice: notice)
    }

    static func primaryRow(in state: AccountsFeature.State) -> AccountProjectionRow? {
        state.rows.first(where: { $0.isActive }) ?? state.rows.first
    }

    static func iconStatus(for state: AccountsFeature.State) -> UsageProbeStatus {
        self.primaryRow(in: state)?.usageStatus ?? .unknown
    }

    private static func primarySubtitle(for row: AccountProjectionRow, language: AppLanguage) -> String {
        if row.isActive, row.isLive {
            return CodeRelayLocalizer.text("menu.detail.activeAndLive", language: language)
        }
        if row.isActive {
            return CodeRelayLocalizer.text("menu.detail.activeOnly", language: language)
        }
        if row.isLive {
            return CodeRelayLocalizer.text("menu.detail.liveOnly", language: language)
        }
        return CodeRelayLocalizer.supportLabel(row.supportState, language: language)
    }
}
