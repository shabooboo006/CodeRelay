import CodeRelayCodex
import CodeRelayCore
import Foundation
import Testing

@Suite(.serialized) struct CodexUsageFetcherTests {
    @Test
    func Phase2_codexUsageFetcher_buildsManagedHomeRequest() async throws {
        let home = Self.makeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let accountID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let updatedAt = Date(timeIntervalSince1970: 5_000)
        try Self.writeAuth(
            home: home,
            tokenKey: "accessToken",
            accessToken: "managed-access-token",
            accountKey: "workspaceId",
            accountID: "workspace-123")
        try Self.writeConfig(
            home: home,
            contents: #"chatgpt_base_url = "https://chat.openai.com""# + "\n")

        let recorder = RequestRecorder()
        let fetcher = DefaultCodexUsageFetcher(
            dataLoader: { request in
                await recorder.record(request)
                return (
                    Data(Self.successResponseJSON().utf8),
                    HTTPURLResponse(
                        url: try #require(request.url),
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil)!
                )
            },
            now: { updatedAt })

        _ = try await fetcher.fetchUsage(in: CodexHomeScope(accountID: accountID, homeURL: home))
        let request = try #require(await recorder.request)

        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "https://chat.openai.com/backend-api/wham/usage")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer managed-access-token")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "ChatGPT-Account-Id") == "workspace-123")
    }

    @Test
    func Phase2_codexUsageFetcher_readsSnakeCaseAuthTokens() async throws {
        let home = Self.makeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let accountID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        try Self.writeAuth(
            home: home,
            tokenKey: "access_token",
            accessToken: "snake-case-token",
            accountKey: "account_id",
            accountID: "workspace-snake")

        let recorder = RequestRecorder()
        let fetcher = DefaultCodexUsageFetcher(
            dataLoader: { request in
                await recorder.record(request)
                return (
                    Data(Self.successResponseJSON().utf8),
                    HTTPURLResponse(
                        url: try #require(request.url),
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil)!
                )
            })

        _ = try await fetcher.fetchUsage(in: CodexHomeScope(accountID: accountID, homeURL: home))
        let request = try #require(await recorder.request)

        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer snake-case-token")
        #expect(request.value(forHTTPHeaderField: "ChatGPT-Account-Id") == "workspace-snake")
    }

    @Test
    func Phase2_codexUsageFetcher_normalizesFiveHourAndWeeklyWindows() async throws {
        let home = Self.makeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let accountID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let updatedAt = Date(timeIntervalSince1970: 7_000)
        try Self.writeAuth(
            home: home,
            tokenKey: "accessToken",
            accessToken: "access-token",
            accountKey: nil,
            accountID: nil)

        let fetcher = DefaultCodexUsageFetcher(
            dataLoader: { request in
                (
                    Data(Self.successResponseJSON().utf8),
                    HTTPURLResponse(
                        url: try #require(request.url),
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil)!
                )
            },
            now: { updatedAt })

        let snapshot = try await fetcher.fetchUsage(in: CodexHomeScope(accountID: accountID, homeURL: home))

        #expect(snapshot.accountID == accountID)
        #expect(snapshot.source == .managedHomeOAuth)
        #expect(snapshot.status == .fresh)
        #expect(snapshot.updatedAt == updatedAt)
        #expect(snapshot.lastErrorDescription == nil)
        #expect(snapshot.fiveHourWindow?.usedPercent == 61)
        #expect(snapshot.fiveHourWindow?.windowMinutes == 300)
        #expect(snapshot.fiveHourWindow?.resetsAt == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(snapshot.weeklyWindow?.usedPercent == 42)
        #expect(snapshot.weeklyWindow?.windowMinutes == 10_080)
        #expect(snapshot.weeklyWindow?.resetsAt == Date(timeIntervalSince1970: 1_700_100_000))
    }

    @Test
    func Phase2_codexUsageFetcher_throwsMissingAccessToken() async {
        let home = Self.makeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try? Self.writeAuth(home: home, tokenKey: nil, accessToken: nil, accountKey: nil, accountID: nil)
        let fetcher = DefaultCodexUsageFetcher()

        await #expect(throws: CodexUsageFetcherError.missingAccessToken) {
            try await fetcher.fetchUsage(in: CodexHomeScope(accountID: UUID(), homeURL: home))
        }
    }

    @Test
    func Phase2_codexUsageFetcher_throwsUnauthorizedForForbiddenResponse() async throws {
        let home = Self.makeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try Self.writeAuth(
            home: home,
            tokenKey: "accessToken",
            accessToken: "access-token",
            accountKey: nil,
            accountID: nil)
        let fetcher = DefaultCodexUsageFetcher(
            dataLoader: { request in
                (
                    Data("denied".utf8),
                    HTTPURLResponse(
                        url: try #require(request.url),
                        statusCode: 403,
                        httpVersion: nil,
                        headerFields: nil)!
                )
            })

        await #expect(throws: CodexUsageFetcherError.unauthorized) {
            try await fetcher.fetchUsage(in: CodexHomeScope(accountID: UUID(), homeURL: home))
        }
    }

    @Test
    func Phase2_codexUsageFetcher_throwsServerErrorForNon2xxResponse() async throws {
        let home = Self.makeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try Self.writeAuth(
            home: home,
            tokenKey: "accessToken",
            accessToken: "access-token",
            accountKey: nil,
            accountID: nil)
        let fetcher = DefaultCodexUsageFetcher(
            dataLoader: { request in
                (
                    Data(#"{"error":"server exploded"}"#.utf8),
                    HTTPURLResponse(
                        url: try #require(request.url),
                        statusCode: 500,
                        httpVersion: nil,
                        headerFields: nil)!
                )
            })

        await #expect(throws: CodexUsageFetcherError.serverError(500, #"{"error":"server exploded"}"#)) {
            try await fetcher.fetchUsage(in: CodexHomeScope(accountID: UUID(), homeURL: home))
        }
    }

    private actor RequestRecorder {
        private(set) var request: URLRequest?

        func record(_ request: URLRequest) {
            self.request = request
        }
    }

    private static func makeHome() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private static func writeAuth(
        home: URL,
        tokenKey: String?,
        accessToken: String?,
        accountKey: String?,
        accountID: String?) throws
    {
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)

        var tokens: [String: Any] = [:]
        if let tokenKey, let accessToken {
            tokens[tokenKey] = accessToken
        }
        if let accountKey, let accountID {
            tokens[accountKey] = accountID
        }

        let auth = ["tokens": tokens]
        let data = try JSONSerialization.data(withJSONObject: auth)
        try data.write(to: home.appendingPathComponent("auth.json"))
    }

    private static func writeConfig(home: URL, contents: String) throws {
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try contents.write(to: home.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
    }

    private static func successResponseJSON() -> String {
        """
        {
          "rate_limit": {
            "primary_window": {
              "used_percent": 61,
              "reset_at": 1700000000,
              "limit_window_seconds": 18000
            },
            "secondary_window": {
              "used_percent": 42,
              "reset_at": 1700100000,
              "limit_window_seconds": 604800
            }
          }
        }
        """
    }
}
