import Foundation

public enum CredentialStoreMode: String, Codable, CaseIterable, Sendable {
    case file
    case keyring
    case auto
    case unknown
}

public struct ManagedAccountIdentity: Codable, Equatable, Sendable {
    public var email: String
    public var workspaceID: String?

    public init(email: String, workspaceID: String? = nil) {
        self.email = ManagedAccount.normalizeEmail(email)
        self.workspaceID = workspaceID
    }

    public func matches(_ account: ManagedAccount) -> Bool {
        self.email == account.email
    }
}

public struct ManagedAccount: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var email: String
    public var managedHomePath: String
    public var createdAt: Date
    public var updatedAt: Date
    public var lastAuthenticatedAt: Date?
    public var credentialStoreMode: CredentialStoreMode
    public var switchSupport: AccountSupportState
    public var lastValidatedIdentity: ManagedAccountIdentity?

    public init(
        id: UUID,
        email: String,
        managedHomePath: String,
        createdAt: Date,
        updatedAt: Date,
        lastAuthenticatedAt: Date?,
        credentialStoreMode: CredentialStoreMode,
        switchSupport: AccountSupportState,
        lastValidatedIdentity: ManagedAccountIdentity? = nil)
    {
        self.id = id
        self.email = Self.normalizeEmail(email)
        self.managedHomePath = managedHomePath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastAuthenticatedAt = lastAuthenticatedAt
        self.credentialStoreMode = credentialStoreMode
        self.switchSupport = switchSupport
        self.lastValidatedIdentity = lastValidatedIdentity
    }

    public static func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public var managedHomeURL: URL {
        URL(fileURLWithPath: self.managedHomePath, isDirectory: true)
    }

    public var accountSupportState: AccountSupportState {
        self.switchSupport
    }
}
