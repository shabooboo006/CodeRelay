import Foundation

public enum ManagedHomeSafetyError: Error, Equatable, Sendable {
    case outsideManagedRoot
}

public protocol ManagedHomeSafety: Sendable {
    func validateRemovalTarget(_ url: URL) throws
}

public struct DefaultManagedHomeSafety: ManagedHomeSafety, Sendable {
    public let paths: CodeRelayPaths

    public init(paths: CodeRelayPaths = CodeRelayPaths()) {
        self.paths = paths
    }

    public func validateRemovalTarget(_ url: URL) throws {
        let candidatePath = url.resolvingSymlinksInPath().standardizedFileURL.path
        let rootPath = self.paths.managedHomesRoot.resolvingSymlinksInPath().standardizedFileURL.path
        let rootPrefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"

        guard candidatePath != rootPath, candidatePath.hasPrefix(rootPrefix) else {
            throw ManagedHomeSafetyError.outsideManagedRoot
        }
    }
}
