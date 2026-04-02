import Foundation

public protocol WarningEvaluating: Sendable {
    func evaluate(
        activeRow: AccountProjectionRow?,
        alternateRows: [AccountProjectionRow],
        preferences: WarningPreferences,
        notificationState: WarningNotificationState)
        -> WarningEvaluationResult
}

public struct DefaultWarningEvaluator: WarningEvaluating, Sendable {
    public init() {}

    public func evaluate(
        activeRow: AccountProjectionRow?,
        alternateRows: [AccountProjectionRow],
        preferences: WarningPreferences,
        notificationState: WarningNotificationState)
        -> WarningEvaluationResult
    {
        guard let activeRow else {
            return WarningEvaluationResult(
                warning: nil,
                shouldNotify: false,
                notificationState: notificationState)
        }

        let threshold = preferences.normalizedThresholdPercent
        var nextState = notificationState

        if let cause = Self.thresholdCause(for: activeRow, threshold: threshold) {
            let warning = ActiveWarning(
                activeAccountID: activeRow.id,
                activeAccountEmail: activeRow.email,
                severity: .thresholdBreached,
                cause: cause,
                thresholdPercent: threshold,
                suggestions: Self.suggestedAccounts(from: alternateRows, threshold: threshold))
            let shouldNotify = preferences.notificationsEnabled
                && !nextState.suppressedAccountIDs.contains(activeRow.id)

            if shouldNotify {
                nextState.suppressedAccountIDs.insert(activeRow.id)
            }

            return WarningEvaluationResult(
                warning: warning,
                shouldNotify: shouldNotify,
                notificationState: nextState)
        }

        if Self.isHealthy(activeRow) {
            nextState.suppressedAccountIDs.remove(activeRow.id)
            return WarningEvaluationResult(
                warning: nil,
                shouldNotify: false,
                notificationState: nextState)
        }

        if let cause = Self.monitoringRiskCause(for: activeRow) {
            let warning = ActiveWarning(
                activeAccountID: activeRow.id,
                activeAccountEmail: activeRow.email,
                severity: .monitoringRisk,
                cause: cause,
                thresholdPercent: threshold,
                suggestions: [])
            return WarningEvaluationResult(
                warning: warning,
                shouldNotify: false,
                notificationState: nextState)
        }

        return WarningEvaluationResult(
            warning: nil,
            shouldNotify: false,
            notificationState: nextState)
    }

    private static func thresholdCause(for row: AccountProjectionRow, threshold: Double) -> WarningCause? {
        guard row.usageStatus == .fresh else {
            return nil
        }

        let fiveHourBreached = row.fiveHourWindow?.remainingPercent.isLessThanOrEqualTo(threshold) == true
        let weeklyBreached = row.weeklyWindow?.remainingPercent.isLessThanOrEqualTo(threshold) == true

        switch (fiveHourBreached, weeklyBreached) {
        case (true, true):
            return .both
        case (true, false):
            return .fiveHour
        case (false, true):
            return .weekly
        case (false, false):
            return nil
        }
    }

    private static func isHealthy(_ row: AccountProjectionRow) -> Bool {
        row.usageStatus == .fresh
    }

    private static func monitoringRiskCause(for row: AccountProjectionRow) -> WarningCause? {
        switch row.usageStatus {
        case .stale:
            .stale
        case .error:
            .error
        case .unknown:
            .unknown
        case .fresh:
            nil
        }
    }

    private static func suggestedAccounts(
        from rows: [AccountProjectionRow],
        threshold: Double)
        -> [WarningSuggestedAccount]
    {
        rows.compactMap { row in
            guard row.supportState.kind == .supported,
                  let readiness = row.alternateReadiness,
                  readiness.status == .fresh,
                  let fiveHourRemainingPercent = readiness.fiveHourRemainingPercent,
                  let weeklyRemainingPercent = readiness.weeklyRemainingPercent,
                  fiveHourRemainingPercent > threshold,
                  weeklyRemainingPercent > threshold
            else {
                return nil
            }

            return WarningSuggestedAccount(
                id: row.id,
                email: row.email,
                fiveHourRemainingPercent: fiveHourRemainingPercent,
                weeklyRemainingPercent: weeklyRemainingPercent,
                lastRefreshedAt: readiness.lastRefreshedAt,
                lastAuthenticatedAt: row.lastAuthenticatedAt)
        }
        .sorted(by: Self.isPreferredSuggestion)
        .prefix(3)
        .map { $0 }
    }

    private static func isPreferredSuggestion(_ lhs: WarningSuggestedAccount, _ rhs: WarningSuggestedAccount) -> Bool {
        let lhsHeadroom = min(lhs.fiveHourRemainingPercent, lhs.weeklyRemainingPercent)
        let rhsHeadroom = min(rhs.fiveHourRemainingPercent, rhs.weeklyRemainingPercent)

        if lhsHeadroom != rhsHeadroom {
            return lhsHeadroom > rhsHeadroom
        }

        if lhs.lastRefreshedAt != rhs.lastRefreshedAt {
            return (lhs.lastRefreshedAt ?? .distantPast) > (rhs.lastRefreshedAt ?? .distantPast)
        }

        if lhs.lastAuthenticatedAt != rhs.lastAuthenticatedAt {
            return (lhs.lastAuthenticatedAt ?? .distantPast) > (rhs.lastAuthenticatedAt ?? .distantPast)
        }

        return lhs.email.localizedCaseInsensitiveCompare(rhs.email) == .orderedAscending
    }
}

private extension Double {
    func isLessThanOrEqualTo(_ value: Double) -> Bool {
        self <= value
    }
}
