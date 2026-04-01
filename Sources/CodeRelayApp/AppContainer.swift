import CodeRelayCodex
import CodeRelayCore
import Foundation

public let defaultActiveManagedAccountIDKey = "activeManagedAccountID"

@MainActor
public final class AppContainer {
    public static let activeManagedAccountIDKey = defaultActiveManagedAccountIDKey

    public struct Services {
        public var paths: CodeRelayPaths
        public var fileManager: FileManager
        public var userDefaults: UserDefaults
        public var activeManagedAccountIDKey: String
        public var managedAccountStore: any ManagedAccountStore
        public var managedAccountUsageStore: any ManagedAccountUsageStore
        public var accountProjection: any AccountProjection
        public var managedHomeSafety: any ManagedHomeSafety
        public var codexLoginRunner: any CodexLoginRunner
        public var codexIdentityReader: any CodexIdentityReader
        public var credentialStoreDetector: any CredentialStoreDetector
        public var codexUsageRefreshService: any CodexUsageRefreshService

        public init(
            paths: CodeRelayPaths = CodeRelayPaths(),
            fileManager: FileManager = .default,
            userDefaults: UserDefaults = .standard,
            activeManagedAccountIDKey: String = defaultActiveManagedAccountIDKey,
            managedAccountStore: (any ManagedAccountStore)? = nil,
            managedAccountUsageStore: (any ManagedAccountUsageStore)? = nil,
            accountProjection: (any AccountProjection)? = nil,
            managedHomeSafety: (any ManagedHomeSafety)? = nil,
            codexLoginRunner: (any CodexLoginRunner)? = nil,
            codexIdentityReader: (any CodexIdentityReader)? = nil,
            credentialStoreDetector: (any CredentialStoreDetector)? = nil,
            codexUsageRefreshService: (any CodexUsageRefreshService)? = nil)
        {
            self.paths = paths
            self.fileManager = fileManager
            self.userDefaults = userDefaults
            self.activeManagedAccountIDKey = activeManagedAccountIDKey

            let resolvedIdentityReader = codexIdentityReader ?? DefaultCodexIdentityReader(fileManager: fileManager)
            self.codexIdentityReader = resolvedIdentityReader
            self.managedAccountStore = managedAccountStore ?? JSONManagedAccountStore(paths: paths, fileManager: fileManager)
            self.managedAccountUsageStore = managedAccountUsageStore ?? JSONManagedAccountUsageStore(paths: paths, fileManager: fileManager)
            self.accountProjection = accountProjection ?? DefaultAccountProjection()
            self.managedHomeSafety = managedHomeSafety ?? DefaultManagedHomeSafety(paths: paths)
            self.codexLoginRunner = codexLoginRunner ?? DefaultCodexLoginRunner(fileManager: fileManager)
            self.credentialStoreDetector = credentialStoreDetector
                ?? DefaultCredentialStoreDetector(fileManager: fileManager, identityReader: resolvedIdentityReader)
            self.codexUsageRefreshService = codexUsageRefreshService ?? DefaultCodexUsageRefreshService()
        }
    }

    public let services: Services

    public init(services: Services = Services()) {
        self.services = services
    }

    public func makeAccountsFeature() -> AccountsFeature {
        let feature = AccountsFeature(services: self.services)
        feature.loadInitialState()
        return feature
    }
}
