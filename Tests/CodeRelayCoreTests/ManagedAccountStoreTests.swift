import CodeRelayCore
import Foundation
import Testing

@Suite(.serialized) struct ManagedAccountStoreTests {
    @Test
    func Phase1_managedAccountStore_roundTripsVersionedJSON() throws {
        let root = Self.makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = Self.makeStore(root: root)
        let authenticatedAt = Date(timeIntervalSince1970: 1_000)
        let created = try store.upsertAuthenticatedAccount(AuthenticatedManagedAccount(
            email: " First@Example.com ",
            managedHomePath: root.appendingPathComponent("managed-home-a", isDirectory: true).path,
            authenticatedAt: authenticatedAt,
            credentialStoreMode: .file,
            switchSupport: .supported,
            lastValidatedIdentity: ManagedAccountIdentity(email: "first@example.com")))

        let loaded = try store.listAccounts()
        let registryURL = CodeRelayPaths(applicationSupportRoot: root).managedAccountsStoreURL
        let contents = try String(contentsOf: registryURL, encoding: .utf8)

        #expect(loaded.count == 1)
        #expect(loaded.first?.id == created.id)
        #expect(loaded.first?.email == "first@example.com")
        #expect(loaded.first?.lastAuthenticatedAt == authenticatedAt)
        #expect(contents.contains("\"version\""))
        #expect(contents.contains("\"accounts\""))
        #if os(macOS)
        let attributes = try FileManager.default.attributesOfItem(atPath: registryURL.path)
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
        #expect(permissions == 0o600)
        #endif
    }

    @Test
    func Phase1_managedAccountStore_suppressesEnvelopeDuplicates() throws {
        let root = Self.makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = Self.makeStore(root: root)
        let homePath = root.appendingPathComponent("managed-home-a", isDirectory: true).path

        let first = try store.upsertAuthenticatedAccount(AuthenticatedManagedAccount(
            email: "first@example.com",
            managedHomePath: homePath,
            authenticatedAt: Date(timeIntervalSince1970: 100),
            credentialStoreMode: .file,
            switchSupport: .supported))
        let second = try store.upsertAuthenticatedAccount(AuthenticatedManagedAccount(
            email: " FIRST@example.com ",
            managedHomePath: homePath,
            authenticatedAt: Date(timeIntervalSince1970: 200),
            credentialStoreMode: .file,
            switchSupport: .supported))

        let loaded = try store.listAccounts()

        #expect(first.id == second.id)
        #expect(loaded.count == 1)
        #expect(loaded.first?.lastAuthenticatedAt == Date(timeIntervalSince1970: 200))
    }

    @Test
    func Phase1_managedAccountStore_reauthenticatesByExplicitID() throws {
        let root = Self.makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = Self.makeStore(root: root)
        let original = try store.upsertAuthenticatedAccount(AuthenticatedManagedAccount(
            email: "person@example.com",
            managedHomePath: root.appendingPathComponent("managed-home-a", isDirectory: true).path,
            authenticatedAt: Date(timeIntervalSince1970: 300),
            credentialStoreMode: .file,
            switchSupport: .supported))

        let updated = try store.upsertAuthenticatedAccount(
            AuthenticatedManagedAccount(
                email: "PERSON@example.com",
                managedHomePath: root.appendingPathComponent("managed-home-b", isDirectory: true).path,
                authenticatedAt: Date(timeIntervalSince1970: 400),
                credentialStoreMode: .file,
                switchSupport: .supported,
                lastValidatedIdentity: ManagedAccountIdentity(email: "person@example.com")),
            existingAccountID: original.id)

        let loaded = try store.listAccounts()

        #expect(updated.id == original.id)
        #expect(updated.createdAt == original.createdAt)
        #expect(updated.updatedAt == Date(timeIntervalSince1970: 400))
        #expect(updated.lastAuthenticatedAt == Date(timeIntervalSince1970: 400))
        #expect(loaded.count == 1)
        #expect(loaded.first?.managedHomePath.hasSuffix("managed-home-b") == true)
    }

    @Test
    func Phase1_managedAccountStore_rejectsUnsupportedVersion() throws {
        let root = Self.makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = CodeRelayPaths(applicationSupportRoot: root)
        try FileManager.default.createDirectory(at: paths.appDirectory, withIntermediateDirectories: true)
        let unsupportedJSON = """
        {
          "accounts" : [],
          "version" : 99
        }
        """
        try unsupportedJSON.write(to: paths.managedAccountsStoreURL, atomically: true, encoding: .utf8)

        let store = Self.makeStore(root: root)

        #expect(throws: ManagedAccountStoreError.unsupportedVersion(99)) {
            try store.listAccounts()
        }
    }

    @Test
    func Phase1_managedAccountStore_unknownRemovalFailsSafely() throws {
        let root = Self.makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = Self.makeStore(root: root)
        let missingID = UUID()

        #expect(throws: ManagedAccountStoreError.accountNotFound(missingID)) {
            try store.removeAccount(id: missingID)
        }
    }

    private static func makeTemporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private static func makeStore(root: URL) -> JSONManagedAccountStore {
        JSONManagedAccountStore(paths: CodeRelayPaths(applicationSupportRoot: root))
    }
}
