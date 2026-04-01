import CodeRelayCore
import Foundation
import Testing

@Suite struct AccountProjectionTests {
    @Test
    func Phase2_accountProjection_exposesActiveUsageWindows() {
        let activeAccount = Self.makeAccount(
            email: "active@example.com",
            supportState: .supported)
        let refreshedAt = Date(timeIntervalSince1970: 5_000)
        let fiveHourResetsAt = Date(timeIntervalSince1970: 6_000)
        let weeklyResetsAt = Date(timeIntervalSince1970: 7_000)

        let result = DefaultAccountProjection().project(AccountProjectionInput(
            accounts: [activeAccount],
            activeManagedAccountID: activeAccount.id,
            liveIdentity: nil,
            usageSnapshots: [
                activeAccount.id: ManagedAccountUsageSnapshot(
                    accountID: activeAccount.id,
                    fiveHourWindow: RateWindow(
                        usedPercent: 61,
                        windowMinutes: 300,
                        resetsAt: fiveHourResetsAt,
                        resetDescription: "in 25m"),
                    weeklyWindow: RateWindow(
                        usedPercent: 42,
                        windowMinutes: 10_080,
                        resetsAt: weeklyResetsAt,
                        resetDescription: "tomorrow"),
                    updatedAt: refreshedAt,
                    source: .managedHomeOAuth,
                    status: .fresh,
                    lastErrorDescription: nil)
            ]))

        let row = result.rows.first(where: { $0.id == activeAccount.id })

        #expect(row?.isActive == true)
        #expect(row?.fiveHourWindow?.usedPercent == 61)
        #expect(row?.weeklyWindow?.usedPercent == 42)
        #expect(row?.lastUsageRefreshAt == refreshedAt)
        #expect(row?.usageSource == .managedHomeOAuth)
        #expect(row?.usageStatus == .fresh)
        #expect(row?.usageErrorDescription == nil)
        #expect(row?.alternateReadiness == nil)
    }

    @Test
    func Phase2_accountProjection_exposesAlternateReadinessSummaries() {
        let activeAccount = Self.makeAccount(
            email: "active@example.com",
            supportState: .supported)
        let alternateAccount = Self.makeAccount(
            email: "alternate@example.com",
            supportState: .supported)
        let refreshedAt = Date(timeIntervalSince1970: 9_000)

        let result = DefaultAccountProjection().project(AccountProjectionInput(
            accounts: [alternateAccount, activeAccount],
            activeManagedAccountID: activeAccount.id,
            liveIdentity: nil,
            usageSnapshots: [
                alternateAccount.id: ManagedAccountUsageSnapshot(
                    accountID: alternateAccount.id,
                    fiveHourWindow: RateWindow(
                        usedPercent: 20,
                        windowMinutes: 300,
                        resetsAt: Date(timeIntervalSince1970: 10_000),
                        resetDescription: "soon"),
                    weeklyWindow: RateWindow(
                        usedPercent: 65,
                        windowMinutes: 10_080,
                        resetsAt: Date(timeIntervalSince1970: 11_000),
                        resetDescription: "later"),
                    updatedAt: refreshedAt,
                    source: .cache,
                    status: .stale,
                    lastErrorDescription: "cached snapshot")
            ]))

        let row = result.rows.first(where: { $0.id == alternateAccount.id })

        #expect(row?.isActive == false)
        #expect(row?.fiveHourWindow == nil)
        #expect(row?.weeklyWindow == nil)
        #expect(row?.usageSource == .cache)
        #expect(row?.usageStatus == .stale)
        #expect(row?.usageErrorDescription == "cached snapshot")
        #expect(row?.alternateReadiness?.accountID == alternateAccount.id)
        #expect(row?.alternateReadiness?.status == .stale)
        #expect(row?.alternateReadiness?.fiveHourRemainingPercent == 80)
        #expect(row?.alternateReadiness?.weeklyRemainingPercent == 35)
        #expect(row?.alternateReadiness?.lastRefreshedAt == refreshedAt)
    }

    @Test
    func Phase2_accountProjection_surfacesUnknownWhenSnapshotMissing() {
        let activeAccount = Self.makeAccount(
            email: "active@example.com",
            supportState: .supported)
        let alternateAccount = Self.makeAccount(
            email: "alternate@example.com",
            supportState: .supported)

        let result = DefaultAccountProjection().project(AccountProjectionInput(
            accounts: [alternateAccount, activeAccount],
            activeManagedAccountID: activeAccount.id,
            liveIdentity: nil,
            usageSnapshots: [:]))

        let activeRow = result.rows.first(where: { $0.id == activeAccount.id })
        let alternateRow = result.rows.first(where: { $0.id == alternateAccount.id })

        #expect(activeRow?.usageStatus == .unknown)
        #expect(activeRow?.usageSource == .unknown)
        #expect(activeRow?.fiveHourWindow == nil)
        #expect(activeRow?.weeklyWindow == nil)
        #expect(activeRow?.lastUsageRefreshAt == nil)
        #expect(activeRow?.alternateReadiness == nil)
        #expect(alternateRow?.usageStatus == .unknown)
        #expect(alternateRow?.usageSource == .unknown)
        #expect(alternateRow?.alternateReadiness?.status == .unknown)
        #expect(alternateRow?.alternateReadiness?.fiveHourRemainingPercent == nil)
        #expect(alternateRow?.alternateReadiness?.weeklyRemainingPercent == nil)
    }

    @Test
    func Phase2_accountProjection_preservesDanglingActiveCorrectionWithUsageSnapshots() {
        let matchingAccount = Self.makeAccount(
            email: "person@example.com",
            supportState: .unverified("Need verification"))
        let refreshedAt = Date(timeIntervalSince1970: 12_000)

        let result = DefaultAccountProjection().project(AccountProjectionInput(
            accounts: [matchingAccount],
            activeManagedAccountID: UUID(),
            liveIdentity: ManagedAccountIdentity(email: "PERSON@example.com"),
            usageSnapshots: [
                matchingAccount.id: ManagedAccountUsageSnapshot(
                    accountID: matchingAccount.id,
                    fiveHourWindow: RateWindow(
                        usedPercent: 10,
                        windowMinutes: 300,
                        resetsAt: nil,
                        resetDescription: nil),
                    weeklyWindow: nil,
                    updatedAt: refreshedAt,
                    source: .managedHomeOAuth,
                    status: .fresh,
                    lastErrorDescription: nil)
            ]))

        #expect(result.correctedActiveManagedAccountID == matchingAccount.id)
        #expect(result.rows.first?.isActive == true)
        #expect(result.rows.first?.isLive == true)
        #expect(result.rows.first?.usageStatus == .fresh)
        #expect(result.rows.first?.fiveHourWindow?.remainingPercent == 90)
    }

    @Test
    func Phase1_accountProjection_exposesActiveLiveAndSupportState() {
        let activeAccount = Self.makeAccount(
            email: "active@example.com",
            supportState: .supported)
        let liveAccount = Self.makeAccount(
            email: "live@example.com",
            supportState: .unsupported("Keychain-backed auth"))

        let result = DefaultAccountProjection().project(AccountProjectionInput(
            accounts: [liveAccount, activeAccount],
            activeManagedAccountID: activeAccount.id,
            liveIdentity: ManagedAccountIdentity(email: "live@example.com"),
            usageSnapshots: [:]))

        #expect(result.rows.count == 2)
        #expect(result.rows.first(where: { $0.id == activeAccount.id })?.isActive == true)
        #expect(result.rows.first(where: { $0.id == liveAccount.id })?.isLive == true)
        #expect(result.rows.first(where: { $0.id == liveAccount.id })?.supportState.kind == .unsupported)
    }

    @Test
    func Phase1_accountProjection_clearsDanglingSelections() {
        let account = Self.makeAccount(email: "person@example.com", supportState: .supported)
        let result = DefaultAccountProjection().project(AccountProjectionInput(
            accounts: [account],
            activeManagedAccountID: UUID(),
            liveIdentity: nil,
            usageSnapshots: [:]))

        #expect(result.correctedActiveManagedAccountID == nil)
        #expect(result.rows.first?.isActive == false)
    }

    @Test
    func Phase1_accountProjection_promotesLiveMatchWhenSelectionIsDangling() {
        let matchingAccount = Self.makeAccount(email: "person@example.com", supportState: .unverified("Need verification"))
        let result = DefaultAccountProjection().project(AccountProjectionInput(
            accounts: [matchingAccount],
            activeManagedAccountID: UUID(),
            liveIdentity: ManagedAccountIdentity(email: "PERSON@example.com"),
            usageSnapshots: [:]))

        #expect(result.correctedActiveManagedAccountID == matchingAccount.id)
        #expect(result.rows.first?.isActive == true)
        #expect(result.rows.first?.isLive == true)
    }

    private static func makeAccount(email: String, supportState: AccountSupportState) -> ManagedAccount {
        ManagedAccount(
            id: UUID(),
            email: email,
            managedHomePath: "/tmp/\(UUID().uuidString)",
            createdAt: .now,
            updatedAt: .now,
            lastAuthenticatedAt: .now,
            credentialStoreMode: .file,
            switchSupport: supportState)
    }
}
