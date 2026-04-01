import Foundation

public struct RateWindow: Codable, Equatable, Sendable {
    public var usedPercent: Double
    public var windowMinutes: Int?
    public var resetsAt: Date?
    public var resetDescription: String?

    public init(
        usedPercent: Double,
        windowMinutes: Int?,
        resetsAt: Date?,
        resetDescription: String?)
    {
        self.usedPercent = usedPercent
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
        self.resetDescription = resetDescription
    }

    public var remainingPercent: Double {
        max(0, 100 - self.usedPercent)
    }
}

public enum UsageProbeSource: String, Codable, Sendable {
    case managedHomeOAuth
    case cache
    case unknown
}

public enum UsageProbeStatus: String, Codable, Sendable {
    case fresh
    case stale
    case error
    case unknown
}

public struct ManagedAccountUsageSnapshot: Codable, Equatable, Sendable {
    public var accountID: UUID
    public var fiveHourWindow: RateWindow?
    public var weeklyWindow: RateWindow?
    public var updatedAt: Date
    public var source: UsageProbeSource
    public var status: UsageProbeStatus
    public var lastErrorDescription: String?

    public init(
        accountID: UUID,
        fiveHourWindow: RateWindow?,
        weeklyWindow: RateWindow?,
        updatedAt: Date,
        source: UsageProbeSource,
        status: UsageProbeStatus,
        lastErrorDescription: String?)
    {
        self.accountID = accountID
        self.fiveHourWindow = fiveHourWindow
        self.weeklyWindow = weeklyWindow
        self.updatedAt = updatedAt
        self.source = source
        self.status = status
        self.lastErrorDescription = lastErrorDescription
    }
}

public struct AlternateAccountReadiness: Codable, Equatable, Sendable {
    public var accountID: UUID
    public var status: UsageProbeStatus
    public var fiveHourRemainingPercent: Double?
    public var weeklyRemainingPercent: Double?
    public var lastRefreshedAt: Date?

    public init(
        accountID: UUID,
        status: UsageProbeStatus,
        fiveHourRemainingPercent: Double?,
        weeklyRemainingPercent: Double?,
        lastRefreshedAt: Date?)
    {
        self.accountID = accountID
        self.status = status
        self.fiveHourRemainingPercent = fiveHourRemainingPercent
        self.weeklyRemainingPercent = weeklyRemainingPercent
        self.lastRefreshedAt = lastRefreshedAt
    }
}
