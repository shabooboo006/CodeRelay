@testable import CodeRelayCodex
import CodeRelayCore
import Foundation
import Testing

@Suite(.serialized) struct CodexLoginRunnerTests {
    @Test
    func Phase1_codexLoginRunner_usesLoginShellPATHToResolveCodex() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let bin = root.appendingPathComponent("bin", isDirectory: true)
        let home = root.appendingPathComponent("home", isDirectory: true)
        let binary = bin.appendingPathComponent("codex", isDirectory: false)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try "#!/bin/sh\nexit 0\n".write(to: binary, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)

        let capturedCommand = LockedBox<CodexLoginCommand?>(nil)
        let runner = DefaultCodexLoginRunner(
            fileManager: .default,
            executor: { command, _ in
                capturedCommand.withValue { $0 = command }
                return "ok"
            },
            loginShellPathProvider: {
                [bin.path]
            })

        let scope = CodexHomeScope(accountID: UUID(), homeURL: home)
        let result = try await runner.login(request: CodexLoginRequest(
            scope: scope,
            baseEnvironment: [
                "PATH": "/usr/bin:/bin",
                "SHELL": "/bin/zsh",
            ]))

        let command = try #require(capturedCommand.value)
        #expect(command.arguments.first == binary.path)
        #expect(result.invokedCommand.first == binary.path)
        #expect(command.environment["CODEX_HOME"] == home.path)
        #expect(command.environment["PATH"] == "\(bin.path):/usr/bin:/bin")

        let config = try String(contentsOf: scope.configFileURL, encoding: .utf8)
        #expect(config.contains(#"cli_auth_credentials_store = "file""#))
    }

    @Test
    func Phase1_codexLoginRunner_reportsMissingBinaryWhenPATHCannotResolveCodex() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let home = root.appendingPathComponent("home", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let runner = DefaultCodexLoginRunner(
            fileManager: .default,
            executor: { _, _ in
                Issue.record("Executor should not run when codex cannot be resolved.")
                return "unexpected"
            },
            loginShellPathProvider: {
                nil
            })

        await #expect(throws: CodexLoginRunnerError.missingBinary) {
            try await runner.login(request: CodexLoginRequest(
                scope: CodexHomeScope(accountID: UUID(), homeURL: home),
                baseEnvironment: [
                    "PATH": "",
                    "SHELL": "/definitely/missing-shell",
                ]))
        }
    }
}

private final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        self.storage = value
    }

    var value: Value {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.storage
    }

    func withValue(_ update: (inout Value) -> Void) {
        self.lock.lock()
        defer { self.lock.unlock() }
        update(&self.storage)
    }
}
