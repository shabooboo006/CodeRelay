import AppKit
import SwiftUI

@main
struct CodeRelayApp: App {
    @NSApplicationDelegateAdaptor(CodeRelayAppDelegate.self) private var appDelegate
    private let runtime: CodeRelayRuntime

    init() {
        let runtime = CodeRelayRuntime()
        self.runtime = runtime
        CodeRelayRuntimeStore.shared = runtime
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
