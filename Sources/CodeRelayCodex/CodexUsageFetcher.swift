import CodeRelayCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum CodexUsageFetcherError: Error, Equatable, LocalizedError, Sendable {
    case missingAuthFile
    case invalidAuthFile
    case missingAccessToken
    case unauthorized
    case invalidResponse
    case serverError(Int, String?)
    case transportError(String)

    public var errorDescription: String? {
        switch self {
        case .missingAuthFile:
            return "Managed account auth.json is missing."
        case .invalidAuthFile:
            return "Managed account auth.json is invalid."
        case .missingAccessToken:
            return "Managed account auth.json does not contain an access token."
        case .unauthorized:
            return "Managed account token is unauthorized for the Codex usage API."
        case .invalidResponse:
            return "Managed account usage response was invalid."
        case let .serverError(code, message):
            if let message, !message.isEmpty {
                return "Managed account usage request failed with status \(code): \(message)"
            }
            return "Managed account usage request failed with status \(code)."
        case let .transportError(message):
            return "Managed account usage request failed: \(message)"
        }
    }
}

public protocol CodexUsageFetcher: Sendable {
    func fetchUsage(in scope: CodexHomeScope) async throws -> ManagedAccountUsageSnapshot
}

public struct DefaultCodexUsageFetcher: CodexUsageFetcher, @unchecked Sendable {
    public typealias DataLoader = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private static let defaultChatGPTBaseURL = "https://chatgpt.com/backend-api"

    private let fileManager: FileManager
    private let dataLoader: DataLoader
    private let now: @Sendable () -> Date

    public init(fileManager: FileManager = .default) {
        self.init(
            fileManager: fileManager,
            dataLoader: { request in
                try await URLSession.shared.data(for: request)
            },
            now: { .now })
    }

    public init(
        fileManager: FileManager = .default,
        dataLoader: @escaping DataLoader,
        now: @escaping @Sendable () -> Date = { .now })
    {
        self.fileManager = fileManager
        self.dataLoader = dataLoader
        self.now = now
    }

    public func fetchUsage(in scope: CodexHomeScope) async throws -> ManagedAccountUsageSnapshot {
        let auth = try self.loadAuth(in: scope)

        var request = URLRequest(url: self.resolveUsageURL(in: scope))
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountID = auth.accountID {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await self.dataLoader(request)
        } catch let error as CodexUsageFetcherError {
            throw error
        } catch {
            throw CodexUsageFetcherError.transportError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CodexUsageFetcherError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            let usageResponse: UsageResponse
            do {
                usageResponse = try JSONDecoder().decode(UsageResponse.self, from: data)
            } catch {
                throw CodexUsageFetcherError.invalidResponse
            }

            return ManagedAccountUsageSnapshot(
                accountID: scope.accountID,
                fiveHourWindow: usageResponse.rateLimit?.primaryWindow.map(Self.makeRateWindow(from:)),
                weeklyWindow: usageResponse.rateLimit?.secondaryWindow.map(Self.makeRateWindow(from:)),
                updatedAt: self.now(),
                source: .managedHomeOAuth,
                status: .fresh,
                lastErrorDescription: nil)

        case 401, 403:
            throw CodexUsageFetcherError.unauthorized

        default:
            let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw CodexUsageFetcherError.serverError(
                httpResponse.statusCode,
                body?.isEmpty == false ? body : nil)
        }
    }

    private func loadAuth(in scope: CodexHomeScope) throws -> AuthContext {
        guard self.fileManager.fileExists(atPath: scope.authFileURL.path) else {
            throw CodexUsageFetcherError.missingAuthFile
        }

        let data: Data
        do {
            data = try Data(contentsOf: scope.authFileURL)
        } catch {
            throw CodexUsageFetcherError.invalidAuthFile
        }

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = root["tokens"] as? [String: Any]
        else {
            throw CodexUsageFetcherError.invalidAuthFile
        }

        guard let accessToken = Self.stringValue(in: tokens, keys: ["accessToken", "access_token"]) else {
            throw CodexUsageFetcherError.missingAccessToken
        }

        let accountID = Self.stringValue(
            in: tokens,
            keys: ["account_id", "accountId", "workspace_id", "workspaceId"])
        return AuthContext(accessToken: accessToken, accountID: accountID)
    }

    private func resolveUsageURL(in scope: CodexHomeScope) -> URL {
        let configContents: String?
        if self.fileManager.fileExists(atPath: scope.configFileURL.path) {
            configContents = try? String(contentsOf: scope.configFileURL, encoding: .utf8)
        } else {
            configContents = nil
        }

        let baseURL = configContents.flatMap(Self.parseChatGPTBaseURL(from:)) ?? Self.defaultChatGPTBaseURL
        let normalizedBaseURL = Self.normalizeChatGPTBaseURL(baseURL)
        let path = normalizedBaseURL.contains("/backend-api") ? "/wham/usage" : "/api/codex/usage"
        return URL(string: normalizedBaseURL + path) ?? URL(string: Self.defaultChatGPTBaseURL + "/wham/usage")!
    }

    private static func makeRateWindow(from snapshot: UsageResponse.WindowSnapshot) -> RateWindow {
        RateWindow(
            usedPercent: snapshot.usedPercent,
            windowMinutes: Int(snapshot.limitWindowSeconds / 60),
            resetsAt: Date(timeIntervalSince1970: snapshot.resetAt),
            resetDescription: nil)
    }

    private static func normalizeChatGPTBaseURL(_ value: String) -> String {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            trimmed = Self.defaultChatGPTBaseURL
        }

        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }

        if (trimmed.hasPrefix("https://chatgpt.com") || trimmed.hasPrefix("https://chat.openai.com"))
            && !trimmed.contains("/backend-api")
        {
            trimmed += "/backend-api"
        }

        return trimmed
    }

    private static func parseChatGPTBaseURL(from contents: String) -> String? {
        for rawLine in contents.split(whereSeparator: \.isNewline) {
            let line = rawLine.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: true).first
            let trimmed = line?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard key == "chatgpt_base_url" else { continue }

            var value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            } else if value.hasPrefix("'"), value.hasSuffix("'") {
                value = String(value.dropFirst().dropLast())
            }
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private static func stringValue(in dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }

        return nil
    }
}

private extension DefaultCodexUsageFetcher {
    struct AuthContext: Sendable {
        let accessToken: String
        let accountID: String?
    }

    struct UsageResponse: Decodable, Sendable {
        let rateLimit: RateLimit?

        enum CodingKeys: String, CodingKey {
            case rateLimit = "rate_limit"
        }

        struct RateLimit: Decodable, Sendable {
            let primaryWindow: WindowSnapshot?
            let secondaryWindow: WindowSnapshot?

            enum CodingKeys: String, CodingKey {
                case primaryWindow = "primary_window"
                case secondaryWindow = "secondary_window"
            }
        }

        struct WindowSnapshot: Decodable, Sendable {
            let usedPercent: Double
            let resetAt: TimeInterval
            let limitWindowSeconds: Double

            enum CodingKeys: String, CodingKey {
                case usedPercent = "used_percent"
                case resetAt = "reset_at"
                case limitWindowSeconds = "limit_window_seconds"
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.usedPercent = try container.decodeFlexibleDouble(forKey: .usedPercent)
                self.resetAt = try container.decodeFlexibleDouble(forKey: .resetAt)
                self.limitWindowSeconds = try container.decodeFlexibleDouble(forKey: .limitWindowSeconds)
            }
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleDouble(forKey key: Key) throws -> Double {
        if let value = try? self.decode(Double.self, forKey: key) {
            return value
        }
        return Double(try self.decode(Int.self, forKey: key))
    }
}
