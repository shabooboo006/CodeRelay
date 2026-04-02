import CodeRelayCore
import Foundation
import Testing
@testable import CodeRelayApp

@Suite struct CodeRelayAppShellTests {
    @Test
    func menuPresentation_usesSetupLaunchModeWithoutAccounts() {
        let state = AccountsFeature.State(selectedLanguage: .english)

        #expect(CodeRelayMenuPresentation.launchMode(for: state) == .setupWindow)
        #expect(CodeRelayMenuPresentation.headerTitle(for: state) == "No managed accounts")
        #expect(CodeRelayMenuPresentation.detailLines(for: state) == [
            "Open setup to add the first managed Codex account."
        ])

        let summary = CodeRelayMenuPresentation.summary(for: state)
        #expect(summary.title == "No managed accounts")
        #expect(summary.subtitle == "Open setup to add the first managed Codex account.")
        #expect(summary.metrics.isEmpty)
    }

    @Test
    func menuPresentation_prefersActiveAccountDetails() {
        let row = AccountProjectionRow(
            id: UUID(),
            email: "active@example.com",
            isActive: true,
            isLive: true,
            supportState: .supported,
            lastAuthenticatedAt: nil,
            fiveHourWindow: RateWindow(
                usedPercent: 25,
                windowMinutes: 300,
                resetsAt: nil,
                resetDescription: nil),
            weeklyWindow: RateWindow(
                usedPercent: 60,
                windowMinutes: 10_080,
                resetsAt: nil,
                resetDescription: nil),
            lastUsageRefreshAt: Date(timeIntervalSince1970: 1_700_000_000),
            usageSource: .managedHomeOAuth,
            usageStatus: .fresh,
            usageErrorDescription: nil,
            alternateReadiness: nil)
        let state = AccountsFeature.State(rows: [row], selectedLanguage: .english)

        #expect(CodeRelayMenuPresentation.launchMode(for: state) == .menuBar)
        #expect(CodeRelayMenuPresentation.headerTitle(for: state) == "active@example.com")
        #expect(CodeRelayMenuPresentation.detailLines(for: state).contains("Active in CodeRelay and matches the live Codex login."))
        #expect(CodeRelayMenuPresentation.detailLines(for: state).contains("5-hour remaining: 75%"))
        #expect(CodeRelayMenuPresentation.detailLines(for: state).contains("Weekly remaining: 40%"))

        let summary = CodeRelayMenuPresentation.summary(for: state)
        #expect(summary.title == "active@example.com")
        #expect(summary.subtitle == "Active in CodeRelay and matches the live Codex login.")
        #expect(summary.badges.map(\.text) == ["Active", "Live"])
        #expect(summary.metrics.map(\.title) == ["Session", "Weekly"])
        #expect(summary.metrics.map(\.value) == ["75%", "40%"])
    }

    @Test
    func menuPresentation_includesWarningSummaryAndAlternates() {
        let row = AccountProjectionRow(
            id: UUID(),
            email: "active@example.com",
            isActive: true,
            isLive: false,
            supportState: .supported,
            lastAuthenticatedAt: nil,
            fiveHourWindow: RateWindow(
                usedPercent: 85,
                windowMinutes: 300,
                resetsAt: nil,
                resetDescription: nil),
            weeklyWindow: RateWindow(
                usedPercent: 35,
                windowMinutes: 10_080,
                resetsAt: nil,
                resetDescription: nil),
            lastUsageRefreshAt: nil,
            usageSource: .managedHomeOAuth,
            usageStatus: .fresh,
            usageErrorDescription: nil,
            alternateReadiness: nil)
        let warning = ActiveWarning(
            activeAccountID: row.id,
            activeAccountEmail: row.email,
            severity: .thresholdBreached,
            cause: .fiveHour,
            thresholdPercent: 20,
            suggestions: [
                WarningSuggestedAccount(
                    id: UUID(),
                    email: "backup@example.com",
                    fiveHourRemainingPercent: 70,
                    weeklyRemainingPercent: 80,
                    lastRefreshedAt: nil,
                    lastAuthenticatedAt: nil)
            ])
        let state = AccountsFeature.State(
            rows: [row],
            selectedLanguage: .english,
            activeWarning: warning)

        let lines = CodeRelayMenuPresentation.detailLines(for: state)
        let summary = CodeRelayMenuPresentation.summary(for: state)

        #expect(lines.contains("Warning: 5-hour remaining is at or below 20%."))
        #expect(lines.contains("Suggested alternates: backup@example.com"))
        #expect(summary.notice?.title == "Low-usage warning")
        #expect(summary.notice?.body.contains("Suggested alternates: backup@example.com") == true)
    }

    @MainActor
    @Test
    func statusIconRenderer_returnsTemplateMenuBarImage() {
        let image = CodeRelayStatusIconRenderer.makeIcon(hasAccounts: true, status: .fresh, isBusy: false)

        #expect(image.isTemplate)
        #expect(image.size.width == 18)
        #expect(image.size.height == 18)
    }
}
