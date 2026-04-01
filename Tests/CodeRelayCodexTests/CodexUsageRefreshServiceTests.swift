import CodeRelayCodex
import CodeRelayCore
import Foundation
import Testing

@Suite(.serialized) struct CodexUsageRefreshServiceTests {
    @Test
    func Phase2_codexUsageRefreshService_returnsFreshSnapshotOnSuccess() async throws {
        let account = Self.makeAccount(email: "fresh@example.com")
        let snapshot = Self.makeSnapshot(
            accountID: account.id,
            updatedAt: Date(timeIntervalSince1970: 1_000),
            source: .managedHomeOAuth,
            status: .fresh,
            error: nil)
        let service = DefaultCodexUsageRefreshService(fetcher: StubCodexUsageFetcher(result: .success(snapshot)))

        let result = await service.refresh(account: account, cachedSnapshot: nil)

        #expect(result.accountID == account.id)
        #expect(result.snapshot == snapshot)
        #expect(result.status == .fresh)
        #expect(result.source == .managedHomeOAuth)
        #expect(result.message == nil)
    }

    @Test
    func Phase2_codexUsageRefreshService_returnsStaleSnapshotWhenFetchFailsWithCache() async {
        let account = Self.makeAccount(email: "stale@example.com")
        let cachedSnapshot = Self.makeSnapshot(
            accountID: account.id,
            updatedAt: Date(timeIntervalSince1970: 2_000),
            source: .managedHomeOAuth,
            status: .fresh,
            error: nil)
        let service = DefaultCodexUsageRefreshService(fetcher: StubCodexUsageFetcher(
            result: .failure(CodexUsageFetcherError.serverError(500, "boom"))))

        let result = await service.refresh(account: account, cachedSnapshot: cachedSnapshot)

        #expect(result.accountID == account.id)
        #expect(result.status == .stale)
        #expect(result.source == .cache)
        #expect(result.message == "Managed account usage request failed with status 500: boom")
        #expect(result.snapshot?.accountID == account.id)
        #expect(result.snapshot?.source == .cache)
        #expect(result.snapshot?.status == .stale)
        #expect(result.snapshot?.updatedAt == cachedSnapshot.updatedAt)
        #expect(result.snapshot?.fiveHourWindow == cachedSnapshot.fiveHourWindow)
        #expect(result.snapshot?.weeklyWindow == cachedSnapshot.weeklyWindow)
        #expect(result.snapshot?.lastErrorDescription == "Managed account usage request failed with status 500: boom")
    }

    @Test
    func Phase2_codexUsageRefreshService_returnsUnknownWhenNoSnapshotExists() async {
        let account = Self.makeAccount(email: "unknown@example.com")
        let service = DefaultCodexUsageRefreshService(fetcher: StubCodexUsageFetcher(
            result: .failure(CodexUsageFetcherError.missingAccessToken)))

        let result = await service.refresh(account: account, cachedSnapshot: nil)

        #expect(result.accountID == account.id)
        #expect(result.snapshot == nil)
        #expect(result.status == .unknown)
        #expect(result.source == .unknown)
        #expect(result.message == "Managed account auth.json does not contain an access token.")
    }

    @Test
    func Phase2_codexUsageRefreshService_returnsErrorWhenFetchFailsWithoutCache() async {
        let account = Self.makeAccount(email: "error@example.com")
        let service = DefaultCodexUsageRefreshService(fetcher: StubCodexUsageFetcher(
            result: .failure(CodexUsageFetcherError.invalidResponse)))

        let result = await service.refresh(account: account, cachedSnapshot: nil)

        #expect(result.accountID == account.id)
        #expect(result.snapshot == nil)
        #expect(result.status == .error)
        #expect(result.source == .managedHomeOAuth)
        #expect(result.message == "Managed account usage response was invalid.")
    }

    private struct StubCodexUsageFetcher: CodexUsageFetcher {
        let result: Result<ManagedAccountUsageSnapshot, Error>

        func fetchUsage(in scope: CodexHomeScope) async throws -> ManagedAccountUsageSnapshot {
            try self.result.get()
        }
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
            switchSupport: .supported)
    }

    private static func makeSnapshot(
        accountID: UUID,
        updatedAt: Date,
        source: UsageProbeSource,
        status: UsageProbeStatus,
        error: String?) -> ManagedAccountUsageSnapshot
    {
        ManagedAccountUsageSnapshot(
            accountID: accountID,
            fiveHourWindow: RateWindow(
                usedPercent: 45,
                windowMinutes: 300,
                resetsAt: Date(timeIntervalSince1970: 3_000),
                resetDescription: "soon"),
            weeklyWindow: RateWindow(
                usedPercent: 25,
                windowMinutes: 10_080,
                resetsAt: Date(timeIntervalSince1970: 4_000),
                resetDescription: "later"),
            updatedAt: updatedAt,
            source: source,
            status: status,
            lastErrorDescription: error)
    }
}
