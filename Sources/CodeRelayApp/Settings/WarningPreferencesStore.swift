import CodeRelayCore
import Foundation

@MainActor
public protocol WarningPreferencesStoring: AnyObject {
    func loadPreferences() -> WarningPreferences
    func savePreferences(_ preferences: WarningPreferences)
    func loadNotificationState() -> WarningNotificationState
    func saveNotificationState(_ state: WarningNotificationState)
}

@MainActor
public final class UserDefaultsWarningPreferencesStore: WarningPreferencesStoring {
    private let userDefaults: UserDefaults
    private let thresholdPercentKey: String
    private let refreshCadenceKey: String
    private let notificationsEnabledKey: String
    private let notificationStateKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        userDefaults: UserDefaults = .standard,
        thresholdPercentKey: String,
        refreshCadenceKey: String,
        notificationsEnabledKey: String,
        notificationStateKey: String)
    {
        self.userDefaults = userDefaults
        self.thresholdPercentKey = thresholdPercentKey
        self.refreshCadenceKey = refreshCadenceKey
        self.notificationsEnabledKey = notificationsEnabledKey
        self.notificationStateKey = notificationStateKey
    }

    public func loadPreferences() -> WarningPreferences {
        let thresholdPercent = self.userDefaults.object(forKey: self.thresholdPercentKey) as? Double
            ?? WarningPreferences.defaultThresholdPercent
        let refreshCadence = self.userDefaults.string(forKey: self.refreshCadenceKey)
            .flatMap(WarningRefreshCadence.init(rawValue:))
            ?? .defaultValue
        let notificationsEnabled = self.userDefaults.object(forKey: self.notificationsEnabledKey) as? Bool
            ?? WarningPreferences.defaultNotificationsEnabled

        return WarningPreferences(
            thresholdPercent: thresholdPercent,
            refreshCadence: refreshCadence,
            notificationsEnabled: notificationsEnabled)
    }

    public func savePreferences(_ preferences: WarningPreferences) {
        self.userDefaults.set(preferences.thresholdPercent, forKey: self.thresholdPercentKey)
        self.userDefaults.set(preferences.refreshCadence.rawValue, forKey: self.refreshCadenceKey)
        self.userDefaults.set(preferences.notificationsEnabled, forKey: self.notificationsEnabledKey)
    }

    public func loadNotificationState() -> WarningNotificationState {
        guard let data = self.userDefaults.data(forKey: self.notificationStateKey),
              let decoded = try? self.decoder.decode(WarningNotificationState.self, from: data)
        else {
            return .defaultValue
        }
        return decoded
    }

    public func saveNotificationState(_ state: WarningNotificationState) {
        guard let data = try? self.encoder.encode(state) else {
            return
        }
        self.userDefaults.set(data, forKey: self.notificationStateKey)
    }
}
