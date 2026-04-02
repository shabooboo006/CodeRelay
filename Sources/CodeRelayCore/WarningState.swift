import Foundation

public enum WarningSeverity: String, Codable, Equatable, Sendable {
    case thresholdBreached
    case monitoringRisk
}

public enum WarningCause: String, Codable, Equatable, Sendable {
    case fiveHour
    case weekly
    case both
    case stale
    case error
    case unknown
}

public struct WarningSuggestedAccount: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var email: String
    public var fiveHourRemainingPercent: Double
    public var weeklyRemainingPercent: Double
    public var lastRefreshedAt: Date?
    public var lastAuthenticatedAt: Date?

    public init(
        id: UUID,
        email: String,
        fiveHourRemainingPercent: Double,
        weeklyRemainingPercent: Double,
        lastRefreshedAt: Date?,
        lastAuthenticatedAt: Date?)
    {
        self.id = id
        self.email = email
        self.fiveHourRemainingPercent = fiveHourRemainingPercent
        self.weeklyRemainingPercent = weeklyRemainingPercent
        self.lastRefreshedAt = lastRefreshedAt
        self.lastAuthenticatedAt = lastAuthenticatedAt
    }
}

public struct ActiveWarning: Codable, Equatable, Sendable {
    public var activeAccountID: UUID
    public var activeAccountEmail: String
    public var severity: WarningSeverity
    public var cause: WarningCause
    public var thresholdPercent: Double
    public var suggestions: [WarningSuggestedAccount]

    public init(
        activeAccountID: UUID,
        activeAccountEmail: String,
        severity: WarningSeverity,
        cause: WarningCause,
        thresholdPercent: Double,
        suggestions: [WarningSuggestedAccount])
    {
        self.activeAccountID = activeAccountID
        self.activeAccountEmail = activeAccountEmail
        self.severity = severity
        self.cause = cause
        self.thresholdPercent = thresholdPercent
        self.suggestions = suggestions
    }
}

public struct WarningNotificationState: Codable, Equatable, Sendable {
    public var suppressedAccountIDs: Set<UUID>

    public static let defaultValue = WarningNotificationState()

    public init(suppressedAccountIDs: Set<UUID> = []) {
        self.suppressedAccountIDs = suppressedAccountIDs
    }
}

public struct WarningEvaluationResult: Equatable, Sendable {
    public var warning: ActiveWarning?
    public var shouldNotify: Bool
    public var notificationState: WarningNotificationState

    public init(
        warning: ActiveWarning?,
        shouldNotify: Bool,
        notificationState: WarningNotificationState)
    {
        self.warning = warning
        self.shouldNotify = shouldNotify
        self.notificationState = notificationState
    }
}
