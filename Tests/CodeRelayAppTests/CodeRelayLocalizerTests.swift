import Foundation
import Testing
@testable import CodeRelayApp

@Suite struct CodeRelayLocalizerTests {
    @Test
    func resourceBundleURL_findsBundleAtPackagedAppRoot() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodeRelayLocalizerTests.\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let appURL = root.appendingPathComponent("CodeRelay.app", isDirectory: true)
        let bundleURL = appURL.appendingPathComponent(CodeRelayLocalizer.resourceBundleName, isDirectory: true)
        try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        let resolvedURL = CodeRelayLocalizer.resourceBundleURL(
            mainBundleURL: appURL,
            mainResourceURL: appURL.appendingPathComponent("Contents/Resources", isDirectory: true),
            executableURL: appURL.appendingPathComponent("Contents/MacOS/CodeRelayApp"),
            hostingBundleResourceURL: nil,
            fileManager: fileManager)

        #expect(resolvedURL == bundleURL.standardizedFileURL)
    }

    @Test
    func resourceBundleURL_findsBundleInsideContentsResources() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodeRelayLocalizerTests.\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let appURL = root.appendingPathComponent("CodeRelay.app", isDirectory: true)
        let resourcesURL = appURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let bundleURL = resourcesURL.appendingPathComponent(CodeRelayLocalizer.resourceBundleName, isDirectory: true)
        try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        let resolvedURL = CodeRelayLocalizer.resourceBundleURL(
            mainBundleURL: appURL,
            mainResourceURL: resourcesURL,
            executableURL: appURL.appendingPathComponent("Contents/MacOS/CodeRelayApp"),
            hostingBundleResourceURL: nil,
            fileManager: fileManager)

        #expect(resolvedURL == bundleURL.standardizedFileURL)
    }

    @Test
    func resourceBundleURL_walksUpFromSwiftTestingRunnerLayout() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CodeRelayLocalizerTests.\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let debugDirectory = root.appendingPathComponent(".build/arm64-apple-macosx/debug", isDirectory: true)
        let testBundleURL = debugDirectory.appendingPathComponent("CodeRelayPackageTests.xctest", isDirectory: true)
        let resourcesURL = testBundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let executableURL = testBundleURL.appendingPathComponent("Contents/MacOS/CodeRelayPackageTests")
        let bundleURL = debugDirectory.appendingPathComponent(CodeRelayLocalizer.resourceBundleName, isDirectory: true)
        try fileManager.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        let resolvedURL = CodeRelayLocalizer.resourceBundleURL(
            mainBundleURL: testBundleURL,
            mainResourceURL: resourcesURL,
            executableURL: executableURL,
            hostingBundleResourceURL: resourcesURL,
            fileManager: fileManager)

        #expect(resolvedURL == bundleURL.standardizedFileURL)
    }
}
