import CodeRelayCore
import Foundation
import Testing

@Suite struct ManagedHomeSafetyTests {
    @Test
    func Phase1_managedHomeSafety_acceptsManagedRootDescendants() throws {
        let paths = CodeRelayPaths(applicationSupportRoot: URL(fileURLWithPath: "/tmp/relay-root", isDirectory: true))
        let candidate = paths.managedHomesRoot.appendingPathComponent("account-id", isDirectory: true)

        try DefaultManagedHomeSafety(paths: paths).validateRemovalTarget(candidate)
    }

    @Test
    func Phase1_managedHomeSafety_rejectsManagedRootItself() {
        let paths = CodeRelayPaths(applicationSupportRoot: URL(fileURLWithPath: "/tmp/relay-root", isDirectory: true))

        #expect(throws: ManagedHomeSafetyError.outsideManagedRoot) {
            try DefaultManagedHomeSafety(paths: paths).validateRemovalTarget(paths.managedHomesRoot)
        }
    }

    @Test
    func Phase1_managedHomeSafety_rejectsPathsOutsideManagedRoot() {
        let paths = CodeRelayPaths(applicationSupportRoot: URL(fileURLWithPath: "/tmp/relay-root", isDirectory: true))
        let outsider = URL(fileURLWithPath: "/tmp/not-managed/account-id", isDirectory: true)

        #expect(throws: ManagedHomeSafetyError.outsideManagedRoot) {
            try DefaultManagedHomeSafety(paths: paths).validateRemovalTarget(outsider)
        }
    }
}
