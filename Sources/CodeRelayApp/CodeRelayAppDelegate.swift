import AppKit
import Combine
import Foundation

@MainActor
final class CodeRelayAppDelegate: NSObject, NSApplicationDelegate {
    private var runtime: CodeRelayRuntime?
    private var windowCoordinator: CodeRelayWindowCoordinator?
    private var statusItemController: CodeRelayStatusItemController?
    private var stateObservation: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = notification
        NSApp.setActivationPolicy(.accessory)

        guard let runtime = CodeRelayRuntimeStore.shared else {
            assertionFailure("CodeRelay runtime was not configured before launch.")
            return
        }

        self.runtime = runtime

        let windowCoordinator = CodeRelayWindowCoordinator(feature: runtime.feature)
        let statusItemController = CodeRelayStatusItemController(
            feature: runtime.feature,
            windowCoordinator: windowCoordinator)

        self.windowCoordinator = windowCoordinator
        self.statusItemController = statusItemController
        self.apply(state: runtime.feature.state)

        self.stateObservation = runtime.feature.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.apply(state: state)
            }
    }

    private func apply(state: AccountsFeature.State) {
        self.windowCoordinator?.apply(state: state)
        self.statusItemController?.apply(state: state)
    }
}
