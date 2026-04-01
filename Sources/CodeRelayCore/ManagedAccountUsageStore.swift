import Foundation

public enum ManagedAccountUsageStoreError: Error, Equatable, Sendable {
    case unsupportedVersion(Int)
}

public protocol ManagedAccountUsageStore: Sendable {
    func listSnapshots() throws -> [ManagedAccountUsageSnapshot]
    func snapshot(for accountID: UUID) throws -> ManagedAccountUsageSnapshot?
    func upsert(_ snapshot: ManagedAccountUsageSnapshot) throws
    func removeSnapshot(for accountID: UUID) throws
}

public struct ManagedAccountUsageRegistry: Codable, Equatable, Sendable {
    public let version: Int
    public var snapshots: [ManagedAccountUsageSnapshot]

    public init(version: Int, snapshots: [ManagedAccountUsageSnapshot]) {
        self.version = version
        self.snapshots = Self.sanitized(snapshots)
    }

    private static func sanitized(_ snapshots: [ManagedAccountUsageSnapshot]) -> [ManagedAccountUsageSnapshot] {
        var seenAccountIDs: Set<UUID> = []
        var sanitizedSnapshots: [ManagedAccountUsageSnapshot] = []
        sanitizedSnapshots.reserveCapacity(snapshots.count)

        for snapshot in snapshots {
            guard seenAccountIDs.insert(snapshot.accountID).inserted else { continue }
            sanitizedSnapshots.append(snapshot)
        }

        return sanitizedSnapshots
    }
}

public struct JSONManagedAccountUsageStore: ManagedAccountUsageStore, @unchecked Sendable {
    public static let currentVersion = 1

    public let paths: CodeRelayPaths
    public let storeURL: URL
    public let fileManager: FileManager

    public init(
        paths: CodeRelayPaths = CodeRelayPaths(),
        fileManager: FileManager = .default)
    {
        self.paths = paths
        self.storeURL = paths.managedAccountUsageStoreURL
        self.fileManager = fileManager
    }

    public func listSnapshots() throws -> [ManagedAccountUsageSnapshot] {
        try self.loadRegistry().snapshots.sorted { lhs, rhs in
            lhs.accountID.uuidString < rhs.accountID.uuidString
        }
    }

    public func snapshot(for accountID: UUID) throws -> ManagedAccountUsageSnapshot? {
        try self.loadRegistry().snapshots.first { $0.accountID == accountID }
    }

    public func upsert(_ snapshot: ManagedAccountUsageSnapshot) throws {
        var registry = try self.loadRegistry()

        if let index = registry.snapshots.firstIndex(where: { $0.accountID == snapshot.accountID }) {
            registry.snapshots[index] = snapshot
        } else {
            registry.snapshots.append(snapshot)
        }

        try self.saveRegistry(registry)
    }

    public func removeSnapshot(for accountID: UUID) throws {
        var registry = try self.loadRegistry()
        registry.snapshots.removeAll { $0.accountID == accountID }
        try self.saveRegistry(registry)
    }

    private func loadRegistry() throws -> ManagedAccountUsageRegistry {
        guard self.fileManager.fileExists(atPath: self.storeURL.path) else {
            return ManagedAccountUsageRegistry(version: Self.currentVersion, snapshots: [])
        }

        let data = try Data(contentsOf: self.storeURL)
        let decoder = JSONDecoder()
        let registry = try decoder.decode(ManagedAccountUsageRegistry.self, from: data)
        guard registry.version == Self.currentVersion else {
            throw ManagedAccountUsageStoreError.unsupportedVersion(registry.version)
        }
        return registry
    }

    private func saveRegistry(_ registry: ManagedAccountUsageRegistry) throws {
        let directory = self.storeURL.deletingLastPathComponent()
        if !self.fileManager.fileExists(atPath: directory.path) {
            try self.fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let normalizedRegistry = ManagedAccountUsageRegistry(
            version: Self.currentVersion,
            snapshots: registry.snapshots)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(normalizedRegistry)
        try data.write(to: self.storeURL, options: [.atomic])
        try self.applySecurePermissions()
    }

    private func applySecurePermissions() throws {
        #if os(macOS)
        try self.fileManager.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: self.storeURL.path)
        #endif
    }
}
