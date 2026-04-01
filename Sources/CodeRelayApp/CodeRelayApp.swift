import SwiftUI

@main
struct CodeRelayApp: App {
    private let container: AppContainer
    @StateObject private var feature: AccountsFeature

    init() {
        let container = AppContainer()
        self.container = container
        self._feature = StateObject(wrappedValue: container.makeAccountsFeature())
    }

    var body: some Scene {
        WindowGroup {
            AccountsView(feature: self.feature)
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}
