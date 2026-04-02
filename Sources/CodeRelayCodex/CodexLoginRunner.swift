import CodeRelayCore
import Darwin
import Foundation

public enum CodexLoginRunnerError: Error, Equatable, Sendable {
    case missingBinary
    case launchFailed(String)
    case timedOut
    case failed(status: Int32, output: String)
}

public struct CodexLoginCommand: Equatable, Sendable {
    public let arguments: [String]
    public let environment: [String: String]

    public init(arguments: [String], environment: [String: String]) {
        self.arguments = arguments
        self.environment = environment
    }
}

public struct CodexLoginRequest: Equatable, Sendable {
    public let scope: CodexHomeScope
    public let existingAccountID: UUID?
    public let timeout: TimeInterval
    public let baseEnvironment: [String: String]

    public init(
        scope: CodexHomeScope,
        existingAccountID: UUID? = nil,
        timeout: TimeInterval = 120,
        baseEnvironment: [String: String] = ProcessInfo.processInfo.environment)
    {
        self.scope = scope
        self.existingAccountID = existingAccountID
        self.timeout = timeout
        self.baseEnvironment = baseEnvironment
    }
}

public struct CodexLoginResult: Equatable, Sendable {
    public let scope: CodexHomeScope
    public let invokedCommand: [String]
    public let environment: [String: String]
    public let output: String

    public init(
        scope: CodexHomeScope,
        invokedCommand: [String],
        environment: [String: String],
        output: String)
    {
        self.scope = scope
        self.invokedCommand = invokedCommand
        self.environment = environment
        self.output = output
    }
}

public protocol CodexLoginRunner: Sendable {
    func login(request: CodexLoginRequest) async throws -> CodexLoginResult
}

public struct DefaultCodexLoginRunner: CodexLoginRunner, @unchecked Sendable {
    public typealias Executor = @Sendable (CodexLoginCommand, TimeInterval) async throws -> String
    typealias LoginShellPathProvider = @Sendable () -> [String]?

    private static let liveExecutor: Executor = { command, timeout in
        try await Self.executeProcess(command: command, timeout: timeout)
    }

    private let fileManager: FileManager
    private let executor: Executor
    private let loginShellPathProvider: LoginShellPathProvider

    public init(fileManager: FileManager = .default) {
        self.init(
            fileManager: fileManager,
            executor: Self.liveExecutor,
            loginShellPathProvider: {
                CodexLoginShellPathCapturer.capture()
            })
    }

    init(
        fileManager: FileManager = .default,
        executor: @escaping Executor,
        loginShellPathProvider: @escaping LoginShellPathProvider)
    {
        self.fileManager = fileManager
        self.executor = executor
        self.loginShellPathProvider = loginShellPathProvider
    }

    public func login(request: CodexLoginRequest) async throws -> CodexLoginResult {
        try request.scope.ensureHomeExists(fileManager: self.fileManager)
        try self.persistManagedConfig(at: request.scope.configFileURL)

        let loginPATH = self.loginShellPathProvider()
        var environment = request.scope.environment(base: request.baseEnvironment)
        environment["PATH"] = CodexCLIPathResolver.effectivePATH(env: environment, loginPATH: loginPATH)
        guard let executable = CodexCLIPathResolver.resolveCodexBinary(
            env: environment,
            loginPATH: loginPATH,
            fileManager: self.fileManager)
        else {
            throw CodexLoginRunnerError.missingBinary
        }

        let command = CodexLoginCommand(
            arguments: [
                executable,
                "-c",
                #"cli_auth_credentials_store="file""#,
                "login",
            ],
            environment: environment)
        let output = try await self.executor(command, request.timeout)

        return CodexLoginResult(
            scope: request.scope,
            invokedCommand: command.arguments,
            environment: environment,
            output: output)
    }

    private func persistManagedConfig(at url: URL) throws {
        let requiredLine = #"cli_auth_credentials_store = "file""#

        let contents: String
        if self.fileManager.fileExists(atPath: url.path) {
            contents = try String(contentsOf: url, encoding: .utf8)
        } else {
            contents = ""
        }

        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let updatedLines: [String]
        if lines.contains(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("cli_auth_credentials_store") }) {
            updatedLines = lines.map { line in
                line.trimmingCharacters(in: .whitespaces).hasPrefix("cli_auth_credentials_store") ? requiredLine : line
            }
        } else if contents.isEmpty {
            updatedLines = [requiredLine]
        } else {
            updatedLines = lines + [requiredLine]
        }

        let normalized = updatedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        try normalized.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func executeProcess(command: CodexLoginCommand, timeout: TimeInterval) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command.arguments
        process.environment = command.environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw CodexLoginRunnerError.launchFailed(error.localizedDescription)
        }

        let timedOut = await self.wait(for: process, timeout: timeout)
        if timedOut {
            if process.isRunning {
                process.terminate()
            }
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            throw CodexLoginRunnerError.timedOut
        }

        let output = self.readCombinedOutput(stdout: stdout, stderr: stderr)
        if process.terminationStatus == 0 {
            return output
        }
        throw CodexLoginRunnerError.failed(status: process.terminationStatus, output: output)
    }

    private static func wait(for process: Process, timeout: TimeInterval) async -> Bool {
        await withTaskGroup(of: Bool.self) { group -> Bool in
            group.addTask {
                process.waitUntilExit()
                return false
            }
            group.addTask {
                let nanos = UInt64(max(0, timeout) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
                return true
            }

            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }
    }

    private static func readCombinedOutput(stdout: Pipe, stderr: Pipe) -> String {
        let stdoutText = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderrText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let combined = [stdoutText, stderrText]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? "No output captured." : combined
    }
}
