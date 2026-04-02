import CodeRelayApp
import CodeRelayCore
import Foundation
import Testing

@Suite struct WarningPreferencesStoreTests {
    @MainActor
    @Test
    func warningPreferencesStore_loadsDefaults() throws {
        let defaults = try Self.makeDefaults("defaults")
        let store = Self.makeStore(defaults: defaults)

        let preferences = store.loadPreferences()

        #expect(preferences == .defaultValue)
        #expect(preferences.thresholdPercent == 5)
        #expect(preferences.refreshCadence == .fiveMinutes)
        #expect(preferences.notificationsEnabled)
        #expect(store.loadNotificationState() == .defaultValue)
    }

    @MainActor
    @Test
    func warningPreferencesStore_roundTripsPreferencesAndNotificationState() throws {
        let defaults = try Self.makeDefaults("roundtrip")
        let store = Self.makeStore(defaults: defaults)
        let state = WarningNotificationState(suppressedAccountIDs: [UUID()])

        store.savePreferences(WarningPreferences(
            thresholdPercent: 35,
            refreshCadence: .fifteenMinutes,
            notificationsEnabled: false))
        store.saveNotificationState(state)

        #expect(store.loadPreferences() == WarningPreferences(
            thresholdPercent: 35,
            refreshCadence: .fifteenMinutes,
            notificationsEnabled: false))
        #expect(store.loadNotificationState() == state)
    }

    @MainActor
    @Test
    func warningPreferencesStore_fallsBackWhenNotificationStateBlobIsCorrupted() throws {
        let defaults = try Self.makeDefaults("corrupted")
        defaults.set(Data("bad".utf8), forKey: AppContainer.warningNotificationStateKey)
        let store = Self.makeStore(defaults: defaults)

        #expect(store.loadNotificationState() == .defaultValue)
    }

    private static func makeDefaults(_ suffix: String) throws -> UserDefaults {
        let suite = "WarningPreferencesStoreTests.\(suffix)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @MainActor
    private static func makeStore(defaults: UserDefaults) -> UserDefaultsWarningPreferencesStore {
        UserDefaultsWarningPreferencesStore(
            userDefaults: defaults,
            thresholdPercentKey: AppContainer.warningThresholdPercentKey,
            refreshCadenceKey: AppContainer.warningRefreshCadenceKey,
            notificationsEnabledKey: AppContainer.warningNotificationsEnabledKey,
            notificationStateKey: AppContainer.warningNotificationStateKey)
    }
}
