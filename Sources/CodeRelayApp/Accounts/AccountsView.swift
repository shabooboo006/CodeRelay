import CodeRelayCore
import SwiftUI

public struct AccountsView: View {
    @ObservedObject private var feature: AccountsFeature

    public init(feature: AccountsFeature) {
        self.feature = feature
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Managed Codex Accounts")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Phase 2 adds monitoring, manual refresh, and readiness details in the existing accounts surface.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Refresh Usage") {
                    Task {
                        await self.feature.run(.refreshMonitoring)
                    }
                }
                .disabled(self.feature.state.isBusy || self.feature.state.rows.isEmpty)

                Button("Add Account") {
                    Task {
                        await self.feature.run(.addAccount)
                    }
                }
                .disabled(self.feature.state.isBusy)
            }

            if let message = self.feature.state.message, !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if self.feature.state.rows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No managed accounts yet.")
                        .font(.headline)
                    Text("Use Add Account to enroll a CodeRelay-scoped Codex login.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 24)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(self.feature.state.rows) { row in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Text(row.email)
                                        .font(.headline)
                                    if row.isActive {
                                        Self.badge("Active")
                                    }
                                    if row.isLive {
                                        Self.badge("Live")
                                    }
                                }

                                Text("Support: \(row.supportState.label)")
                                    .foregroundStyle(.secondary)

                                Text(self.lastAuthenticatedCopy(row.lastAuthenticatedAt))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                self.monitoringDetails(for: row)

                                HStack(spacing: 8) {
                                    Button("Set Active") {
                                        Task {
                                            await self.feature.run(.setActive(row.id))
                                        }
                                    }
                                    .disabled(row.isActive || self.feature.state.isBusy)

                                    Button("Re-authenticate") {
                                        Task {
                                            await self.feature.run(.reauthenticate(row.id))
                                        }
                                    }
                                    .disabled(self.feature.state.isBusy)

                                    Button("Remove", role: .destructive) {
                                        Task {
                                            await self.feature.run(.remove(row.id))
                                        }
                                    }
                                    .disabled(self.feature.state.isBusy)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
        }
        .padding(20)
    }

    private func lastAuthenticatedCopy(_ date: Date?) -> String {
        guard let date else {
            return "Last authenticated: unavailable"
        }
        return "Last authenticated: \(Self.dateFormatter.string(from: date))"
    }

    @ViewBuilder
    private func monitoringDetails(for row: AccountProjectionRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if row.isActive {
                Text("5-hour usage: \(self.usageCopy(window: row.fiveHourWindow))")
                Text("Weekly usage: \(self.usageCopy(window: row.weeklyWindow))")
            }

            Text("Last refreshed: \(self.lastRefreshedCopy(row.lastUsageRefreshAt))")
            Text("Source: \(self.sourceCopy(row.usageSource))")
            Text("Status: \(self.statusCopy(row))")

            if !row.isActive {
                Text("Readiness: \(self.readinessCopy(row))")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func usageCopy(window: RateWindow?) -> String {
        guard let window else {
            return "unavailable"
        }

        let used = Self.percentFormatter.string(from: NSNumber(value: window.usedPercent)) ?? "\(Int(window.usedPercent))%"
        let remaining = Self.percentFormatter.string(from: NSNumber(value: window.remainingPercent)) ?? "\(Int(window.remainingPercent))%"
        let reset = self.resetCopy(window)

        if reset.isEmpty {
            return "\(used) used, \(remaining) remaining"
        }

        return "\(used) used, \(remaining) remaining, reset \(reset)"
    }

    private func resetCopy(_ window: RateWindow) -> String {
        let description = window.resetDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description?.isEmpty == false ? description : nil

        if let trimmedDescription,
           let date = window.resetsAt
        {
            return "\(trimmedDescription) (\(Self.dateFormatter.string(from: date)))"
        }

        if let trimmedDescription {
            return trimmedDescription
        }

        if let date = window.resetsAt {
            return Self.dateFormatter.string(from: date)
        }

        return ""
    }

    private func lastRefreshedCopy(_ date: Date?) -> String {
        guard let date else {
            return "unavailable"
        }
        return Self.dateFormatter.string(from: date)
    }

    private func sourceCopy(_ source: UsageProbeSource) -> String {
        if source == .managedHomeOAuth {
            return "managed-home oauth"
        }

        if source == .cache {
            return "cache"
        }

        return "unknown"
    }

    private func statusCopy(_ row: AccountProjectionRow) -> String {
        let status = row.usageStatus.rawValue
        guard let error = row.usageErrorDescription,
              !error.isEmpty,
              row.usageStatus != .fresh
        else {
            return status
        }
        return "\(status) (\(error))"
    }

    private func readinessCopy(_ row: AccountProjectionRow) -> String {
        guard let readiness = row.alternateReadiness else {
            return "unavailable"
        }

        if readiness.status == .fresh {
            let fiveHour = readiness.fiveHourRemainingPercent.map(Self.formattedPercent)
            let weekly = readiness.weeklyRemainingPercent.map(Self.formattedPercent)

            if let fiveHour,
               let weekly
            {
                return "\(fiveHour) 5-hour remaining, \(weekly) weekly remaining"
            }

            if let fiveHour {
                return "\(fiveHour) 5-hour remaining"
            }

            if let weekly {
                return "\(weekly) weekly remaining"
            }

            return "unknown"
        }

        if readiness.status == .stale {
            return "stale"
        }

        if readiness.status == .error {
            return "error"
        }

        return "unknown"
    }

    private static func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        formatter.multiplier = 1
        return formatter
    }()

    private static func formattedPercent(_ value: Double) -> String {
        Self.percentFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))%"
    }
}
