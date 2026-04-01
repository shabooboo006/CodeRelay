import CodeRelayCodex
import CodeRelayCore
import Combine
import Foundation

public enum AccountsFeatureError: Error, Equatable, Sendable {
    case missingAccount(UUID)
    case missingIdentity
}

@MainActor
public final class AccountsFeature: ObservableObject {
    public enum Action: Equatable, Sendable {
        case addAccount
        case refreshMonitoring
        case setActive(UUID)
        case reauthenticate(UUID)
        case remove(UUID)
    }

    public struct State: Equatable, Sendable {
        public var rows: [AccountProjectionRow]
        public var activeManagedAccountID: UUID?
        public var liveIdentity: ManagedAccountIdentity?
        public var isBusy: Bool
        public var message: String?
        public var lastAction: Action?

        public init(
            rows: [AccountProjectionRow] = [],
            activeManagedAccountID: UUID? = nil,
            liveIdentity: ManagedAccountIdentity? = nil,
            isBusy: Bool = false,
            message: String? = nil,
            lastAction: Action? = nil)
        {
            self.rows = rows
            self.activeManagedAccountID = activeManagedAccountID
            self.liveIdentity = liveIdentity
            self.isBusy = isBusy
            self.message = message
            self.lastAction = lastAction
        }
    }

    public let services: AppContainer.Services
    @Published public private(set) var state: State
    public private(set) var recordedActions: [Action]

    public init(
        services: AppContainer.Services,
        state: State = State(),
        recordedActions: [Action] = [])
    {
        self.services = services
        self.state = state
        self.recordedActions = recordedActions
    }

    public func loadInitialState() {
        do {
            try self.refresh()
        } catch {
            self.state.message = Self.describe(error)
        }
    }

    public func refresh(liveIdentity: ManagedAccountIdentity? = nil) throws {
        let resolvedLiveIdentity = liveIdentity ?? self.state.liveIdentity
        let persistedActiveManagedAccountID = self.persistedActiveManagedAccountID()
        let usageSnapshots = try self.usageSnapshotsByAccountID()
        let projection = self.services.accountProjection.project(AccountProjectionInput(
            accounts: try self.services.managedAccountStore.listAccounts(),
            activeManagedAccountID: persistedActiveManagedAccountID,
            liveIdentity: resolvedLiveIdentity,
            usageSnapshots: usageSnapshots))

        self.state.rows = projection.rows
        self.state.activeManagedAccountID = projection.correctedActiveManagedAccountID
        self.state.liveIdentity = resolvedLiveIdentity
        if projection.correctedActiveManagedAccountID != persistedActiveManagedAccountID {
            self.persistActiveManagedAccountID(projection.correctedActiveManagedAccountID)
        }
    }

    public func send(_ action: Action) {
        self.recordedActions.append(action)
        self.state.lastAction = action
    }

    public func run(_ action: Action) async {
        do {
            try await self.perform(action)
        } catch {
            self.state.message = Self.describe(error)
        }
    }

    public func perform(_ action: Action) async throws {
        self.send(action)
        self.state.isBusy = true
        defer { self.state.isBusy = false }

        switch action {
        case .addAccount:
            try await self.addAccount()
        case .refreshMonitoring:
            try await self.refreshMonitoring()
        case let .setActive(accountID):
            try self.setActive(accountID)
        case let .reauthenticate(accountID):
            try await self.reauthenticate(accountID)
        case let .remove(accountID):
            try self.remove(accountID)
        }
    }

    private func addAccount() async throws {
        let accountID = UUID()
        let scope = CodexHomeScope(accountID: accountID, paths: self.services.paths)
        let result = try await self.services.codexLoginRunner.login(request: CodexLoginRequest(scope: scope))
        guard let identity = try self.services.codexIdentityReader.readIdentity(in: result.scope) else {
            throw AccountsFeatureError.missingIdentity
        }

        let supportState = try self.services.credentialStoreDetector.detectSupport(in: result.scope)
        let storeMode = try self.services.credentialStoreDetector.credentialStoreMode(in: result.scope)
        let stored = try self.services.managedAccountStore.upsertAuthenticatedAccount(AuthenticatedManagedAccount(
            email: identity.email,
            managedHomePath: result.scope.homeURL.path,
            authenticatedAt: .now,
            credentialStoreMode: storeMode == .unknown ? .file : storeMode,
            switchSupport: supportState,
            lastValidatedIdentity: identity), existingAccountID: nil)

        if self.persistedActiveManagedAccountID() == nil {
            self.persistActiveManagedAccountID(stored.id)
        }

        self.state.message = "Managed account added."
        try self.refresh(liveIdentity: identity)
    }

    private func refreshMonitoring() async throws {
        let accounts = try self.services.managedAccountStore.listAccounts()
            .sorted { lhs, rhs in
                lhs.email.localizedCaseInsensitiveCompare(rhs.email) == .orderedAscending
            }

        guard !accounts.isEmpty else {
            self.state.message = "No managed accounts to refresh."
            try self.refresh()
            return
        }

        var snapshotsByAccountID = try self.usageSnapshotsByAccountID()
        var freshCount = 0
        var staleOrErrorCount = 0

        for account in accounts {
            let result = await self.services.codexUsageRefreshService.refresh(
                account: account,
                cachedSnapshot: snapshotsByAccountID[account.id])
            let resolvedSnapshot = Self.snapshot(
                from: result,
                existingSnapshot: snapshotsByAccountID[account.id])

            if let resolvedSnapshot {
                try self.services.managedAccountUsageStore.upsert(resolvedSnapshot)
                snapshotsByAccountID[account.id] = resolvedSnapshot
            }

            switch result.status {
            case .fresh:
                freshCount += 1
            case .stale, .error, .unknown:
                staleOrErrorCount += 1
            }
        }

        try self.refresh(liveIdentity: self.state.liveIdentity)
        self.state.message = staleOrErrorCount == 0
            ? "Usage refreshed for \(freshCount) accounts."
            : "Usage refresh completed with stale or error results."
    }

    private func setActive(_ accountID: UUID) throws {
        _ = try self.account(id: accountID)
        self.persistActiveManagedAccountID(accountID)
        self.state.message = "Active account updated."
        try self.refresh()
    }

    private func reauthenticate(_ accountID: UUID) async throws {
        let existing = try self.account(id: accountID)
        let scope = CodexHomeScope(accountID: accountID, homeURL: existing.managedHomeURL)
        let result = try await self.services.codexLoginRunner.login(request: CodexLoginRequest(
            scope: scope,
            existingAccountID: accountID))
        guard let identity = try self.services.codexIdentityReader.readIdentity(in: result.scope) else {
            throw AccountsFeatureError.missingIdentity
        }

        let supportState = try self.services.credentialStoreDetector.detectSupport(in: result.scope)
        let storeMode = try self.services.credentialStoreDetector.credentialStoreMode(in: result.scope)
        _ = try self.services.managedAccountStore.upsertAuthenticatedAccount(AuthenticatedManagedAccount(
            email: identity.email,
            managedHomePath: result.scope.homeURL.path,
            authenticatedAt: .now,
            credentialStoreMode: storeMode == .unknown ? existing.credentialStoreMode : storeMode,
            switchSupport: supportState,
            lastValidatedIdentity: identity), existingAccountID: accountID)

        self.state.message = "Managed account re-authenticated."
        try self.refresh(liveIdentity: identity)
    }

    private func remove(_ accountID: UUID) throws {
        let existing = try self.account(id: accountID)
        try self.services.managedHomeSafety.validateRemovalTarget(existing.managedHomeURL)
        _ = try self.services.managedAccountStore.removeAccount(id: accountID)

        if self.services.fileManager.fileExists(atPath: existing.managedHomeURL.path) {
            try? self.services.fileManager.removeItem(at: existing.managedHomeURL)
        }

        if self.persistedActiveManagedAccountID() == accountID {
            self.persistActiveManagedAccountID(nil)
        }

        self.state.message = "Managed account removed."
        try self.refresh()
    }

    private func account(id: UUID) throws -> ManagedAccount {
        guard let account = try self.services.managedAccountStore.listAccounts().first(where: { $0.id == id }) else {
            throw AccountsFeatureError.missingAccount(id)
        }
        return account
    }

    private func usageSnapshotsByAccountID() throws -> [UUID: ManagedAccountUsageSnapshot] {
        try self.services.managedAccountUsageStore.listSnapshots()
            .reduce(into: [:]) { partialResult, snapshot in
                partialResult[snapshot.accountID] = snapshot
            }
    }

    private func persistedActiveManagedAccountID() -> UUID? {
        guard let rawValue = self.services.userDefaults.string(forKey: self.services.activeManagedAccountIDKey) else {
            return nil
        }
        return UUID(uuidString: rawValue)
    }

    private func persistActiveManagedAccountID(_ accountID: UUID?) {
        switch accountID {
        case let accountID?:
            self.services.userDefaults.set(accountID.uuidString, forKey: self.services.activeManagedAccountIDKey)
        case nil:
            self.services.userDefaults.removeObject(forKey: self.services.activeManagedAccountIDKey)
        }
    }

    private static func describe(_ error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription
        {
            return description
        }
        return String(describing: error)
    }

    private static func snapshot(
        from result: ManagedAccountUsageRefreshResult,
        existingSnapshot: ManagedAccountUsageSnapshot?)
        -> ManagedAccountUsageSnapshot?
    {
        if let snapshot = result.snapshot {
            return snapshot
        }

        guard result.status != .fresh else {
            return existingSnapshot
        }

        return ManagedAccountUsageSnapshot(
            accountID: result.accountID,
            fiveHourWindow: existingSnapshot?.fiveHourWindow,
            weeklyWindow: existingSnapshot?.weeklyWindow,
            updatedAt: .now,
            source: result.source,
            status: result.status,
            lastErrorDescription: result.message)
    }
}
