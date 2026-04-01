import CodeRelayCore
import Foundation

public protocol CodexIdentityReader: Sendable {
    func readIdentity(in scope: CodexHomeScope) throws -> ManagedAccountIdentity?
}

public struct DefaultCodexIdentityReader: CodexIdentityReader, @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func readIdentity(in scope: CodexHomeScope) throws -> ManagedAccountIdentity? {
        guard self.fileManager.fileExists(atPath: scope.authFileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: scope.authFileURL)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let apiKey = root["OPENAI_API_KEY"] as? String,
           !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return nil
        }

        guard let tokens = root["tokens"] as? [String: Any],
              let idToken = Self.stringValue(in: tokens, keys: ["id_token", "idToken"]),
              let payload = Self.parseJWT(idToken)
        else {
            return nil
        }

        let auth = payload["https://api.openai.com/auth"] as? [String: Any]
        let profile = payload["https://api.openai.com/profile"] as? [String: Any]
        let email = Self.stringValue(in: payload, keys: ["email"])
            ?? Self.stringValue(in: profile, keys: ["email"])
        let workspaceID = Self.stringValue(in: auth, keys: ["workspace_id", "workspaceId"])
            ?? Self.stringValue(in: tokens, keys: ["account_id", "accountId"])

        guard let email, !email.isEmpty else {
            return nil
        }

        return ManagedAccountIdentity(email: email, workspaceID: workspaceID)
    }

    private static func parseJWT(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var padded = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while padded.count % 4 != 0 {
            padded.append("=")
        }

        guard let data = Data(base64Encoded: padded),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        return payload
    }

    private static func stringValue(in dictionary: [String: Any]?, keys: [String]) -> String? {
        guard let dictionary else { return nil }
        for key in keys {
            if let value = dictionary[key] as? String,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                return value
            }
        }
        return nil
    }
}
