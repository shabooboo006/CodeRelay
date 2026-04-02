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
        case setLanguage(AppLanguage)
        case setActive(UUID)
        case reauthenticate(UUID)
        case remove(UUID)
    }

    public struct State: Equatable, Sendable {
        public var rows: [AccountProjectionRow]
        public var activeManagedAccountID: UUID?
        public var liveIdentity: ManagedAccountIdentity?
        public var selectedLanguage: AppLanguage
        public var isBusy: Bool
        public var message: String?
        public var lastAction: Action?

        public init(
            rows: [AccountProjectionRow] = [],
            activeManagedAccountID: UUID? = nil,
            liveIdentity: ManagedAccountIdentity? = nil,
            selectedLanguage: AppLanguage = .defaultValue,
            isBusy: Bool = false,
            message: String? = nil,
            lastAction: Action? = nil)
        {
            self.rows = rows
            self.activeManagedAccountID = activeManagedAccountID
            self.liveIdentity = liveIdentity
            self.selectedLanguage = selectedLanguage
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
        var resolvedState = state
        resolvedState.selectedLanguage = Self.resolvePreferredAppLanguage(
            rawValue: services.userDefaults.string(forKey: services.preferredAppLanguageKey))
            ?? resolvedState.selectedLanguage
        self.state = resolvedState
        self.recordedActions = recordedActions
    }

    public func loadInitialState() {
        do {
            try self.refresh()
        } catch {
            self.state.message = self.describe(error)
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
            self.state.message = self.describe(error)
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
        case let .setLanguage(language):
            self.setLanguage(language)
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

        self.state.message = CodeRelayLocalizer.text("accounts.message.added", language: self.state.selectedLanguage)
        try self.refresh(liveIdentity: identity)
    }

    private func refreshMonitoring() async throws {
        let accounts = try self.services.managedAccountStore.listAccounts()
            .sorted { lhs, rhs in
                lhs.email.localizedCaseInsensitiveCompare(rhs.email) == .orderedAscending
            }

        guard !accounts.isEmpty else {
            self.state.message = CodeRelayLocalizer.text("accounts.message.noAccountsToRefresh", language: self.state.selectedLanguage)
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
            ? CodeRelayLocalizer.format("accounts.message.usageRefreshedCount", language: self.state.selectedLanguage, freshCount)
            : CodeRelayLocalizer.text("accounts.message.usageRefreshMixed", language: self.state.selectedLanguage)
    }

    private func setActive(_ accountID: UUID) throws {
        _ = try self.account(id: accountID)
        self.persistActiveManagedAccountID(accountID)
        self.state.message = CodeRelayLocalizer.text("accounts.message.activeUpdated", language: self.state.selectedLanguage)
        try self.refresh()
    }

    private func setLanguage(_ language: AppLanguage) {
        self.persistPreferredAppLanguage(language)
        self.state.selectedLanguage = language
        self.state.message = nil
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

        self.state.message = CodeRelayLocalizer.text("accounts.message.reauthenticated", language: self.state.selectedLanguage)
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

        self.state.message = CodeRelayLocalizer.text("accounts.message.removed", language: self.state.selectedLanguage)
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

    private func persistedPreferredAppLanguage() -> AppLanguage {
        Self.resolvePreferredAppLanguage(
            rawValue: self.services.userDefaults.string(forKey: self.services.preferredAppLanguageKey))
            ?? .defaultValue
    }

    private func persistActiveManagedAccountID(_ accountID: UUID?) {
        switch accountID {
        case let accountID?:
            self.services.userDefaults.set(accountID.uuidString, forKey: self.services.activeManagedAccountIDKey)
        case nil:
            self.services.userDefaults.removeObject(forKey: self.services.activeManagedAccountIDKey)
        }
    }

    private func persistPreferredAppLanguage(_ language: AppLanguage) {
        self.services.userDefaults.set(language.rawValue, forKey: self.services.preferredAppLanguageKey)
    }

    private func describe(_ error: Error) -> String {
        let language = self.persistedPreferredAppLanguage()

        if let error = error as? AccountsFeatureError {
            switch error {
            case .missingAccount:
                return CodeRelayLocalizer.text("accounts.error.missingAccount", language: language)
            case .missingIdentity:
                return CodeRelayLocalizer.text("accounts.error.missingIdentity", language: language)
            }
        }

        if let error = error as? ManagedHomeSafetyError {
            switch error {
            case .outsideManagedRoot:
                return CodeRelayLocalizer.text("accounts.error.unsafeRemovalTarget", language: language)
            }
        }

        if let error = error as? CodexLoginRunnerError {
            switch error {
            case .missingBinary:
                return CodeRelayLocalizer.text("accounts.error.loginMissingBinary", language: language)
            case let .launchFailed(message):
                return CodeRelayLocalizer.format("accounts.error.loginLaunchFailed", language: language, message)
            case .timedOut:
                return CodeRelayLocalizer.text("accounts.error.loginTimedOut", language: language)
            case let .failed(status, output):
                let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedOutput.isEmpty else {
                    return CodeRelayLocalizer.format("accounts.error.loginFailedStatus", language: language, Int(status))
                }
                return CodeRelayLocalizer.format("accounts.error.loginFailedStatusWithOutput", language: language, Int(status), trimmedOutput)
            }
        }

        if let error = error as? ManagedAccountStoreError {
            switch error {
            case .accountNotFound:
                return CodeRelayLocalizer.text("accounts.error.storeAccountNotFound", language: language)
            case let .unsupportedVersion(version):
                return CodeRelayLocalizer.format("accounts.error.storeUnsupportedVersion", language: language, version)
            }
        }

        if let error = error as? ManagedAccountUsageStoreError {
            switch error {
            case let .unsupportedVersion(version):
                return CodeRelayLocalizer.format("accounts.error.usageStoreUnsupportedVersion", language: language, version)
            }
        }

        if let localized = error as? LocalizedError,
           let description = localized.errorDescription
        {
            return description
        }
        return String(describing: error)
    }

    private static func resolvePreferredAppLanguage(rawValue: String?) -> AppLanguage? {
        guard let rawValue else {
            return nil
        }
        return AppLanguage(rawValue: rawValue)
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
