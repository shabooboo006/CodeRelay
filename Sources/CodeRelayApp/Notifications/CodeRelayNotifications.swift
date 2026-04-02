import CodeRelayCore
import Foundation
@preconcurrency import UserNotifications

@MainActor
public protocol WarningNotifying: AnyObject {
    func requestAuthorizationOnStartup()
    func postLowUsageWarning(idPrefix: String, title: String, body: String)
}

@MainActor
public final class CodeRelayNotifications: WarningNotifying {
    private let centerProvider: @Sendable () -> UNUserNotificationCenter
    private var authorizationTask: Task<Bool, Never>?

    public init(centerProvider: @escaping @Sendable () -> UNUserNotificationCenter = { UNUserNotificationCenter.current() }) {
        self.centerProvider = centerProvider
    }

    public func requestAuthorizationOnStartup() {
        guard !Self.isRunningUnderTests else { return }
        _ = self.ensureAuthorizationTask()
    }

    public func postLowUsageWarning(idPrefix: String, title: String, body: String) {
        guard !Self.isRunningUnderTests else { return }
        let center = self.centerProvider()

        Task { @MainActor in
            let granted = await self.ensureAuthorized()
            guard granted else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "coderelay-warning-\(idPrefix)-\(UUID().uuidString)",
                content: content,
                trigger: nil)

            try? await center.add(request)
        }
    }

    private func ensureAuthorizationTask() -> Task<Bool, Never> {
        if let authorizationTask {
            return authorizationTask
        }

        let task = Task { @MainActor in
            await self.requestAuthorization()
        }
        self.authorizationTask = task
        return task
    }

    private func ensureAuthorized() async -> Bool {
        await self.ensureAuthorizationTask().value
    }

    private func requestAuthorization() async -> Bool {
        if let status = await self.notificationAuthorizationStatus() {
            if status == .authorized || status == .provisional {
                return true
            }
            if status == .denied {
                return false
            }
        }

        let center = self.centerProvider()
        return await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private func notificationAuthorizationStatus() async -> UNAuthorizationStatus? {
        let center = self.centerProvider()
        return await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    private static var isRunningUnderTests: Bool {
        if Bundle.main.bundleURL.pathExtension != "app" { return true }
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil { return true }
        if env["TESTING_LIBRARY_VERSION"] != nil { return true }
        if env["SWIFT_TESTING"] != nil { return true }
        return NSClassFromString("XCTestCase") != nil
    }
}
