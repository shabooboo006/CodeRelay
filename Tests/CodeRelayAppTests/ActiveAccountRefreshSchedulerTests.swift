import CodeRelayCore
import Foundation
import Testing
@testable import CodeRelayApp

@Suite struct ActiveAccountRefreshSchedulerTests {
    @MainActor
    @Test
    func scheduler_startsLoopForActiveAccountWithDefaultCadence() async throws {
        let defaults = try AccountsFeatureTests.makeDefaults("scheduler-start")
        let active = AccountsFeatureTests.makeAccount(email: "active@example.com")
        defaults.set(active.id.uuidString, forKey: AppContainer.activeManagedAccountIDKey)

        let feature = AccountsFeature(services: AccountsFeatureTests.makeServices(
            defaults: defaults,
            store: StubManagedAccountStore(accounts: [active])))
        feature.loadInitialState()

        let loopStarter = RecordingLoopStarter()
        let scheduler = ActiveAccountRefreshScheduler(feature: feature, loopStarter: loopStarter.start)

        scheduler.start()
        scheduler.stop()
        await Self.drainSchedulerTasks()

        #expect(loopStarter.startedIntervals == [WarningRefreshCadence.defaultValue.seconds])
        #expect(loopStarter.cancelledLoops == 1)
    }

    @MainActor
    @Test
    func scheduler_cancelsLoopWhenCadenceBecomesManual() async throws {
        let defaults = try AccountsFeatureTests.makeDefaults("scheduler-manual")
        let active = AccountsFeatureTests.makeAccount(email: "active@example.com")
        defaults.set(active.id.uuidString, forKey: AppContainer.activeManagedAccountIDKey)

        let feature = AccountsFeature(services: AccountsFeatureTests.makeServices(
            defaults: defaults,
            store: StubManagedAccountStore(accounts: [active])))
        feature.loadInitialState()

        let loopStarter = RecordingLoopStarter()
        let scheduler = ActiveAccountRefreshScheduler(feature: feature, loopStarter: loopStarter.start)

        scheduler.start()
        try await feature.perform(.setWarningRefreshCadence(.manual))
        scheduler.stop()
        await Self.drainSchedulerTasks()

        #expect(loopStarter.startedIntervals == [WarningRefreshCadence.defaultValue.seconds])
        #expect(loopStarter.cancelledLoops >= 1)
    }

    @MainActor
    @Test
    func scheduler_restartsLoopWhenCadenceChanges() async throws {
        let defaults = try AccountsFeatureTests.makeDefaults("scheduler-restart")
        let active = AccountsFeatureTests.makeAccount(email: "active@example.com")
        defaults.set(active.id.uuidString, forKey: AppContainer.activeManagedAccountIDKey)

        let feature = AccountsFeature(services: AccountsFeatureTests.makeServices(
            defaults: defaults,
            store: StubManagedAccountStore(accounts: [active])))
        feature.loadInitialState()

        let loopStarter = RecordingLoopStarter()
        let scheduler = ActiveAccountRefreshScheduler(feature: feature, loopStarter: loopStarter.start)

        scheduler.start()
        try await feature.perform(.setWarningRefreshCadence(.oneMinute))
        scheduler.stop()
        await Self.drainSchedulerTasks()

        #expect(loopStarter.startedIntervals == [
            WarningRefreshCadence.fiveMinutes.seconds,
            WarningRefreshCadence.oneMinute.seconds,
        ])
        #expect(loopStarter.cancelledLoops >= 2)
    }

    @MainActor
    private static func drainSchedulerTasks() async {
        await Task.yield()
        await Task.yield()
    }
}

@MainActor
private final class RecordingLoopStarter {
    private(set) var startedIntervals: [TimeInterval?] = []
    var cancelledLoops = 0

    func start(
        seconds: TimeInterval,
        operation: @escaping @MainActor () async -> Void)
        -> any ActiveAccountRefreshLoopHandle
    {
        _ = operation
        self.startedIntervals.append(seconds)
        return RecordingLoopHandle(owner: self)
    }
}

@MainActor
private final class RecordingLoopHandle: ActiveAccountRefreshLoopHandle {
    private unowned let owner: RecordingLoopStarter

    init(owner: RecordingLoopStarter) {
        self.owner = owner
    }

    func cancel() {
        self.owner.cancelledLoops += 1
    }
}
