import AppKit
import Foundation

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

        let titleItem = NSMenuItem(
            title: CodeRelayMenuPresentation.headerTitle(for: state),
            action: nil,
            keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        for line in CodeRelayMenuPresentation.detailLines(for: state) {
            let item = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        if let message = state.message, !message.isEmpty {
            menu.addItem(.separator())
            let messageItem = NSMenuItem(title: message, action: nil, keyEquivalent: "")
            messageItem.isEnabled = false
            menu.addItem(messageItem)
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

            if state.rows.count > 1 {
                let switchActiveItem = NSMenuItem(
                    title: self.localized("menu.action.switchActive"),
                    action: nil,
                    keyEquivalent: "")
                switchActiveItem.submenu = self.makeSwitchActiveMenu(state: state)
                menu.addItem(switchActiveItem)
            }

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

    private func makeSwitchActiveMenu(state: AccountsFeature.State) -> NSMenu {
        let menu = NSMenu()

        for row in state.rows {
            let item = NSMenuItem(title: row.email, action: #selector(self.setActiveAccount(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = row.id
            item.state = row.isActive ? .on : .off
            item.isEnabled = !row.isActive && !state.isBusy
            menu.addItem(item)
        }

        return menu
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
    private func setActiveAccount(_ sender: NSMenuItem) {
        guard let accountID = sender.representedObject as? UUID else {
            return
        }

        Task {
            await self.feature.run(.setActive(accountID))
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
