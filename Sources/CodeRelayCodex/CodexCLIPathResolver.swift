import Foundation

enum CodexCLIPathResolver {
    typealias CommandV = @Sendable (String, String?, TimeInterval, FileManager) -> String?

    static func effectivePATH(
        env: [String: String],
        loginPATH: [String]?) -> String
    {
        var parts: [String] = []

        if let loginPATH, !loginPATH.isEmpty {
            parts.append(contentsOf: loginPATH)
        }

        if let existing = env["PATH"], !existing.isEmpty {
            parts.append(contentsOf: existing.split(separator: ":").map(String.init))
        }

        if parts.isEmpty {
            parts.append(contentsOf: ["/usr/bin", "/bin", "/usr/sbin", "/sbin"])
        }

        var seen = Set<String>()
        let deduped = parts.compactMap { part -> String? in
            guard !part.isEmpty else { return nil }
            if seen.insert(part).inserted {
                return part
            }
            return nil
        }

        return deduped.joined(separator: ":")
    }

    static func resolveCodexBinary(
        env: [String: String],
        loginPATH: [String]?,
        commandV: CommandV = CodexLoginShellCommandLocator.commandV,
        fileManager: FileManager = .default) -> String?
    {
        if let override = env["CODEX_CLI_PATH"], fileManager.isExecutableFile(atPath: override) {
            return override
        }

        if let loginPATH,
           let pathHit = self.find("codex", in: loginPATH, fileManager: fileManager)
        {
            return pathHit
        }

        if let existingPATH = env["PATH"],
           let pathHit = self.find(
               "codex",
               in: existingPATH.split(separator: ":").map(String.init),
               fileManager: fileManager)
        {
            return pathHit
        }

        if let shellHit = commandV("codex", env["SHELL"], 2.0, fileManager),
           fileManager.isExecutableFile(atPath: shellHit)
        {
            return shellHit
        }

        return nil
    }

    private static func find(_ binary: String, in paths: [String], fileManager: FileManager) -> String? {
        for path in paths where !path.isEmpty {
            let normalizedPath = path.hasSuffix("/") ? String(path.dropLast()) : path
            let candidate = normalizedPath + "/" + binary
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }
}

enum CodexLoginShellCommandLocator {
    @Sendable
    static func commandV(
        _ tool: String,
        _ shell: String?,
        _ timeout: TimeInterval,
        _ fileManager: FileManager) -> String?
    {
        let escapedTool = tool.replacingOccurrences(of: "'", with: "'\\''")
        let text = self.runShellCapture(shell, timeout, "command -v '\(escapedTool)'")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else { return nil }

        let lines = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        for line in lines.reversed() where line.hasPrefix("/") {
            if fileManager.isExecutableFile(atPath: line) {
                return line
            }
        }

        return nil
    }

    private static func runShellCapture(_ shell: String?, _ timeout: TimeInterval, _ command: String) -> String? {
        let shellPath = (shell?.isEmpty == false) ? shell! : "/bin/zsh"
        let isCI = ["1", "true"].contains(ProcessInfo.processInfo.environment["CI"]?.lowercased())
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellPath)
        process.arguments = isCI ? ["-c", command] : ["-l", "-i", "-c", command]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            return nil
        }

        guard let stdout = process.standardOutput as? Pipe else {
            return nil
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}

enum CodexLoginShellPathCapturer {
    static func capture(
        shell: String? = ProcessInfo.processInfo.environment["SHELL"],
        timeout: TimeInterval = 2.0) -> [String]?
    {
        let shellPath = (shell?.isEmpty == false) ? shell! : "/bin/zsh"
        let isCI = ["1", "true"].contains(ProcessInfo.processInfo.environment["CI"]?.lowercased())
        let marker = "__CODERELAY_PATH__"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellPath)
        process.arguments = isCI
            ? ["-c", "printf '\(marker)%s\(marker)' \"$PATH\""]
            : ["-l", "-i", "-c", "printf '\(marker)%s\(marker)' \"$PATH\""]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            return nil
        }

        guard let stdout = process.standardOutput as? Pipe else {
            return nil
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8), !raw.isEmpty else {
            return nil
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let extracted: String
        if let start = trimmed.range(of: marker),
           let end = trimmed.range(of: marker, options: .backwards),
           start.upperBound <= end.lowerBound
        {
            extracted = String(trimmed[start.upperBound..<end.lowerBound])
        } else {
            extracted = trimmed
        }

        let value = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return value.split(separator: ":").map(String.init)
    }
}
