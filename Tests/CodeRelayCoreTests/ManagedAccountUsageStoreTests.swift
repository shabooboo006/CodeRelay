import CodeRelayCore
import Foundation
import Testing

@Suite(.serialized) struct ManagedAccountUsageStoreTests {
    @Test
    func Phase2_managedAccountUsageStore_roundTripsSnapshots() throws {
        let root = Self.makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let accountID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let refreshedAt = Date(timeIntervalSince1970: 12_345)
        let resetsAt = Date(timeIntervalSince1970: 23_456)

        let store = Self.makeStore(root: root)
        let snapshot = ManagedAccountUsageSnapshot(
            accountID: accountID,
            fiveHourWindow: RateWindow(
                usedPercent: 72,
                windowMinutes: 300,
                resetsAt: resetsAt,
                resetDescription: "in 2h"),
            weeklyWindow: RateWindow(
                usedPercent: 48,
                windowMinutes: 10_080,
                resetsAt: nil,
                resetDescription: "next week"),
            updatedAt: refreshedAt,
            source: .managedHomeOAuth,
            status: .fresh,
            lastErrorDescription: nil)

        try store.upsert(snapshot)

        let reloadedStore = Self.makeStore(root: root)
        let loaded = try #require(try reloadedStore.snapshot(for: accountID))
        let storeContents = try String(
            contentsOf: CodeRelayPaths(applicationSupportRoot: root).managedAccountUsageStoreURL,
            encoding: .utf8)

        #expect(loaded == snapshot)
        #expect(try reloadedStore.listSnapshots() == [snapshot])
        #expect(storeContents.contains("\"version\""))
        #expect(storeContents.contains("\"managedHomeOAuth\""))
        #expect(storeContents.contains("\"fresh\""))
    }

    @Test
    func Phase2_managedAccountUsageStore_rejectsUnsupportedVersion() throws {
        let root = Self.makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = CodeRelayPaths(applicationSupportRoot: root)
        try FileManager.default.createDirectory(at: paths.appDirectory, withIntermediateDirectories: true)
        let unsupportedJSON = """
        {
          "snapshots" : [],
          "version" : 99
        }
        """
        try unsupportedJSON.write(to: paths.managedAccountUsageStoreURL, atomically: true, encoding: .utf8)

        let store = Self.makeStore(root: root)

        #expect(throws: ManagedAccountUsageStoreError.unsupportedVersion(99)) {
            try store.listSnapshots()
        }
    }

    @Test
    func Phase2_managedAccountUsageStore_replacesSnapshotsByAccountID() throws {
        let root = Self.makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = Self.makeStore(root: root)
        let accountA = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let accountB = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!

        try store.upsert(Self.makeSnapshot(
            accountID: accountA,
            fiveHourUsed: 25,
            weeklyUsed: 40,
            updatedAt: Date(timeIntervalSince1970: 100),
            source: .managedHomeOAuth,
            status: .fresh,
            error: nil))
        try store.upsert(Self.makeSnapshot(
            accountID: accountB,
            fiveHourUsed: 55,
            weeklyUsed: 70,
            updatedAt: Date(timeIntervalSince1970: 200),
            source: .cache,
            status: .stale,
            error: "cache only"))
        try store.upsert(Self.makeSnapshot(
            accountID: accountA,
            fiveHourUsed: 80,
            weeklyUsed: 88,
            updatedAt: Date(timeIntervalSince1970: 300),
            source: .cache,
            status: .error,
            error: "network timeout"))

        let snapshots = try store.listSnapshots()
        let accountASnapshot = try #require(try store.snapshot(for: accountA))
        let accountBSnapshot = try #require(try store.snapshot(for: accountB))

        #expect(snapshots.count == 2)
        #expect(accountASnapshot.fiveHourWindow?.usedPercent == 80)
        #expect(accountASnapshot.weeklyWindow?.usedPercent == 88)
        #expect(accountASnapshot.status == .error)
        #expect(accountASnapshot.lastErrorDescription == "network timeout")
        #expect(accountBSnapshot.fiveHourWindow?.usedPercent == 55)
        #expect(accountBSnapshot.status == .stale)
    }

    @Test
    func Phase2_managedAccountUsageStore_returnsNilForMissingAccount() throws {
        let root = Self.makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = Self.makeStore(root: root)

        #expect(try store.snapshot(for: UUID()) == nil)
    }

    private static func makeSnapshot(
        accountID: UUID,
        fiveHourUsed: Double,
        weeklyUsed: Double,
        updatedAt: Date,
        source: UsageProbeSource,
        status: UsageProbeStatus,
        error: String?)
        -> ManagedAccountUsageSnapshot
    {
        ManagedAccountUsageSnapshot(
            accountID: accountID,
            fiveHourWindow: RateWindow(
                usedPercent: fiveHourUsed,
                windowMinutes: 300,
                resetsAt: Date(timeIntervalSince1970: 9_999),
                resetDescription: "soon"),
            weeklyWindow: RateWindow(
                usedPercent: weeklyUsed,
                windowMinutes: 10_080,
                resetsAt: Date(timeIntervalSince1970: 19_999),
                resetDescription: "later"),
            updatedAt: updatedAt,
            source: source,
            status: status,
            lastErrorDescription: error)
    }

    private static func makeTemporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private static func makeStore(root: URL) -> JSONManagedAccountUsageStore {
        JSONManagedAccountUsageStore(paths: CodeRelayPaths(applicationSupportRoot: root))
    }
}
