import CodeRelayCodex
import CodeRelayApp
import CodeRelayCore
import Foundation
import Testing

@Suite struct AccountsFeatureTests {
    @MainActor
    @Test
    func Phase1_accountsFeature_loadsRowRenderingState() throws {
        let defaults = try Self.makeDefaults("rows")
        let account = Self.makeAccount(email: "person@example.com")
        let store = StubManagedAccountStore(accounts: [account])
        let feature = AccountsFeature(services: Self.makeServices(
            defaults: defaults,
            store: store))

        try feature.refresh(liveIdentity: ManagedAccountIdentity(email: "person@example.com"))

        #expect(feature.state.rows.count == 1)
        #expect(feature.state.rows.first?.email == "person@example.com")
        #expect(feature.state.rows.first?.isLive == true)
    }

    @MainActor
    @Test
    func Phase1_accountsFeature_persistsSetActiveSelection() async throws {
        let defaults = try Self.makeDefaults("set-active")
        let first = Self.makeAccount(email: "first@example.com")
        let second = Self.makeAccount(email: "second@example.com")
        let store = StubManagedAccountStore(accounts: [first, second])
        let feature = AccountsFeature(services: Self.makeServices(
            defaults: defaults,
            store: store))

        try await feature.perform(.setActive(second.id))

        #expect(defaults.string(forKey: AppContainer.activeManagedAccountIDKey) == second.id.uuidString)
        #expect(feature.state.activeManagedAccountID == second.id)
    }

    @MainActor
    @Test
    func Phase1_accountsFeature_routesReauthenticationWithExistingID() async throws {
        let defaults = try Self.makeDefaults("reauth")
        let account = Self.makeAccount(email: "person@example.com")
        let store = StubManagedAccountStore(accounts: [account])
        let loginRecorder = LoginRecorder()
        let feature = AccountsFeature(services: Self.makeServices(
            defaults: defaults,
            store: store,
            loginRunner: StubCodexLoginRunner(recorder: loginRecorder),
            identityReader: StubCodexIdentityReader(identity: ManagedAccountIdentity(email: "person@example.com")),
            detector: StubCredentialStoreDetector()))

        try await feature.perform(.reauthenticate(account.id))

        #expect(loginRecorder.requests.last?.existingAccountID == account.id)
        #expect(store.upsertCalls.last?.existingAccountID == account.id)
    }

    @MainActor
    @Test
    func Phase1_accountsFeature_rejectsUnsafeRemovalTargets() async throws {
        let defaults = try Self.makeDefaults("remove")
        let account = Self.makeAccount(email: "person@example.com")
        let store = StubManagedAccountStore(accounts: [account])
        let feature = AccountsFeature(services: Self.makeServices(
            defaults: defaults,
            store: store,
            managedHomeSafety: StubManagedHomeSafety(shouldThrow: true)))

        do {
            try await feature.perform(.remove(account.id))
            Issue.record("Expected unsafe removal to throw.")
        } catch let error as ManagedHomeSafetyError {
            #expect(error == .outsideManagedRoot)
        }
        #expect(try store.listAccounts().count == 1)
    }

    private static func makeDefaults(_ suffix: String) throws -> UserDefaults {
        let suite = "AccountsFeatureTests.\(suffix)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private static func makeAccount(email: String) -> ManagedAccount {
        ManagedAccount(
            id: UUID(),
            email: email,
            managedHomePath: "/tmp/\(UUID().uuidString)",
            createdAt: .now,
            updatedAt: .now,
            lastAuthenticatedAt: .now,
            credentialStoreMode: .file,
            switchSupport: .supported,
            lastValidatedIdentity: ManagedAccountIdentity(email: email))
    }

    private static func makeServices(
        defaults: UserDefaults,
        store: StubManagedAccountStore,
        managedHomeSafety: StubManagedHomeSafety = StubManagedHomeSafety(),
        loginRunner: StubCodexLoginRunner = StubCodexLoginRunner(),
        identityReader: StubCodexIdentityReader = StubCodexIdentityReader(identity: ManagedAccountIdentity(email: "new@example.com")),
        detector: StubCredentialStoreDetector = StubCredentialStoreDetector())
        -> AppContainer.Services
    {
        AppContainer.Services(
            paths: CodeRelayPaths(applicationSupportRoot: URL(fileURLWithPath: "/tmp/relay-root", isDirectory: true)),
            fileManager: .default,
            userDefaults: defaults,
            managedAccountStore: store,
            accountProjection: DefaultAccountProjection(),
            managedHomeSafety: managedHomeSafety,
            codexLoginRunner: loginRunner,
            codexIdentityReader: identityReader,
            credentialStoreDetector: detector)
    }
}

private struct UpsertCall {
    let account: AuthenticatedManagedAccount
    let existingAccountID: UUID?
}

private final class StubManagedAccountStore: ManagedAccountStore, @unchecked Sendable {
    var accounts: [ManagedAccount]
    var upsertCalls: [UpsertCall] = []

    init(accounts: [ManagedAccount] = []) {
        self.accounts = accounts
    }

    func listAccounts() throws -> [ManagedAccount] {
        self.accounts
    }

    func upsertAuthenticatedAccount(_ account: AuthenticatedManagedAccount, existingAccountID: UUID?) throws -> ManagedAccount {
        self.upsertCalls.append(UpsertCall(account: account, existingAccountID: existingAccountID))
        if let existingAccountID,
           let index = self.accounts.firstIndex(where: { $0.id == existingAccountID })
        {
            let updated = ManagedAccount(
                id: existingAccountID,
                email: account.email,
                managedHomePath: account.managedHomePath,
                createdAt: self.accounts[index].createdAt,
                updatedAt: account.authenticatedAt,
                lastAuthenticatedAt: account.authenticatedAt,
                credentialStoreMode: account.credentialStoreMode,
                switchSupport: account.switchSupport,
                lastValidatedIdentity: account.lastValidatedIdentity)
            self.accounts[index] = updated
            return updated
        }

        let created = ManagedAccount(
            id: UUID(),
            email: account.email,
            managedHomePath: account.managedHomePath,
            createdAt: account.authenticatedAt,
            updatedAt: account.authenticatedAt,
            lastAuthenticatedAt: account.authenticatedAt,
            credentialStoreMode: account.credentialStoreMode,
            switchSupport: account.switchSupport,
            lastValidatedIdentity: account.lastValidatedIdentity)
        self.accounts.append(created)
        return created
    }

    func updateAccount(_ account: ManagedAccount) throws {
        guard let index = self.accounts.firstIndex(where: { $0.id == account.id }) else {
            throw ManagedAccountStoreError.accountNotFound(account.id)
        }
        self.accounts[index] = account
    }

    func removeAccount(id: UUID) throws -> ManagedAccount {
        guard let index = self.accounts.firstIndex(where: { $0.id == id }) else {
            throw ManagedAccountStoreError.accountNotFound(id)
        }
        return self.accounts.remove(at: index)
    }
}

private final class LoginRecorder: @unchecked Sendable {
    var requests: [CodexLoginRequest] = []
}

private struct StubCodexLoginRunner: CodexLoginRunner, Sendable {
    var recorder: LoginRecorder?

    init(recorder: LoginRecorder? = nil) {
        self.recorder = recorder
    }

    func login(request: CodexLoginRequest) async throws -> CodexLoginResult {
        self.recorder?.requests.append(request)
        return CodexLoginResult(
            scope: request.scope,
            invokedCommand: ["codex", "login"],
            environment: request.scope.environment(),
            output: "ok")
    }
}

private struct StubCodexIdentityReader: CodexIdentityReader, Sendable {
    let identity: ManagedAccountIdentity?

    func readIdentity(in scope: CodexHomeScope) throws -> ManagedAccountIdentity? {
        _ = scope
        return self.identity
    }
}

private struct StubCredentialStoreDetector: CredentialStoreDetector, Sendable {
    var mode: CredentialStoreMode = .file
    var supportState: AccountSupportState = .supported

    func credentialStoreMode(in scope: CodexHomeScope) throws -> CredentialStoreMode {
        _ = scope
        return self.mode
    }

    func detectSupport(in scope: CodexHomeScope) throws -> AccountSupportState {
        _ = scope
        return self.supportState
    }
}

private struct StubManagedHomeSafety: ManagedHomeSafety, Sendable {
    var shouldThrow: Bool = false

    func validateRemovalTarget(_ url: URL) throws {
        _ = url
        if self.shouldThrow {
            throw ManagedHomeSafetyError.outsideManagedRoot
        }
    }
}
