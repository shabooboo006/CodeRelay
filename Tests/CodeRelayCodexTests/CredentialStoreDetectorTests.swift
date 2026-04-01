import CodeRelayCodex
import CodeRelayCore
import Foundation
import Testing

@Suite(.serialized) struct CredentialStoreDetectorTests {
    @Test
    func Phase1_credentialStoreDetector_marksFileBackedAuthSupported() throws {
        let home = Self.makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try Self.writeConfig(mode: "file", home: home)
        try Self.writeAuth(home: home, email: "file@example.com")

        let scope = CodexHomeScope(accountID: UUID(), homeURL: home)
        let detector = DefaultCredentialStoreDetector()

        #expect(try detector.credentialStoreMode(in: scope) == .file)
        #expect(try detector.detectSupport(in: scope).kind == .supported)
    }

    @Test
    func Phase1_credentialStoreDetector_marksKeyringUnsupported() throws {
        let home = Self.makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try Self.writeConfig(mode: "keyring", home: home)

        let scope = CodexHomeScope(accountID: UUID(), homeURL: home)
        let support = try DefaultCredentialStoreDetector().detectSupport(in: scope)

        #expect(support.kind == .unsupported)
    }

    @Test
    func Phase1_credentialStoreDetector_marksUnknownModeUnverified() throws {
        let home = Self.makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try Self.writeAuth(home: home, email: "unknown@example.com")

        let scope = CodexHomeScope(accountID: UUID(), homeURL: home)
        let detector = DefaultCredentialStoreDetector()

        #expect(try detector.credentialStoreMode(in: scope) == .unknown)
        #expect(try detector.detectSupport(in: scope).kind == .unverified)
    }

    private static func makeHome() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private static func writeConfig(mode: String, home: URL) throws {
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let config = #"cli_auth_credentials_store = "\#(mode)""# + "\n"
        try config.write(to: home.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
    }

    private static func writeAuth(home: URL, email: String) throws {
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let auth = [
            "tokens": [
                "accessToken": "access-token",
                "refreshToken": "refresh-token",
                "idToken": Self.fakeJWT(email: email),
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: auth)
        try data.write(to: home.appendingPathComponent("auth.json"))
    }

    private static func fakeJWT(email: String) -> String {
        let header = (try? JSONSerialization.data(withJSONObject: ["alg": "none"])) ?? Data()
        let payload = (try? JSONSerialization.data(withJSONObject: [
            "email": email,
            "https://api.openai.com/auth": [
                "workspace_id": "workspace-1",
            ],
        ])) ?? Data()

        func encode(_ data: Data) -> String {
            data.base64EncodedString()
                .replacingOccurrences(of: "=", with: "")
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
        }

        return "\(encode(header)).\(encode(payload))."
    }
}
