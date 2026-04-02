import Foundation

@MainActor
enum CodeRelayRuntimeStore {
    static var shared: CodeRelayRuntime?
}

@MainActor
final class CodeRelayRuntime {
    let container: AppContainer
    let feature: AccountsFeature

    init(container: AppContainer) {
        self.container = container
        self.feature = container.makeAccountsFeature()
    }

    convenience init() {
        self.init(container: AppContainer())
    }
}
