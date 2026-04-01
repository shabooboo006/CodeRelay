import Foundation

public struct AccountProjectionInput: Equatable, Sendable {
    public var accounts: [ManagedAccount]
    public var activeManagedAccountID: UUID?
    public var liveIdentity: ManagedAccountIdentity?

    public init(
        accounts: [ManagedAccount],
        activeManagedAccountID: UUID?,
        liveIdentity: ManagedAccountIdentity?)
    {
        self.accounts = accounts
        self.activeManagedAccountID = activeManagedAccountID
        self.liveIdentity = liveIdentity
    }
}

public struct AccountProjectionRow: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var email: String
    public var isActive: Bool
    public var isLive: Bool
    public var supportState: AccountSupportState
    public var lastAuthenticatedAt: Date?

    public init(
        id: UUID,
        email: String,
        isActive: Bool,
        isLive: Bool,
        supportState: AccountSupportState,
        lastAuthenticatedAt: Date?)
    {
        self.id = id
        self.email = email
        self.isActive = isActive
        self.isLive = isLive
        self.supportState = supportState
        self.lastAuthenticatedAt = lastAuthenticatedAt
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
            AccountProjectionRow(
                id: account.id,
                email: account.email,
                isActive: account.id == correctedActiveManagedAccountID,
                isLive: input.liveIdentity?.matches(account) == true,
                supportState: account.switchSupport,
                lastAuthenticatedAt: account.lastAuthenticatedAt)
        }
        return AccountProjectionResult(rows: rows.sorted { $0.email < $1.email }, correctedActiveManagedAccountID: correctedActiveManagedAccountID)
    }
}
