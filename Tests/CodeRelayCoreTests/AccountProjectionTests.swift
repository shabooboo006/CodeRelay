import CodeRelayCore
import Foundation
import Testing

@Suite struct AccountProjectionTests {
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
            liveIdentity: ManagedAccountIdentity(email: "live@example.com")))

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
            liveIdentity: nil))

        #expect(result.correctedActiveManagedAccountID == nil)
        #expect(result.rows.first?.isActive == false)
    }

    @Test
    func Phase1_accountProjection_promotesLiveMatchWhenSelectionIsDangling() {
        let matchingAccount = Self.makeAccount(email: "person@example.com", supportState: .unverified("Need verification"))
        let result = DefaultAccountProjection().project(AccountProjectionInput(
            accounts: [matchingAccount],
            activeManagedAccountID: UUID(),
            liveIdentity: ManagedAccountIdentity(email: "PERSON@example.com")))

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
