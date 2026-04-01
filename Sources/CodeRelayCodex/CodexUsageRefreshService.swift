import CodeRelayCore
import Foundation

public struct ManagedAccountUsageRefreshResult: Equatable, Sendable {
    public let accountID: UUID
    public let snapshot: ManagedAccountUsageSnapshot?
    public let status: UsageProbeStatus
    public let source: UsageProbeSource
    public let message: String?

    public init(
        accountID: UUID,
        snapshot: ManagedAccountUsageSnapshot?,
        status: UsageProbeStatus,
        source: UsageProbeSource,
        message: String?)
    {
        self.accountID = accountID
        self.snapshot = snapshot
        self.status = status
        self.source = source
        self.message = message
    }
}

public protocol CodexUsageRefreshService: Sendable {
    func refresh(account: ManagedAccount, cachedSnapshot: ManagedAccountUsageSnapshot?) async -> ManagedAccountUsageRefreshResult
}

public struct DefaultCodexUsageRefreshService: CodexUsageRefreshService, Sendable {
    private let fetcher: any CodexUsageFetcher

    public init(fetcher: any CodexUsageFetcher = DefaultCodexUsageFetcher()) {
        self.fetcher = fetcher
    }

    public func refresh(
        account: ManagedAccount,
        cachedSnapshot: ManagedAccountUsageSnapshot?) async
        -> ManagedAccountUsageRefreshResult
    {
        let scope = CodexHomeScope(accountID: account.id, homeURL: account.managedHomeURL)

        do {
            let snapshot = try await self.fetcher.fetchUsage(in: scope)
            return ManagedAccountUsageRefreshResult(
                accountID: account.id,
                snapshot: snapshot,
                status: snapshot.status,
                source: snapshot.source,
                message: nil)
        } catch {
            let message = Self.failureMessage(for: error)

            if let cachedSnapshot {
                let staleSnapshot = ManagedAccountUsageSnapshot(
                    accountID: account.id,
                    fiveHourWindow: cachedSnapshot.fiveHourWindow,
                    weeklyWindow: cachedSnapshot.weeklyWindow,
                    updatedAt: cachedSnapshot.updatedAt,
                    source: .cache,
                    status: .stale,
                    lastErrorDescription: message)
                return ManagedAccountUsageRefreshResult(
                    accountID: account.id,
                    snapshot: staleSnapshot,
                    status: .stale,
                    source: .cache,
                    message: message)
            }

            if Self.isUnknownCredentialFailure(error) {
                return ManagedAccountUsageRefreshResult(
                    accountID: account.id,
                    snapshot: nil,
                    status: .unknown,
                    source: .unknown,
                    message: message)
            }

            return ManagedAccountUsageRefreshResult(
                accountID: account.id,
                snapshot: nil,
                status: .error,
                source: .managedHomeOAuth,
                message: message)
        }
    }

    private static func isUnknownCredentialFailure(_ error: Error) -> Bool {
        guard let fetchError = error as? CodexUsageFetcherError else {
            return false
        }

        if fetchError == .missingAuthFile || fetchError == .missingAccessToken {
            return true
        }

        return false
    }

    private static func failureMessage(for error: Error) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? String(describing: error) : message
    }
}
