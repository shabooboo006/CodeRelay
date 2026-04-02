import Foundation

@MainActor
enum CodeRelayRuntimeStore {
    static var shared: CodeRelayRuntime?
}

@MainActor
final class CodeRelayRuntime {
    let container: AppContainer
    let feature: AccountsFeature
    private let refreshScheduler: ActiveAccountRefreshScheduler

    init(container: AppContainer) {
        self.container = container
        self.feature = container.makeAccountsFeature()
        self.refreshScheduler = ActiveAccountRefreshScheduler(feature: self.feature)
    }

    convenience init() {
        self.init(container: AppContainer())
    }

    func start() {
        if self.feature.state.warningPreferences.notificationsEnabled {
            self.container.services.warningNotifier.requestAuthorizationOnStartup()
        }
        self.refreshScheduler.start()
    }

    func stop() {
        self.refreshScheduler.stop()
    }
}
