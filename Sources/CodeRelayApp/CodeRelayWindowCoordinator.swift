import AppKit
import SwiftUI

@MainActor
final class CodeRelayWindowCoordinator {
    private let feature: AccountsFeature
    private var setupWindowController: NSWindowController?
    private var managementWindowController: NSWindowController?

    init(feature: AccountsFeature) {
        self.feature = feature
    }

    func apply(state: AccountsFeature.State) {
        if CodeRelayMenuPresentation.launchMode(for: state) == .setupWindow {
            self.showSetupWindow()
        } else {
            self.closeSetupWindow()
        }

        self.setupWindowController?.window?.title = self.localized("setup.window.title")
        self.managementWindowController?.window?.title = self.localized("manage.window.title")
    }

    func showSetupWindow() {
        let controller = self.setupWindowController ?? self.makeSetupWindowController()
        self.setupWindowController = controller
        self.present(controller: controller)
    }

    func showManagementWindow() {
        let controller = self.managementWindowController ?? self.makeManagementWindowController()
        self.managementWindowController = controller
        self.present(controller: controller)
    }

    private func closeSetupWindow() {
        self.setupWindowController?.close()
    }

    private func makeSetupWindowController() -> NSWindowController {
        self.makeWindowController(
            title: self.localized("setup.window.title"),
            size: NSSize(width: 540, height: 430),
            styleMask: [.titled, .closable, .miniaturizable],
            view: AccountsView(feature: self.feature, mode: .setup))
    }

    private func makeManagementWindowController() -> NSWindowController {
        self.makeWindowController(
            title: self.localized("manage.window.title"),
            size: NSSize(width: 760, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            view: AccountsView(feature: self.feature, mode: .management))
    }

    private func present(controller: NSWindowController) {
        guard let window = controller.window else {
            return
        }

        window.center()
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindowController<Content: View>(
        title: String,
        size: NSSize,
        styleMask: NSWindow.StyleMask,
        view: Content)
        -> NSWindowController
    {
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = title
        window.setContentSize(size)
        window.styleMask = styleMask
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenNone]
        return NSWindowController(window: window)
    }

    private func localized(_ key: String) -> String {
        CodeRelayLocalizer.text(key, language: self.feature.state.selectedLanguage)
    }
}
