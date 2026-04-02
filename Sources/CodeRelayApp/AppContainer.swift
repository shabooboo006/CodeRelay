import CodeRelayCodex
import CodeRelayCore
import Foundation

public let defaultActiveManagedAccountIDKey = "activeManagedAccountID"
public let defaultPreferredAppLanguageKey = "preferredAppLanguage"
public let defaultWarningThresholdPercentKey = "warningThresholdPercent"
public let defaultWarningRefreshCadenceKey = "warningRefreshCadence"
public let defaultWarningNotificationsEnabledKey = "warningNotificationsEnabled"
public let defaultWarningNotificationStateKey = "warningNotificationState"

@MainActor
public final class AppContainer {
    public static let activeManagedAccountIDKey = defaultActiveManagedAccountIDKey
    public static let preferredAppLanguageKey = defaultPreferredAppLanguageKey
    public static let warningThresholdPercentKey = defaultWarningThresholdPercentKey
    public static let warningRefreshCadenceKey = defaultWarningRefreshCadenceKey
    public static let warningNotificationsEnabledKey = defaultWarningNotificationsEnabledKey
    public static let warningNotificationStateKey = defaultWarningNotificationStateKey

    public struct Services {
        public var paths: CodeRelayPaths
        public var fileManager: FileManager
        public var userDefaults: UserDefaults
        public var activeManagedAccountIDKey: String
        public var preferredAppLanguageKey: String
        public var warningThresholdPercentKey: String
        public var warningRefreshCadenceKey: String
        public var warningNotificationsEnabledKey: String
        public var warningNotificationStateKey: String
        public var managedAccountStore: any ManagedAccountStore
        public var managedAccountUsageStore: any ManagedAccountUsageStore
        public var accountProjection: any AccountProjection
        public var warningEvaluator: any WarningEvaluating
        public var managedHomeSafety: any ManagedHomeSafety
        public var codexLoginRunner: any CodexLoginRunner
        public var codexIdentityReader: any CodexIdentityReader
        public var credentialStoreDetector: any CredentialStoreDetector
        public var codexUsageRefreshService: any CodexUsageRefreshService
        public var warningPreferencesStore: any WarningPreferencesStoring
        public var warningNotifier: any WarningNotifying

        @MainActor
        public init(
            paths: CodeRelayPaths = CodeRelayPaths(),
            fileManager: FileManager = .default,
            userDefaults: UserDefaults = .standard,
            activeManagedAccountIDKey: String = defaultActiveManagedAccountIDKey,
            preferredAppLanguageKey: String = defaultPreferredAppLanguageKey,
            warningThresholdPercentKey: String = defaultWarningThresholdPercentKey,
            warningRefreshCadenceKey: String = defaultWarningRefreshCadenceKey,
            warningNotificationsEnabledKey: String = defaultWarningNotificationsEnabledKey,
            warningNotificationStateKey: String = defaultWarningNotificationStateKey,
            managedAccountStore: (any ManagedAccountStore)? = nil,
            managedAccountUsageStore: (any ManagedAccountUsageStore)? = nil,
            accountProjection: (any AccountProjection)? = nil,
            warningEvaluator: (any WarningEvaluating)? = nil,
            managedHomeSafety: (any ManagedHomeSafety)? = nil,
            codexLoginRunner: (any CodexLoginRunner)? = nil,
            codexIdentityReader: (any CodexIdentityReader)? = nil,
            credentialStoreDetector: (any CredentialStoreDetector)? = nil,
            codexUsageRefreshService: (any CodexUsageRefreshService)? = nil,
            warningPreferencesStore: (any WarningPreferencesStoring)? = nil,
            warningNotifier: (any WarningNotifying)? = nil)
        {
            self.paths = paths
            self.fileManager = fileManager
            self.userDefaults = userDefaults
            self.activeManagedAccountIDKey = activeManagedAccountIDKey
            self.preferredAppLanguageKey = preferredAppLanguageKey
            self.warningThresholdPercentKey = warningThresholdPercentKey
            self.warningRefreshCadenceKey = warningRefreshCadenceKey
            self.warningNotificationsEnabledKey = warningNotificationsEnabledKey
            self.warningNotificationStateKey = warningNotificationStateKey

            let resolvedIdentityReader = codexIdentityReader ?? DefaultCodexIdentityReader(fileManager: fileManager)
            self.codexIdentityReader = resolvedIdentityReader
            self.managedAccountStore = managedAccountStore ?? JSONManagedAccountStore(paths: paths, fileManager: fileManager)
            self.managedAccountUsageStore = managedAccountUsageStore ?? JSONManagedAccountUsageStore(paths: paths, fileManager: fileManager)
            self.accountProjection = accountProjection ?? DefaultAccountProjection()
            self.warningEvaluator = warningEvaluator ?? DefaultWarningEvaluator()
            self.managedHomeSafety = managedHomeSafety ?? DefaultManagedHomeSafety(paths: paths)
            self.codexLoginRunner = codexLoginRunner ?? DefaultCodexLoginRunner(fileManager: fileManager)
            self.credentialStoreDetector = credentialStoreDetector
                ?? DefaultCredentialStoreDetector(fileManager: fileManager, identityReader: resolvedIdentityReader)
            self.codexUsageRefreshService = codexUsageRefreshService ?? DefaultCodexUsageRefreshService()
            self.warningPreferencesStore = warningPreferencesStore ?? UserDefaultsWarningPreferencesStore(
                userDefaults: userDefaults,
                thresholdPercentKey: warningThresholdPercentKey,
                refreshCadenceKey: warningRefreshCadenceKey,
                notificationsEnabledKey: warningNotificationsEnabledKey,
                notificationStateKey: warningNotificationStateKey)
            self.warningNotifier = warningNotifier ?? CodeRelayNotifications()
        }
    }

    public let services: Services

    @MainActor
    public init(services: Services) {
        self.services = services
    }

    @MainActor
    public convenience init() {
        self.init(services: Services())
    }

    public func makeAccountsFeature() -> AccountsFeature {
        let feature = AccountsFeature(services: self.services)
        feature.loadInitialState()
        return feature
    }
}
