import CodeRelayCore
import Foundation

public struct CodexHomeScope: Equatable, Sendable {
    public let accountID: UUID
    public let homeURL: URL

    public init(accountID: UUID, paths: CodeRelayPaths = CodeRelayPaths()) {
        self.accountID = accountID
        self.homeURL = paths.managedHomesRoot.appendingPathComponent(accountID.uuidString, isDirectory: true)
    }

    public init(accountID: UUID, homeURL: URL) {
        self.accountID = accountID
        self.homeURL = homeURL
    }

    public func environment(base: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        Self.scopedEnvironment(base: base, codexHome: self.homeURL.path)
    }

    public var authFileURL: URL {
        self.homeURL.appendingPathComponent("auth.json", isDirectory: false)
    }

    public var configFileURL: URL {
        self.homeURL.appendingPathComponent("config.toml", isDirectory: false)
    }

    public func ensureHomeExists(fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: self.homeURL, withIntermediateDirectories: true)
    }

    public static func ambientHomeURL(
        env: [String: String],
        fileManager: FileManager = .default)
        -> URL
    {
        if let raw = env["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            return URL(fileURLWithPath: raw, isDirectory: true)
        }

        return fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
    }

    public static func scopedEnvironment(base: [String: String], codexHome: String?) -> [String: String] {
        guard let codexHome, !codexHome.isEmpty else { return base }
        var env = base
        env["CODEX_HOME"] = codexHome
        return env
    }
}
