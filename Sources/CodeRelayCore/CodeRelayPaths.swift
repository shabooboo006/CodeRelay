import Foundation

public struct CodeRelayPaths: Equatable, Sendable {
    public static let appDirectoryName = "CodeRelay"
    public static let managedAccountsFileName = "managed-codex-accounts.json"
    public static let managedHomesDirectoryName = "managed-codex-homes"

    public let applicationSupportRoot: URL

    public init(applicationSupportRoot: URL = Self.defaultApplicationSupportRoot()) {
        self.applicationSupportRoot = applicationSupportRoot
    }

    public var appDirectory: URL {
        self.applicationSupportRoot.appendingPathComponent(Self.appDirectoryName, isDirectory: true)
    }

    public var managedAccountsStoreURL: URL {
        self.appDirectory.appendingPathComponent(Self.managedAccountsFileName)
    }

    public var managedHomesRoot: URL {
        self.appDirectory.appendingPathComponent(Self.managedHomesDirectoryName, isDirectory: true)
    }

    public static func defaultApplicationSupportRoot(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
    }
}
