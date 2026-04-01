import CodeRelayCore
import Foundation

public protocol CredentialStoreDetector: Sendable {
    func credentialStoreMode(in scope: CodexHomeScope) throws -> CredentialStoreMode
    func detectSupport(in scope: CodexHomeScope) throws -> AccountSupportState
}

public struct DefaultCredentialStoreDetector: CredentialStoreDetector, Sendable {
    private let fileManager: FileManager
    private let identityReader: any CodexIdentityReader

    public init(
        fileManager: FileManager = .default,
        identityReader: any CodexIdentityReader = DefaultCodexIdentityReader())
    {
        self.fileManager = fileManager
        self.identityReader = identityReader
    }

    public func credentialStoreMode(in scope: CodexHomeScope) throws -> CredentialStoreMode {
        guard self.fileManager.fileExists(atPath: scope.configFileURL.path) else {
            return .unknown
        }

        let contents = try String(contentsOf: scope.configFileURL, encoding: .utf8)
        for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("cli_auth_credentials_store") else { continue }

            if line.contains(#""file""#) || line.contains("'file'") {
                return .file
            }
            if line.contains(#""keyring""#) || line.contains("'keyring'") {
                return .keyring
            }
            if line.contains(#""auto""#) || line.contains("'auto'") {
                return .auto
            }
            return .unknown
        }

        return .unknown
    }

    public func detectSupport(in scope: CodexHomeScope) throws -> AccountSupportState {
        let mode = try self.credentialStoreMode(in: scope)
        let authFileExists = self.fileManager.fileExists(atPath: scope.authFileURL.path)
        let identityVerified = (try self.identityReader.readIdentity(in: scope)) != nil

        switch mode {
        case .file:
            return authFileExists && identityVerified
                ? .supported
                : .unverified("File-backed auth is missing a verified auth.json identity.")
        case .keyring:
            return .unsupported("Keychain-backed auth cannot be switched reliably by file isolation.")
        case .auto:
            return authFileExists && identityVerified
                ? .supported
                : .unverified("Auto auth storage has not been verified as file-backed.")
        case .unknown:
            return .unverified("Unable to determine cli_auth_credentials_store from the managed config.")
        }
    }
}
