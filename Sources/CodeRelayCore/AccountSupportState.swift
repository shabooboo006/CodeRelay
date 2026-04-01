import Foundation

public struct AccountSupportState: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case supported
        case unsupported
        case unverified
    }

    public var kind: Kind
    public var reason: String?

    public init(kind: Kind, reason: String? = nil) {
        self.kind = kind
        self.reason = reason
    }

    public static var supported: Self {
        Self(kind: .supported)
    }

    public static func unsupported(_ reason: String) -> Self {
        Self(kind: .unsupported, reason: reason)
    }

    public static func unverified(_ reason: String? = nil) -> Self {
        Self(kind: .unverified, reason: reason)
    }

    public var label: String {
        switch self.reason {
        case let reason? where !reason.isEmpty:
            return "\(self.kind.rawValue.capitalized): \(reason)"
        default:
            return self.kind.rawValue.capitalized
        }
    }
}
