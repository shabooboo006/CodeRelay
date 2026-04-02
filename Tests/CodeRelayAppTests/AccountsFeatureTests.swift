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
    func Phase2_1_accountsFeature_defaultsToSimplifiedChinese() throws {
        let feature = AccountsFeature(services: Self.makeServices(
            defaults: try Self.makeDefaults("default-language"),
            store: StubManagedAccountStore()))

        #expect(feature.state.selectedLanguage == .simplifiedChinese)
    }

    @MainActor
    @Test
    func Phase2_1_accountsFeature_persistsLanguageSelectionAndUsesEnglishCopy() async throws {
        let defaults = try Self.makeDefaults("language-selection")
        let feature = AccountsFeature(services: Self.makeServices(
            defaults: defaults,
            store: StubManagedAccountStore()))

        try await feature.perform(.setLanguage(.english))
        try await feature.perform(.refreshMonitoring)

        #expect(defaults.string(forKey: AppContainer.preferredAppLanguageKey) == AppLanguage.english.rawValue)
        #expect(feature.state.selectedLanguage == .english)
        #expect(feature.state.message == CodeRelayLocalizer.text("accounts.message.noAccountsToRefresh", language: .english))
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

    @MainActor
    @Test
    func Phase2_accountsFeature_loadsCachedMonitoringSnapshots() throws {
        let defaults = try Self.makeDefaults("phase2-cached-load")
        let account = Self.makeAccount(email: "active@example.com")
        defaults.set(account.id.uuidString, forKey: AppContainer.activeManagedAccountIDKey)

        let usageStore = StubManagedAccountUsageStore(snapshots: [
            Self.makeSnapshot(
                accountID: account.id,
                fiveHourUsedPercent: 72,
                weeklyUsedPercent: 38,
                status: .fresh,
                source: .cache)
        ])
        let feature = AccountsFeature(services: Self.makeServices(
            defaults: defaults,
            store: StubManagedAccountStore(accounts: [account]),
            usageStore: usageStore))

        feature.loadInitialState()

        let row = try #require(feature.state.rows.first)
        #expect(row.isActive)
        #expect(row.fiveHourWindow?.usedPercent == 72)
        #expect(row.weeklyWindow?.usedPercent == 38)
        #expect(row.usageSource == .cache)
        #expect(row.usageStatus == .fresh)
        #expect(row.lastUsageRefreshAt != nil)
    }

    @MainActor
    @Test
    func Phase2_accountsFeature_refreshesAllManagedAccounts() async throws {
        let defaults = try Self.makeDefaults("phase2-refresh")
        let alpha = Self.makeAccount(email: "alpha@example.com")
        let beta = Self.makeAccount(email: "beta@example.com")
        let zeta = Self.makeAccount(email: "zeta@example.com")
        defaults.set(beta.id.uuidString, forKey: AppContainer.activeManagedAccountIDKey)

        let refreshService = StubCodexUsageRefreshService(resultsByAccountID: [
            alpha.id: .init(
                accountID: alpha.id,
                snapshot: Self.makeSnapshot(
                    accountID: alpha.id,
                    fiveHourUsedPercent: 24,
                    weeklyUsedPercent: 10,
                    status: .fresh,
                    source: .managedHomeOAuth),
                status: .fresh,
                source: .managedHomeOAuth,
                message: nil),
            beta.id: .init(
                accountID: beta.id,
                snapshot: Self.makeSnapshot(
                    accountID: beta.id,
                    fiveHourUsedPercent: 41,
                    weeklyUsedPercent: 19,
                    status: .fresh,
                    source: .managedHomeOAuth),
                status: .fresh,
                source: .managedHomeOAuth,
                message: nil),
            zeta.id: .init(
                accountID: zeta.id,
                snapshot: Self.makeSnapshot(
                    accountID: zeta.id,
                    fiveHourUsedPercent: 81,
                    weeklyUsedPercent: 57,
                    status: .fresh,
                    source: .managedHomeOAuth),
                status: .fresh,
                source: .managedHomeOAuth,
                message: nil)
        ])
        let usageStore = StubManagedAccountUsageStore()
        let feature = AccountsFeature(services: Self.makeServices(
            defaults: defaults,
            store: StubManagedAccountStore(accounts: [zeta, beta, alpha]),
            usageStore: usageStore,
            refreshService: refreshService))

        try await feature.perform(.refreshMonitoring)

        #expect(refreshService.requestedEmails == [
            "alpha@example.com",
            "beta@example.com",
            "zeta@example.com"
        ])
        #expect(try usageStore.listSnapshots().count == 3)

        let active = try #require(feature.state.rows.first(where: { $0.id == beta.id }))
        #expect(active.isActive)
        #expect(active.fiveHourWindow?.usedPercent == 41)
        #expect(active.weeklyWindow?.usedPercent == 19)

        let alternate = try #require(feature.state.rows.first(where: { $0.id == alpha.id }))
        #expect(alternate.alternateReadiness?.status == .fresh)
        #expect(alternate.alternateReadiness?.fiveHourRemainingPercent == 76)
        #expect(feature.state.message == CodeRelayLocalizer.format(
            "accounts.message.usageRefreshedCount",
            language: .simplifiedChinese,
            3))
    }

    @MainActor
    @Test
    func Phase2_accountsFeature_preservesStaleSnapshotsWhenRefreshFails() async throws {
        let defaults = try Self.makeDefaults("phase2-stale-fallback")
        let active = Self.makeAccount(email: "active@example.com")
        let alternate = Self.makeAccount(email: "alternate@example.com")
        defaults.set(active.id.uuidString, forKey: AppContainer.activeManagedAccountIDKey)

        let cachedSnapshot = Self.makeSnapshot(
            accountID: active.id,
            fiveHourUsedPercent: 88,
            weeklyUsedPercent: 44,
            status: .fresh,
            source: .cache)
        let usageStore = StubManagedAccountUsageStore(snapshots: [cachedSnapshot])
        let refreshService = StubCodexUsageRefreshService(resultsByAccountID: [
            active.id: .init(
                accountID: active.id,
                snapshot: Self.makeSnapshot(
                    accountID: active.id,
                    fiveHourUsedPercent: 88,
                    weeklyUsedPercent: 44,
                    status: .stale,
                    source: .cache,
                    lastErrorDescription: "timed out"),
                status: .stale,
                source: .cache,
                message: "timed out"),
            alternate.id: .init(
                accountID: alternate.id,
                snapshot: nil,
                status: .error,
                source: .managedHomeOAuth,
                message: "unauthorized")
        ])
        let feature = AccountsFeature(services: Self.makeServices(
            defaults: defaults,
            store: StubManagedAccountStore(accounts: [active, alternate]),
            usageStore: usageStore,
            refreshService: refreshService))

        try await feature.perform(.refreshMonitoring)

        #expect(feature.state.rows.count == 2)
        let activeRow = try #require(feature.state.rows.first(where: { $0.id == active.id }))
        #expect(activeRow.fiveHourWindow?.usedPercent == 88)
        #expect(activeRow.usageStatus == .stale)
        #expect(activeRow.usageSource == .cache)
        let alternateRow = try #require(feature.state.rows.first(where: { $0.id == alternate.id }))
        #expect(alternateRow.alternateReadiness?.status == .error)
        #expect(feature.state.message == CodeRelayLocalizer.text(
            "accounts.message.usageRefreshMixed",
            language: .simplifiedChinese))
    }

    @MainActor
    @Test
    func Phase2_accountsFeature_preservesUnknownReadinessAfterRefresh() async throws {
        let defaults = try Self.makeDefaults("phase2-unknown-readiness")
        let active = Self.makeAccount(email: "active@example.com")
        let alternate = Self.makeAccount(email: "alternate@example.com")
        defaults.set(active.id.uuidString, forKey: AppContainer.activeManagedAccountIDKey)

        let refreshService = StubCodexUsageRefreshService(resultsByAccountID: [
            active.id: .init(
                accountID: active.id,
                snapshot: Self.makeSnapshot(
                    accountID: active.id,
                    fiveHourUsedPercent: 21,
                    weeklyUsedPercent: 11,
                    status: .fresh,
                    source: .managedHomeOAuth),
                status: .fresh,
                source: .managedHomeOAuth,
                message: nil),
            alternate.id: .init(
                accountID: alternate.id,
                snapshot: nil,
                status: .unknown,
                source: .unknown,
                message: "missing credentials")
        ])
        let feature = AccountsFeature(services: Self.makeServices(
            defaults: defaults,
            store: StubManagedAccountStore(accounts: [active, alternate]),
            refreshService: refreshService))

        try await feature.perform(.refreshMonitoring)

        let alternateRow = try #require(feature.state.rows.first(where: { $0.id == alternate.id }))
        #expect(alternateRow.alternateReadiness?.status == .unknown)
        #expect(alternateRow.alternateReadiness?.lastRefreshedAt != nil)
        #expect(alternateRow.usageStatus == .unknown)
    }

    @MainActor
    @Test
    func Phase3_accountsFeature_refreshesOnlyActiveAccountInBackground() async throws {
        let defaults = try Self.makeDefaults("phase3-active-only-refresh")
        let active = Self.makeAccount(email: "active@example.com")
        let alternate = Self.makeAccount(email: "alternate@example.com")
        defaults.set(active.id.uuidString, forKey: AppContainer.activeManagedAccountIDKey)

        let refreshService = StubCodexUsageRefreshService(resultsByAccountID: [
            active.id: .init(
                accountID: active.id,
                snapshot: Self.makeSnapshot(
                    accountID: active.id,
                    fiveHourUsedPercent: 40,
                    weeklyUsedPercent: 20,
                    status: .fresh,
                    source: .managedHomeOAuth),
                status: .fresh,
                source: .managedHomeOAuth,
                message: nil)
        ])
        let usageStore = StubManagedAccountUsageStore()
        let feature = AccountsFeature(services: Self.makeServices(
            defaults: defaults,
            store: StubManagedAccountStore(accounts: [active, alternate]),
            usageStore: usageStore,
            refreshService: refreshService))

        feature.loadInitialState()
        try await feature.perform(.refreshActiveMonitoring)

        #expect(refreshService.requestedEmails == ["active@example.com"])
        #expect(try usageStore.listSnapshots().map(\.accountID) == [active.id])
    }

    @MainActor
    @Test
    func Phase3_accountsFeature_skipsBackgroundRefreshWithoutActiveAccount() async throws {
        let defaults = try Self.makeDefaults("phase3-no-active-background")
        let active = Self.makeAccount(email: "active@example.com")
        let alternate = Self.makeAccount(email: "alternate@example.com")
        let refreshService = StubCodexUsageRefreshService(resultsByAccountID: [
            active.id: .init(
                accountID: active.id,
                snapshot: Self.makeSnapshot(
                    accountID: active.id,
                    fiveHourUsedPercent: 40,
                    weeklyUsedPercent: 20,
                    status: .fresh,
                    source: .managedHomeOAuth),
                status: .fresh,
                source: .managedHomeOAuth,
                message: nil)
        ])
        let feature = AccountsFeature(services: Self.makeServices(
            defaults: defaults,
            store: StubManagedAccountStore(accounts: [active, alternate]),
            refreshService: refreshService))

        feature.loadInitialState()
        try await feature.perform(.refreshActiveMonitoring)

        #expect(refreshService.requestedEmails.isEmpty)
    }

    @MainActor
    @Test
    func Phase3_accountsFeature_notifiesOncePerDepletionCycle() async throws {
        let defaults = try Self.makeDefaults("phase3-notify-once")
        let active = Self.makeAccount(email: "active@example.com")
        defaults.set(active.id.uuidString, forKey: AppContainer.activeManagedAccountIDKey)

        let warningStore = StubWarningPreferencesStore(preferences: WarningPreferences(
            thresholdPercent: 20,
            refreshCadence: .fiveMinutes,
            notificationsEnabled: true))
        let notifier = StubWarningNotifier()
        let refreshService = StubCodexUsageRefreshService(resultsByAccountID: [
            active.id: .init(
                accountID: active.id,
                snapshot: Self.makeSnapshot(
                    accountID: active.id,
                    fiveHourUsedPercent: 90,
                    weeklyUsedPercent: 25,
                    status: .fresh,
                    source: .managedHomeOAuth),
                status: .fresh,
                source: .managedHomeOAuth,
                message: nil)
        ])
        let feature = AccountsFeature(services: Self.makeServices(
            defaults: defaults,
            store: StubManagedAccountStore(accounts: [active]),
            refreshService: refreshService,
            warningPreferencesStore: warningStore,
            warningNotifier: notifier))

        feature.loadInitialState()
        try await feature.perform(.refreshActiveMonitoring)
        try await feature.perform(.refreshActiveMonitoring)

        #expect(feature.state.activeWarning?.cause == .fiveHour)
        #expect(notifier.postedWarnings.count == 1)
        #expect(warningStore.notificationState.suppressedAccountIDs == [active.id])
    }

    @MainActor
    @Test
    func Phase3_accountsFeature_notifiesAgainAfterRecoveryAndRebreach() async throws {
        let defaults = try Self.makeDefaults("phase3-rebreach")
        let active = Self.makeAccount(email: "active@example.com")
        defaults.set(active.id.uuidString, forKey: AppContainer.activeManagedAccountIDKey)

        let warningStore = StubWarningPreferencesStore(preferences: WarningPreferences(
            thresholdPercent: 20,
            refreshCadence: .fiveMinutes,
            notificationsEnabled: true))
        let notifier = StubWarningNotifier()
        let refreshService = StubCodexUsageRefreshService(
            resultSequencesByAccountID: [
                active.id: [
                    .init(
                        accountID: active.id,
                        snapshot: Self.makeSnapshot(
                            accountID: active.id,
                            fiveHourUsedPercent: 90,
                            weeklyUsedPercent: 25,
                            status: .fresh,
                            source: .managedHomeOAuth),
                        status: .fresh,
                        source: .managedHomeOAuth,
                        message: nil),
                    .init(
                        accountID: active.id,
                        snapshot: Self.makeSnapshot(
                            accountID: active.id,
                            fiveHourUsedPercent: 40,
                            weeklyUsedPercent: 25,
                            status: .fresh,
                            source: .managedHomeOAuth),
                        status: .fresh,
                        source: .managedHomeOAuth,
                        message: nil),
                    .init(
                        accountID: active.id,
                        snapshot: Self.makeSnapshot(
                            accountID: active.id,
                            fiveHourUsedPercent: 88,
                            weeklyUsedPercent: 25,
                            status: .fresh,
                            source: .managedHomeOAuth),
                        status: .fresh,
                        source: .managedHomeOAuth,
                        message: nil),
                ]
            ])
        let feature = AccountsFeature(services: Self.makeServices(
            defaults: defaults,
            store: StubManagedAccountStore(accounts: [active]),
            refreshService: refreshService,
            warningPreferencesStore: warningStore,
            warningNotifier: notifier))

        feature.loadInitialState()
        try await feature.perform(.refreshActiveMonitoring)
        try await feature.perform(.refreshActiveMonitoring)
        try await feature.perform(.refreshActiveMonitoring)

        #expect(notifier.postedWarnings.count == 2)
        #expect(feature.state.activeWarning?.cause == .fiveHour)
    }

    @MainActor
    @Test
    func Phase3_accountsFeature_marksMonitoringRiskWithoutNotifying() async throws {
        let defaults = try Self.makeDefaults("phase3-monitoring-risk")
        let active = Self.makeAccount(email: "active@example.com")
        defaults.set(active.id.uuidString, forKey: AppContainer.activeManagedAccountIDKey)

        let warningStore = StubWarningPreferencesStore(preferences: .defaultValue)
        let notifier = StubWarningNotifier()
        let refreshService = StubCodexUsageRefreshService(resultsByAccountID: [
            active.id: .init(
                accountID: active.id,
                snapshot: Self.makeSnapshot(
                    accountID: active.id,
                    fiveHourUsedPercent: 90,
                    weeklyUsedPercent: 25,
                    status: .stale,
                    source: .cache,
                    lastErrorDescription: "timed out"),
                status: .stale,
                source: .cache,
                message: "timed out")
        ])
        let feature = AccountsFeature(services: Self.makeServices(
            defaults: defaults,
            store: StubManagedAccountStore(accounts: [active]),
            refreshService: refreshService,
            warningPreferencesStore: warningStore,
            warningNotifier: notifier))

        feature.loadInitialState()
        try await feature.perform(.refreshActiveMonitoring)

        #expect(feature.state.activeWarning?.severity == .monitoringRisk)
        #expect(feature.state.activeWarning?.cause == .stale)
        #expect(notifier.postedWarnings.isEmpty)
    }

    @MainActor
    @Test
    func Phase3_accountsFeature_persistsWarningPreferencesAndRequestsAuthorizationWhenEnabled() async throws {
        let defaults = try Self.makeDefaults("phase3-preferences")
        let warningStore = StubWarningPreferencesStore(preferences: WarningPreferences(
            thresholdPercent: 15,
            refreshCadence: .manual,
            notificationsEnabled: false))
        let notifier = StubWarningNotifier()
        let feature = AccountsFeature(services: Self.makeServices(
            defaults: defaults,
            store: StubManagedAccountStore(),
            warningPreferencesStore: warningStore,
            warningNotifier: notifier))

        #expect(feature.state.warningPreferences.thresholdPercent == 15)
        #expect(feature.state.warningPreferences.refreshCadence == .manual)
        #expect(feature.state.warningPreferences.notificationsEnabled == false)

        try await feature.perform(.setWarningThreshold(35))
        try await feature.perform(.setWarningRefreshCadence(.oneMinute))
        try await feature.perform(.setWarningNotificationsEnabled(true))

        #expect(feature.state.warningPreferences == WarningPreferences(
            thresholdPercent: 35,
            refreshCadence: .oneMinute,
            notificationsEnabled: true))
        #expect(warningStore.savedPreferences.suffix(3) == [
            WarningPreferences(thresholdPercent: 35, refreshCadence: .manual, notificationsEnabled: false),
            WarningPreferences(thresholdPercent: 35, refreshCadence: .oneMinute, notificationsEnabled: false),
            WarningPreferences(thresholdPercent: 35, refreshCadence: .oneMinute, notificationsEnabled: true),
        ])
        #expect(notifier.authorizationRequests == 1)
    }

    @Test
    func Phase2_1_localizerProvidesChineseAndEnglishAccountCopy() {
        #expect(CodeRelayLocalizer.text("accounts.title", language: .simplifiedChinese) == "托管 Codex 账号")
        #expect(CodeRelayLocalizer.text("accounts.title", language: .english) == "Managed Codex Accounts")
        #expect(CodeRelayLocalizer.languageOptionLabel(.simplifiedChinese, language: .english) == "Simplified Chinese")
        #expect(CodeRelayLocalizer.languageOptionLabel(.english, language: .simplifiedChinese) == "English")
    }

    @MainActor
    @Test
    func Phase2_1_accountsFeature_localizesErrorsInCurrentLanguage() async throws {
        let defaults = try Self.makeDefaults("localized-errors")
        let account = Self.makeAccount(email: "person@example.com")
        let feature = AccountsFeature(services: Self.makeServices(
            defaults: defaults,
            store: StubManagedAccountStore(accounts: [account]),
            managedHomeSafety: StubManagedHomeSafety(shouldThrow: true)))

        await feature.run(.remove(account.id))
        #expect(feature.state.message == CodeRelayLocalizer.text(
            "accounts.error.unsafeRemovalTarget",
            language: .simplifiedChinese))

        try await feature.perform(.setLanguage(.english))
        await feature.run(.remove(account.id))
        #expect(feature.state.message == CodeRelayLocalizer.text(
            "accounts.error.unsafeRemovalTarget",
            language: .english))
    }

    static func makeDefaults(_ suffix: String) throws -> UserDefaults {
        let suite = "AccountsFeatureTests.\(suffix)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    static func makeAccount(email: String) -> ManagedAccount {
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

    @MainActor
    static func makeServices(
        defaults: UserDefaults,
        store: StubManagedAccountStore,
        usageStore: StubManagedAccountUsageStore = StubManagedAccountUsageStore(),
        managedHomeSafety: StubManagedHomeSafety = StubManagedHomeSafety(),
        loginRunner: StubCodexLoginRunner = StubCodexLoginRunner(),
        identityReader: StubCodexIdentityReader = StubCodexIdentityReader(identity: ManagedAccountIdentity(email: "new@example.com")),
        detector: StubCredentialStoreDetector = StubCredentialStoreDetector(),
        refreshService: StubCodexUsageRefreshService = StubCodexUsageRefreshService(),
        warningEvaluator: any WarningEvaluating = DefaultWarningEvaluator(),
        warningPreferencesStore: (any WarningPreferencesStoring)? = nil,
        warningNotifier: (any WarningNotifying)? = nil)
        -> AppContainer.Services
    {
        AppContainer.Services(
            paths: CodeRelayPaths(applicationSupportRoot: URL(fileURLWithPath: "/tmp/relay-root", isDirectory: true)),
            fileManager: .default,
            userDefaults: defaults,
            managedAccountStore: store,
            managedAccountUsageStore: usageStore,
            accountProjection: DefaultAccountProjection(),
            warningEvaluator: warningEvaluator,
            managedHomeSafety: managedHomeSafety,
            codexLoginRunner: loginRunner,
            codexIdentityReader: identityReader,
            credentialStoreDetector: detector,
            codexUsageRefreshService: refreshService,
            warningPreferencesStore: warningPreferencesStore,
            warningNotifier: warningNotifier)
    }

    private static func makeSnapshot(
        accountID: UUID,
        fiveHourUsedPercent: Double,
        weeklyUsedPercent: Double,
        status: UsageProbeStatus,
        source: UsageProbeSource,
        lastErrorDescription: String? = nil)
        -> ManagedAccountUsageSnapshot
    {
        ManagedAccountUsageSnapshot(
            accountID: accountID,
            fiveHourWindow: RateWindow(
                usedPercent: fiveHourUsedPercent,
                windowMinutes: 300,
                resetsAt: Date(timeIntervalSince1970: 1_775_069_593),
                resetDescription: "in 35m"),
            weeklyWindow: RateWindow(
                usedPercent: weeklyUsedPercent,
                windowMinutes: 10_080,
                resetsAt: Date(timeIntervalSince1970: 1_775_155_993),
                resetDescription: "in 6d"),
            updatedAt: Date(timeIntervalSince1970: 1_775_069_593),
            source: source,
            status: status,
            lastErrorDescription: lastErrorDescription)
    }
}

struct UpsertCall {
    let account: AuthenticatedManagedAccount
    let existingAccountID: UUID?
}

final class StubManagedAccountUsageStore: ManagedAccountUsageStore, @unchecked Sendable {
    var snapshots: [ManagedAccountUsageSnapshot]

    init(snapshots: [ManagedAccountUsageSnapshot] = []) {
        self.snapshots = snapshots
    }

    func listSnapshots() throws -> [ManagedAccountUsageSnapshot] {
        self.snapshots.sorted { $0.accountID.uuidString < $1.accountID.uuidString }
    }

    func snapshot(for accountID: UUID) throws -> ManagedAccountUsageSnapshot? {
        self.snapshots.first { $0.accountID == accountID }
    }

    func upsert(_ snapshot: ManagedAccountUsageSnapshot) throws {
        if let index = self.snapshots.firstIndex(where: { $0.accountID == snapshot.accountID }) {
            self.snapshots[index] = snapshot
        } else {
            self.snapshots.append(snapshot)
        }
    }

    func removeSnapshot(for accountID: UUID) throws {
        self.snapshots.removeAll { $0.accountID == accountID }
    }
}

final class StubManagedAccountStore: ManagedAccountStore, @unchecked Sendable {
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

final class LoginRecorder: @unchecked Sendable {
    var requests: [CodexLoginRequest] = []
}

struct StubCodexLoginRunner: CodexLoginRunner, Sendable {
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

struct StubCodexIdentityReader: CodexIdentityReader, Sendable {
    let identity: ManagedAccountIdentity?

    func readIdentity(in scope: CodexHomeScope) throws -> ManagedAccountIdentity? {
        _ = scope
        return self.identity
    }
}

struct StubCredentialStoreDetector: CredentialStoreDetector, Sendable {
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

final class StubCodexUsageRefreshService: CodexUsageRefreshService, @unchecked Sendable {
    var resultsByAccountID: [UUID: ManagedAccountUsageRefreshResult]
    var resultSequencesByAccountID: [UUID: [ManagedAccountUsageRefreshResult]]
    var requestedEmails: [String] = []

    init(
        resultsByAccountID: [UUID: ManagedAccountUsageRefreshResult] = [:],
        resultSequencesByAccountID: [UUID: [ManagedAccountUsageRefreshResult]] = [:])
    {
        self.resultsByAccountID = resultsByAccountID
        self.resultSequencesByAccountID = resultSequencesByAccountID
    }

    func refresh(
        account: ManagedAccount,
        cachedSnapshot: ManagedAccountUsageSnapshot?)
        async -> ManagedAccountUsageRefreshResult
    {
        _ = cachedSnapshot
        self.requestedEmails.append(account.email)
        if var sequence = self.resultSequencesByAccountID[account.id], !sequence.isEmpty {
            let next = sequence.removeFirst()
            self.resultSequencesByAccountID[account.id] = sequence
            return next
        }
        return self.resultsByAccountID[account.id] ?? ManagedAccountUsageRefreshResult(
            accountID: account.id,
            snapshot: nil,
            status: .unknown,
            source: .unknown,
            message: "missing stub")
    }
}

struct StubManagedHomeSafety: ManagedHomeSafety, Sendable {
    var shouldThrow: Bool = false

    func validateRemovalTarget(_ url: URL) throws {
        _ = url
        if self.shouldThrow {
            throw ManagedHomeSafetyError.outsideManagedRoot
        }
    }
}

final class StubWarningPreferencesStore: WarningPreferencesStoring, @unchecked Sendable {
    var preferences: WarningPreferences
    var notificationState: WarningNotificationState
    var savedPreferences: [WarningPreferences] = []
    var savedNotificationStates: [WarningNotificationState] = []

    init(
        preferences: WarningPreferences,
        notificationState: WarningNotificationState = .defaultValue)
    {
        self.preferences = preferences
        self.notificationState = notificationState
    }

    func loadPreferences() -> WarningPreferences {
        self.preferences
    }

    func savePreferences(_ preferences: WarningPreferences) {
        self.preferences = preferences
        self.savedPreferences.append(preferences)
    }

    func loadNotificationState() -> WarningNotificationState {
        self.notificationState
    }

    func saveNotificationState(_ state: WarningNotificationState) {
        self.notificationState = state
        self.savedNotificationStates.append(state)
    }
}

final class StubWarningNotifier: WarningNotifying, @unchecked Sendable {
    struct PostedWarning: Equatable {
        let idPrefix: String
        let title: String
        let body: String
    }

    var authorizationRequests = 0
    var postedWarnings: [PostedWarning] = []

    func requestAuthorizationOnStartup() {
        self.authorizationRequests += 1
    }

    func postLowUsageWarning(idPrefix: String, title: String, body: String) {
        self.postedWarnings.append(PostedWarning(idPrefix: idPrefix, title: title, body: body))
    }
}
