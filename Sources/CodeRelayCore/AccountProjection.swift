import Foundation

public struct AccountProjectionInput: Equatable, Sendable {
    public var accounts: [ManagedAccount]
    public var activeManagedAccountID: UUID?
    public var liveIdentity: ManagedAccountIdentity?
    public var usageSnapshots: [UUID: ManagedAccountUsageSnapshot]

    public init(
        accounts: [ManagedAccount],
        activeManagedAccountID: UUID?,
        liveIdentity: ManagedAccountIdentity?,
        usageSnapshots: [UUID: ManagedAccountUsageSnapshot] = [:])
    {
        self.accounts = accounts
        self.activeManagedAccountID = activeManagedAccountID
        self.liveIdentity = liveIdentity
        self.usageSnapshots = usageSnapshots
    }
}

public struct AccountProjectionRow: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var email: String
    public var isActive: Bool
    public var isLive: Bool
    public var supportState: AccountSupportState
    public var lastAuthenticatedAt: Date?
    public var fiveHourWindow: RateWindow?
    public var weeklyWindow: RateWindow?
    public var lastUsageRefreshAt: Date?
    public var usageSource: UsageProbeSource
    public var usageStatus: UsageProbeStatus
    public var usageErrorDescription: String?
    public var alternateReadiness: AlternateAccountReadiness?

    public init(
        id: UUID,
        email: String,
        isActive: Bool,
        isLive: Bool,
        supportState: AccountSupportState,
        lastAuthenticatedAt: Date?,
        fiveHourWindow: RateWindow? = nil,
        weeklyWindow: RateWindow? = nil,
        lastUsageRefreshAt: Date? = nil,
        usageSource: UsageProbeSource = .unknown,
        usageStatus: UsageProbeStatus = .unknown,
        usageErrorDescription: String? = nil,
        alternateReadiness: AlternateAccountReadiness? = nil)
    {
        self.id = id
        self.email = email
        self.isActive = isActive
        self.isLive = isLive
        self.supportState = supportState
        self.lastAuthenticatedAt = lastAuthenticatedAt
        self.fiveHourWindow = fiveHourWindow
        self.weeklyWindow = weeklyWindow
        self.lastUsageRefreshAt = lastUsageRefreshAt
        self.usageSource = usageSource
        self.usageStatus = usageStatus
        self.usageErrorDescription = usageErrorDescription
        self.alternateReadiness = alternateReadiness
    }
}

public struct AccountProjectionResult: Equatable, Sendable {
    public var rows: [AccountProjectionRow]
    public var correctedActiveManagedAccountID: UUID?

    public init(rows: [AccountProjectionRow], correctedActiveManagedAccountID: UUID?) {
        self.rows = rows
        self.correctedActiveManagedAccountID = correctedActiveManagedAccountID
    }
}

public protocol AccountProjection: Sendable {
    func project(_ input: AccountProjectionInput) -> AccountProjectionResult
}

public struct DefaultAccountProjection: AccountProjection, Sendable {
    public init() {}

    public func project(_ input: AccountProjectionInput) -> AccountProjectionResult {
        let correctedActiveManagedAccountID: UUID? = {
            if let activeManagedAccountID = input.activeManagedAccountID,
               input.accounts.contains(where: { $0.id == activeManagedAccountID })
            {
                return activeManagedAccountID
            }

            guard let liveIdentity = input.liveIdentity else {
                return nil
            }

            return input.accounts.first(where: { liveIdentity.matches($0) })?.id
        }()

        let rows = input.accounts.map { account in
            let snapshot = input.usageSnapshots[account.id]
            let isActive = account.id == correctedActiveManagedAccountID

            return AccountProjectionRow(
                id: account.id,
                email: account.email,
                isActive: isActive,
                isLive: input.liveIdentity?.matches(account) == true,
                supportState: account.accountSupportState,
                lastAuthenticatedAt: account.lastAuthenticatedAt,
                fiveHourWindow: isActive ? snapshot?.fiveHourWindow : nil,
                weeklyWindow: isActive ? snapshot?.weeklyWindow : nil,
                lastUsageRefreshAt: snapshot?.updatedAt,
                usageSource: snapshot?.source ?? .unknown,
                usageStatus: snapshot?.status ?? .unknown,
                usageErrorDescription: snapshot?.lastErrorDescription,
                alternateReadiness: isActive ? nil : Self.makeAlternateReadiness(for: account.id, snapshot: snapshot))
        }
        return AccountProjectionResult(rows: rows.sorted { $0.email < $1.email }, correctedActiveManagedAccountID: correctedActiveManagedAccountID)
    }

    private static func makeAlternateReadiness(
        for accountID: UUID,
        snapshot: ManagedAccountUsageSnapshot?)
        -> AlternateAccountReadiness
    {
        AlternateAccountReadiness(
            accountID: accountID,
            status: snapshot?.status ?? .unknown,
            fiveHourRemainingPercent: snapshot?.fiveHourWindow?.remainingPercent,
            weeklyRemainingPercent: snapshot?.weeklyWindow?.remainingPercent,
            lastRefreshedAt: snapshot?.updatedAt)
    }
}
