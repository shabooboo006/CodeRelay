import AppKit
import Foundation
import SwiftUI

@MainActor
final class CodeRelayStatusItemController: NSObject {
    private let feature: AccountsFeature
    private let windowCoordinator: CodeRelayWindowCoordinator
    private let statusItem: NSStatusItem

    init(
        feature: AccountsFeature,
        windowCoordinator: CodeRelayWindowCoordinator,
        statusBar: NSStatusBar = .system)
    {
        self.feature = feature
        self.windowCoordinator = windowCoordinator
        self.statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        self.statusItem.button?.imageScaling = .scaleNone
        self.statusItem.button?.toolTip = "CodeRelay"
    }

    func apply(state: AccountsFeature.State) {
        self.statusItem.button?.image = CodeRelayStatusIconRenderer.makeIcon(
            hasAccounts: !state.rows.isEmpty,
            status: CodeRelayMenuPresentation.iconStatus(for: state),
            isBusy: state.isBusy)
        self.statusItem.menu = self.makeMenu(state: state)
    }

    private func makeMenu(state: AccountsFeature.State) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(self.makeHostedItem(
            CodeRelayMenuSummaryView(model: CodeRelayMenuPresentation.summary(for: state))))

        if let message = state.message, !message.isEmpty {
            menu.addItem(self.makeHostedItem(
                CodeRelayMenuMessageView(message: message, isBusy: state.isBusy)))
        }

        menu.addItem(.separator())

        if state.rows.isEmpty {
            menu.addItem(self.makeItem(
                title: self.localized("menu.action.openSetup"),
                action: #selector(self.openSetupWindow)))
        } else {
            let refreshItem = self.makeItem(
                title: self.localized("accounts.action.refreshUsage"),
                action: #selector(self.refreshUsage))
            refreshItem.isEnabled = !state.isBusy
            menu.addItem(refreshItem)

            menu.addItem(self.makeItem(
                title: self.localized("menu.action.manageAccounts"),
                action: #selector(self.openManagementWindow)))
        }

        menu.addItem(.separator())
        menu.addItem(self.makeItem(
            title: self.localized("menu.action.quit"),
            action: #selector(self.quit)))

        return menu
    }

    private func makeHostedItem<Content: View>(_ rootView: Content) -> NSMenuItem {
        let item = NSMenuItem()
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.layoutSubtreeIfNeeded()
        hostingView.frame = CGRect(origin: .zero, size: hostingView.fittingSize)
        item.view = hostingView
        item.isEnabled = false
        return item
    }

    private func makeItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc
    private func openSetupWindow() {
        self.windowCoordinator.showSetupWindow()
    }

    @objc
    private func openManagementWindow() {
        self.windowCoordinator.showManagementWindow()
    }

    @objc
    private func refreshUsage() {
        Task {
            await self.feature.run(.refreshMonitoring)
        }
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }

    private func localized(_ key: String) -> String {
        CodeRelayLocalizer.text(key, language: self.feature.state.selectedLanguage)
    }
}
