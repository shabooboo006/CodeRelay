import CodeRelayCore
import Combine
import Foundation

@MainActor
final class ActiveAccountRefreshScheduler {
    typealias RefreshOperation = @MainActor () async -> Void
    typealias LoopStarter = @MainActor (TimeInterval, @escaping RefreshOperation) -> any ActiveAccountRefreshLoopHandle

    private let feature: AccountsFeature
    private let loopStarter: LoopStarter

    private var stateObservation: AnyCancellable?
    private var loopHandle: (any ActiveAccountRefreshLoopHandle)?
    private var loopSignature: LoopSignature?

    convenience init(feature: AccountsFeature) {
        self.init(feature: feature, loopStarter: Self.defaultLoopStarter)
    }

    init(
        feature: AccountsFeature,
        loopStarter: @escaping LoopStarter)
    {
        self.feature = feature
        self.loopStarter = loopStarter
    }

    func start() {
        guard self.stateObservation == nil else {
            return
        }

        self.stateObservation = self.feature.$state
            .sink { [weak self] state in
                self?.apply(state: state)
            }

        self.apply(state: self.feature.state)
    }

    func stop() {
        self.stateObservation = nil
        self.loopSignature = nil
        self.cancelLoop()
    }

    private func apply(state: AccountsFeature.State) {
        let signature = LoopSignature(
            activeManagedAccountID: state.activeManagedAccountID,
            refreshCadence: state.warningPreferences.refreshCadence)

        guard signature != self.loopSignature else {
            return
        }

        self.loopSignature = signature
        self.cancelLoop()

        guard let seconds = signature.refreshCadence.seconds,
              signature.activeManagedAccountID != nil
        else {
            return
        }

        self.loopHandle = self.loopStarter(seconds) { [weak feature = self.feature] in
            await feature?.run(.refreshActiveMonitoring)
        }
    }

    private func cancelLoop() {
        self.loopHandle?.cancel()
        self.loopHandle = nil
    }

    private static func defaultLoopStarter(
        seconds: TimeInterval,
        operation: @escaping RefreshOperation)
        -> any ActiveAccountRefreshLoopHandle
    {
        TaskBackedActiveAccountRefreshLoopHandle(task: Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: Self.nanoseconds(for: seconds))
                } catch {
                    break
                }

                guard !Task.isCancelled else {
                    break
                }

                await operation()
            }
        })
    }

    private static func nanoseconds(for seconds: TimeInterval) -> UInt64 {
        UInt64(seconds * 1_000_000_000)
    }
}

private struct LoopSignature: Equatable {
    let activeManagedAccountID: UUID?
    let refreshCadence: WarningRefreshCadence
}

@MainActor
protocol ActiveAccountRefreshLoopHandle: AnyObject {
    func cancel()
}

@MainActor
private final class TaskBackedActiveAccountRefreshLoopHandle: ActiveAccountRefreshLoopHandle {
    private let task: Task<Void, Never>

    init(task: Task<Void, Never>) {
        self.task = task
    }

    func cancel() {
        self.task.cancel()
    }
}
