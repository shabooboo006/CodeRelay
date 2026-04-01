import Foundation

public enum ManagedAccountStoreError: Error, Equatable, Sendable {
    case accountNotFound(UUID)
    case unsupportedVersion(Int)
}

public struct AuthenticatedManagedAccount: Equatable, Sendable {
    public var email: String
    public var managedHomePath: String
    public var authenticatedAt: Date
    public var credentialStoreMode: CredentialStoreMode
    public var switchSupport: AccountSupportState
    public var lastValidatedIdentity: ManagedAccountIdentity?

    public init(
        email: String,
        managedHomePath: String,
        authenticatedAt: Date = .now,
        credentialStoreMode: CredentialStoreMode,
        switchSupport: AccountSupportState,
        lastValidatedIdentity: ManagedAccountIdentity? = nil)
    {
        self.email = ManagedAccount.normalizeEmail(email)
        self.managedHomePath = managedHomePath
        self.authenticatedAt = authenticatedAt
        self.credentialStoreMode = credentialStoreMode
        self.switchSupport = switchSupport
        self.lastValidatedIdentity = lastValidatedIdentity
    }
}

public struct ManagedAccountRegistry: Codable, Equatable, Sendable {
    public let version: Int
    public var accounts: [ManagedAccount]

    public init(version: Int, accounts: [ManagedAccount]) {
        self.version = version
        self.accounts = Self.sanitized(accounts)
    }

    public func account(id: UUID) -> ManagedAccount? {
        self.accounts.first { $0.id == id }
    }

    private static func sanitized(_ accounts: [ManagedAccount]) -> [ManagedAccount] {
        var seenIDs: Set<UUID> = []
        var seenEnvelopes: Set<String> = []
        var sanitizedAccounts: [ManagedAccount] = []
        sanitizedAccounts.reserveCapacity(accounts.count)

        for account in accounts {
            guard seenIDs.insert(account.id).inserted else { continue }
            let envelope = "\(account.email)|\(account.managedHomePath)"
            guard seenEnvelopes.insert(envelope).inserted else { continue }
            sanitizedAccounts.append(account)
        }

        return sanitizedAccounts
    }
}

public protocol ManagedAccountStore: Sendable {
    func listAccounts() throws -> [ManagedAccount]
    func upsertAuthenticatedAccount(_ account: AuthenticatedManagedAccount, existingAccountID: UUID?) throws -> ManagedAccount
    func updateAccount(_ account: ManagedAccount) throws
    func removeAccount(id: UUID) throws -> ManagedAccount
}

public struct JSONManagedAccountStore: ManagedAccountStore, @unchecked Sendable {
    public static let currentVersion = 1

    public let paths: CodeRelayPaths
    public let registryURL: URL
    public let fileManager: FileManager

    public init(
        paths: CodeRelayPaths = CodeRelayPaths(),
        fileManager: FileManager = .default)
    {
        self.paths = paths
        self.registryURL = paths.managedAccountsStoreURL
        self.fileManager = fileManager
    }

    public func listAccounts() throws -> [ManagedAccount] {
        try self.loadRegistry().accounts.sorted { lhs, rhs in
            lhs.email < rhs.email
        }
    }

    public func upsertAuthenticatedAccount(
        _ account: AuthenticatedManagedAccount,
        existingAccountID: UUID? = nil) throws -> ManagedAccount
    {
        var registry = try self.loadRegistry()
        let timestamp = account.authenticatedAt

        if let index = self.matchingAccountIndex(
            in: registry.accounts,
            candidate: account,
            existingAccountID: existingAccountID)
        {
            let existing = registry.accounts[index]
            registry.accounts[index] = ManagedAccount(
                id: existing.id,
                email: account.email,
                managedHomePath: account.managedHomePath,
                createdAt: existing.createdAt,
                updatedAt: timestamp,
                lastAuthenticatedAt: timestamp,
                credentialStoreMode: account.credentialStoreMode,
                switchSupport: account.switchSupport,
                lastValidatedIdentity: account.lastValidatedIdentity)
            try self.saveRegistry(registry)
            return registry.accounts[index]
        }

        let created = ManagedAccount(
            id: existingAccountID ?? UUID(),
            email: account.email,
            managedHomePath: account.managedHomePath,
            createdAt: timestamp,
            updatedAt: timestamp,
            lastAuthenticatedAt: timestamp,
            credentialStoreMode: account.credentialStoreMode,
            switchSupport: account.switchSupport,
            lastValidatedIdentity: account.lastValidatedIdentity)
        registry.accounts.append(created)
        try self.saveRegistry(registry)
        return created
    }

    public func updateAccount(_ account: ManagedAccount) throws {
        var registry = try self.loadRegistry()
        guard let index = registry.accounts.firstIndex(where: { $0.id == account.id }) else {
            throw ManagedAccountStoreError.accountNotFound(account.id)
        }
        registry.accounts[index] = account
        try self.saveRegistry(registry)
    }

    public func removeAccount(id: UUID) throws -> ManagedAccount {
        var registry = try self.loadRegistry()
        guard let index = registry.accounts.firstIndex(where: { $0.id == id }) else {
            throw ManagedAccountStoreError.accountNotFound(id)
        }
        let removed = registry.accounts.remove(at: index)
        try self.saveRegistry(registry)
        return removed
    }

    private func matchingAccountIndex(
        in accounts: [ManagedAccount],
        candidate: AuthenticatedManagedAccount,
        existingAccountID: UUID?)
        -> Int?
    {
        if let existingAccountID,
           let index = accounts.firstIndex(where: { $0.id == existingAccountID })
        {
            return index
        }

        let normalizedEmail = ManagedAccount.normalizeEmail(candidate.email)
        return accounts.firstIndex {
            $0.email == normalizedEmail && $0.managedHomePath == candidate.managedHomePath
        }
    }

    private func loadRegistry() throws -> ManagedAccountRegistry {
        guard self.fileManager.fileExists(atPath: self.registryURL.path) else {
            return ManagedAccountRegistry(version: Self.currentVersion, accounts: [])
        }

        let data = try Data(contentsOf: self.registryURL)
        let decoder = JSONDecoder()
        let registry = try decoder.decode(ManagedAccountRegistry.self, from: data)
        guard registry.version == Self.currentVersion else {
            throw ManagedAccountStoreError.unsupportedVersion(registry.version)
        }
        return registry
    }

    private func saveRegistry(_ registry: ManagedAccountRegistry) throws {
        let directory = self.registryURL.deletingLastPathComponent()
        if !self.fileManager.fileExists(atPath: directory.path) {
            try self.fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let normalizedRegistry = ManagedAccountRegistry(
            version: Self.currentVersion,
            accounts: registry.accounts)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(normalizedRegistry)
        try data.write(to: self.registryURL, options: [.atomic])
        try self.applySecurePermissions()
    }

    private func applySecurePermissions() throws {
        #if os(macOS)
        try self.fileManager.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: self.registryURL.path)
        #endif
    }
}
