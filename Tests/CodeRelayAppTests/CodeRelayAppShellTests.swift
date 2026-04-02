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
