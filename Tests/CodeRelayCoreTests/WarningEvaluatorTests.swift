import CodeRelayCore
import Foundation
import Testing

@Suite struct WarningEvaluatorTests {
    @Test
    func thresholdBreach_notifiesOnceForFreshFiveHourDrop() {
        let active = Self.makeRow(
            email: "active@example.com",
            isActive: true,
            fiveHourRemaining: 15,
            weeklyRemaining: 55,
            usageStatus: .fresh)
        let evaluator = DefaultWarningEvaluator()

        let first = evaluator.evaluate(
            activeRow: active,
            alternateRows: [],
            preferences: Self.breachPreferences,
            notificationState: WarningNotificationState())

        #expect(first.warning?.severity == .thresholdBreached)
        #expect(first.warning?.cause == .fiveHour)
        #expect(first.shouldNotify)
        #expect(first.notificationState.suppressedAccountIDs.contains(active.id))

        let second = evaluator.evaluate(
            activeRow: active,
            alternateRows: [],
            preferences: Self.breachPreferences,
            notificationState: first.notificationState)

        #expect(second.warning?.severity == .thresholdBreached)
        #expect(second.shouldNotify == false)
    }

    @Test
    func thresholdBreach_respectsNotificationsDisabled() {
        let active = Self.makeRow(
            email: "active@example.com",
            isActive: true,
            fiveHourRemaining: 20,
            weeklyRemaining: 55,
            usageStatus: .fresh)

        let result = DefaultWarningEvaluator().evaluate(
            activeRow: active,
            alternateRows: [],
            preferences: WarningPreferences(
                thresholdPercent: 20,
                refreshCadence: .fiveMinutes,
                notificationsEnabled: false),
            notificationState: .defaultValue)

        #expect(result.warning?.cause == .fiveHour)
        #expect(result.shouldNotify == false)
        #expect(result.notificationState == .defaultValue)
    }

    @Test
    func thresholdBreach_resetsSuppressionAfterRecovery() {
        let active = Self.makeRow(
            email: "active@example.com",
            isActive: true,
            fiveHourRemaining: 12,
            weeklyRemaining: 50,
            usageStatus: .fresh)
        let evaluator = DefaultWarningEvaluator()
        let initial = evaluator.evaluate(
            activeRow: active,
            alternateRows: [],
            preferences: Self.breachPreferences,
            notificationState: WarningNotificationState())

        let recovered = Self.makeRow(
            id: active.id,
            email: active.email,
            isActive: true,
            fiveHourRemaining: 48,
            weeklyRemaining: 62,
            usageStatus: .fresh)
        let recovery = evaluator.evaluate(
            activeRow: recovered,
            alternateRows: [],
            preferences: Self.breachPreferences,
            notificationState: initial.notificationState)

        #expect(recovery.warning == nil)
        #expect(recovery.shouldNotify == false)
        #expect(recovery.notificationState.suppressedAccountIDs.contains(active.id) == false)
    }

    @Test
    func thresholdBreach_returnsNilWhenNoActiveRowExists() {
        let state = WarningNotificationState(suppressedAccountIDs: [UUID()])

        let result = DefaultWarningEvaluator().evaluate(
            activeRow: nil,
            alternateRows: [],
            preferences: .defaultValue,
            notificationState: state)

        #expect(result.warning == nil)
        #expect(result.shouldNotify == false)
        #expect(result.notificationState == state)
    }

    @Test
    func thresholdBreach_detectsBothWindows() {
        let active = Self.makeRow(
            email: "active@example.com",
            isActive: true,
            fiveHourRemaining: 18,
            weeklyRemaining: 19,
            usageStatus: .fresh)

        let result = DefaultWarningEvaluator().evaluate(
            activeRow: active,
            alternateRows: [],
            preferences: Self.breachPreferences,
            notificationState: WarningNotificationState())

        #expect(result.warning?.cause == .both)
        #expect(result.shouldNotify)
    }

    @Test
    func monitoringRisk_neverNotifiesAndKeepsSuppressionLatched() {
        let activeID = UUID()
        let active = Self.makeRow(
            id: activeID,
            email: "active@example.com",
            isActive: true,
            fiveHourRemaining: 14,
            weeklyRemaining: 28,
            usageStatus: .stale)

        let state = WarningNotificationState(suppressedAccountIDs: [activeID])
        let result = DefaultWarningEvaluator().evaluate(
            activeRow: active,
            alternateRows: [],
            preferences: .defaultValue,
            notificationState: state)

        #expect(result.warning?.severity == .monitoringRisk)
        #expect(result.warning?.cause == .stale)
        #expect(result.shouldNotify == false)
        #expect(result.notificationState == state)
    }

    @Test
    func monitoringRisk_handlesErrorAndUnknownWithoutUnlockingSuppression() {
        let activeID = UUID()
        let state = WarningNotificationState(suppressedAccountIDs: [activeID])

        let errorResult = DefaultWarningEvaluator().evaluate(
            activeRow: Self.makeRow(
                id: activeID,
                email: "active@example.com",
                isActive: true,
                fiveHourRemaining: 18,
                weeklyRemaining: 40,
                usageStatus: .error),
            alternateRows: [],
            preferences: .defaultValue,
            notificationState: state)
        let unknownResult = DefaultWarningEvaluator().evaluate(
            activeRow: Self.makeRow(
                id: activeID,
                email: "active@example.com",
                isActive: true,
                fiveHourRemaining: 18,
                weeklyRemaining: 40,
                usageStatus: .unknown),
            alternateRows: [],
            preferences: .defaultValue,
            notificationState: state)

        #expect(errorResult.warning?.cause == .error)
        #expect(errorResult.shouldNotify == false)
        #expect(errorResult.notificationState == state)
        #expect(unknownResult.warning?.cause == .unknown)
        #expect(unknownResult.shouldNotify == false)
        #expect(unknownResult.notificationState == state)
    }

    @Test
    func suggestions_includeOnlyFreshSupportedAccountsAboveThreshold() {
        let active = Self.makeRow(
            email: "active@example.com",
            isActive: true,
            fiveHourRemaining: 15,
            weeklyRemaining: 55,
            usageStatus: .fresh)
        let good = Self.makeAlternate(
            email: "good@example.com",
            supportState: .supported,
            readinessStatus: .fresh,
            fiveHourRemaining: 70,
            weeklyRemaining: 68,
            lastAuthenticatedAt: Date(timeIntervalSince1970: 300))
        let unsupported = Self.makeAlternate(
            email: "unsupported@example.com",
            supportState: .unsupported("No"),
            readinessStatus: .fresh,
            fiveHourRemaining: 90,
            weeklyRemaining: 90,
            lastAuthenticatedAt: Date(timeIntervalSince1970: 500))
        let stale = Self.makeAlternate(
            email: "stale@example.com",
            supportState: .supported,
            readinessStatus: .stale,
            fiveHourRemaining: 95,
            weeklyRemaining: 95,
            lastAuthenticatedAt: Date(timeIntervalSince1970: 600))
        let belowThreshold = Self.makeAlternate(
            email: "low@example.com",
            supportState: .supported,
            readinessStatus: .fresh,
            fiveHourRemaining: 18,
            weeklyRemaining: 80,
            lastAuthenticatedAt: Date(timeIntervalSince1970: 700))

        let result = DefaultWarningEvaluator().evaluate(
            activeRow: active,
            alternateRows: [unsupported, stale, belowThreshold, good],
            preferences: Self.breachPreferences,
            notificationState: WarningNotificationState())

        #expect(result.warning?.suggestions.map(\.email) == ["good@example.com"])
    }

    @Test
    func suggestions_sortByHeadroomThenFreshnessThenAuthenticationThenEmail() {
        let active = Self.makeRow(
            email: "active@example.com",
            isActive: true,
            fiveHourRemaining: 15,
            weeklyRemaining: 45,
            usageStatus: .fresh)
        let highestHeadroom = Self.makeAlternate(
            email: "top@example.com",
            supportState: .supported,
            readinessStatus: .fresh,
            fiveHourRemaining: 90,
            weeklyRemaining: 90,
            lastAuthenticatedAt: Date(timeIntervalSince1970: 10))
        let fresher = Self.makeAlternate(
            email: "fresher@example.com",
            supportState: .supported,
            readinessStatus: .fresh,
            fiveHourRemaining: 60,
            weeklyRemaining: 60,
            lastAuthenticatedAt: Date(timeIntervalSince1970: 10),
            lastRefreshedAt: Date(timeIntervalSince1970: 300))
        let olderRefresh = Self.makeAlternate(
            email: "older-refresh@example.com",
            supportState: .supported,
            readinessStatus: .fresh,
            fiveHourRemaining: 60,
            weeklyRemaining: 60,
            lastAuthenticatedAt: Date(timeIntervalSince1970: 100),
            lastRefreshedAt: Date(timeIntervalSince1970: 200))
        let laterAuth = Self.makeAlternate(
            email: "later-auth@example.com",
            supportState: .supported,
            readinessStatus: .fresh,
            fiveHourRemaining: 60,
            weeklyRemaining: 60,
            lastAuthenticatedAt: Date(timeIntervalSince1970: 200),
            lastRefreshedAt: Date(timeIntervalSince1970: 200))

        let result = DefaultWarningEvaluator().evaluate(
            activeRow: active,
            alternateRows: [laterAuth, olderRefresh, fresher, highestHeadroom],
            preferences: Self.breachPreferences,
            notificationState: .defaultValue)

        #expect(result.warning?.suggestions.map(\.email) == [
            "top@example.com",
            "fresher@example.com",
            "later-auth@example.com",
        ])
    }

    private static func makeRow(
        id: UUID = UUID(),
        email: String,
        isActive: Bool,
        fiveHourRemaining: Double,
        weeklyRemaining: Double,
        usageStatus: UsageProbeStatus)
        -> AccountProjectionRow
    {
        AccountProjectionRow(
            id: id,
            email: email,
            isActive: isActive,
            isLive: isActive,
            supportState: .supported,
            lastAuthenticatedAt: Date(timeIntervalSince1970: 100),
            fiveHourWindow: RateWindow(
                usedPercent: 100 - fiveHourRemaining,
                windowMinutes: 300,
                resetsAt: nil,
                resetDescription: nil),
            weeklyWindow: RateWindow(
                usedPercent: 100 - weeklyRemaining,
                windowMinutes: 10_080,
                resetsAt: nil,
                resetDescription: nil),
            lastUsageRefreshAt: Date(timeIntervalSince1970: 200),
            usageSource: usageStatus == .fresh ? .managedHomeOAuth : .cache,
            usageStatus: usageStatus,
            usageErrorDescription: usageStatus == .fresh ? nil : "problem",
            alternateReadiness: nil)
    }

    private static func makeAlternate(
        email: String,
        supportState: AccountSupportState,
        readinessStatus: UsageProbeStatus,
        fiveHourRemaining: Double,
        weeklyRemaining: Double,
        lastAuthenticatedAt: Date?,
        lastRefreshedAt: Date = Date(timeIntervalSince1970: 250))
        -> AccountProjectionRow
    {
        AccountProjectionRow(
            id: UUID(),
            email: email,
            isActive: false,
            isLive: false,
            supportState: supportState,
            lastAuthenticatedAt: lastAuthenticatedAt,
            fiveHourWindow: nil,
            weeklyWindow: nil,
            lastUsageRefreshAt: Date(timeIntervalSince1970: 250),
            usageSource: readinessStatus == .fresh ? .managedHomeOAuth : .cache,
            usageStatus: readinessStatus,
            usageErrorDescription: nil,
            alternateReadiness: AlternateAccountReadiness(
                accountID: UUID(),
                status: readinessStatus,
                fiveHourRemainingPercent: fiveHourRemaining,
                weeklyRemainingPercent: weeklyRemaining,
                lastRefreshedAt: lastRefreshedAt))
    }

    private static let breachPreferences = WarningPreferences(
        thresholdPercent: 20,
        refreshCadence: .fiveMinutes,
        notificationsEnabled: true)
}
