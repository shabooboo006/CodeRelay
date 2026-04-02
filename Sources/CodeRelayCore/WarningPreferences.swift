import Foundation

public enum WarningRefreshCadence: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case manual
    case oneMinute
    case fiveMinutes
    case fifteenMinutes
    case thirtyMinutes

    public static let defaultValue: Self = .fiveMinutes

    public var id: String {
        self.rawValue
    }

    public var seconds: TimeInterval? {
        switch self {
        case .manual:
            nil
        case .oneMinute:
            60
        case .fiveMinutes:
            300
        case .fifteenMinutes:
            900
        case .thirtyMinutes:
            1_800
        }
    }
}

public struct WarningPreferences: Codable, Equatable, Sendable {
    public static let defaultThresholdPercent: Double = 5
    public static let defaultNotificationsEnabled = true
    public static let defaultValue = WarningPreferences(
        thresholdPercent: Self.defaultThresholdPercent,
        refreshCadence: .defaultValue,
        notificationsEnabled: Self.defaultNotificationsEnabled)

    public var thresholdPercent: Double
    public var refreshCadence: WarningRefreshCadence
    public var notificationsEnabled: Bool

    public init(
        thresholdPercent: Double,
        refreshCadence: WarningRefreshCadence,
        notificationsEnabled: Bool)
    {
        self.thresholdPercent = thresholdPercent
        self.refreshCadence = refreshCadence
        self.notificationsEnabled = notificationsEnabled
    }

    public var normalizedThresholdPercent: Double {
        min(100, max(1, self.thresholdPercent.rounded()))
    }
}
