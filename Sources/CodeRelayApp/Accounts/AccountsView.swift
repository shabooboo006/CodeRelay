import CodeRelayCore
import SwiftUI

public struct AccountsView: View {
    @ObservedObject private var feature: AccountsFeature

    public init(feature: AccountsFeature) {
        self.feature = feature
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(self.localized("accounts.title"))
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(self.localized("accounts.subtitle"))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    Picker(self.localized("app.language.label"), selection: self.languageSelection) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(CodeRelayLocalizer.languageOptionLabel(option, language: self.language))
                                .tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 170)

                    Button(self.localized("accounts.action.refreshUsage")) {
                        Task {
                            await self.feature.run(.refreshMonitoring)
                        }
                    }
                    .disabled(self.feature.state.isBusy || self.feature.state.rows.isEmpty)

                    Button(self.localized("accounts.action.addAccount")) {
                        Task {
                            await self.feature.run(.addAccount)
                        }
                    }
                    .disabled(self.feature.state.isBusy)
                }
            }

            if let message = self.feature.state.message, !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if self.feature.state.rows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(self.localized("accounts.empty.title"))
                        .font(.headline)
                    Text(self.localized("accounts.empty.subtitle"))
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
                                        Self.badge(self.localized("accounts.badge.active"))
                                    }
                                    if row.isLive {
                                        Self.badge(self.localized("accounts.badge.live"))
                                    }
                                }

                                Text(CodeRelayLocalizer.supportLabel(row.supportState, language: self.language))
                                    .foregroundStyle(.secondary)

                                Text(self.lastAuthenticatedCopy(row.lastAuthenticatedAt))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                self.monitoringDetails(for: row)

                                HStack(spacing: 8) {
                                    Button(self.localized("accounts.action.setActive")) {
                                        Task {
                                            await self.feature.run(.setActive(row.id))
                                        }
                                    }
                                    .disabled(row.isActive || self.feature.state.isBusy)

                                    Button(self.localized("accounts.action.reauthenticate")) {
                                        Task {
                                            await self.feature.run(.reauthenticate(row.id))
                                        }
                                    }
                                    .disabled(self.feature.state.isBusy)

                                    Button(self.localized("accounts.action.remove"), role: .destructive) {
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

    private var language: AppLanguage {
        self.feature.state.selectedLanguage
    }

    private var languageSelection: Binding<AppLanguage> {
        Binding(
            get: { self.feature.state.selectedLanguage },
            set: { newValue in
                Task {
                    await self.feature.run(.setLanguage(newValue))
                }
            })
    }

    private func localized(_ key: String) -> String {
        CodeRelayLocalizer.text(key, language: self.language)
    }

    private func lastAuthenticatedCopy(_ date: Date?) -> String {
        guard let date else {
            return self.localized("accounts.lastAuthenticated.unavailable")
        }
        return CodeRelayLocalizer.format(
            "accounts.lastAuthenticated.value",
            language: self.language,
            CodeRelayLocalizer.formattedDate(date, language: self.language))
    }

    @ViewBuilder
    private func monitoringDetails(for row: AccountProjectionRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if row.isActive {
                Text(CodeRelayLocalizer.format(
                    "accounts.monitoring.fiveHourUsage",
                    language: self.language,
                    self.usageCopy(window: row.fiveHourWindow)))
                Text(CodeRelayLocalizer.format(
                    "accounts.monitoring.weeklyUsage",
                    language: self.language,
                    self.usageCopy(window: row.weeklyWindow)))
            }

            Text(CodeRelayLocalizer.format(
                "accounts.monitoring.lastRefreshed",
                language: self.language,
                self.lastRefreshedCopy(row.lastUsageRefreshAt)))
            Text(CodeRelayLocalizer.format(
                "accounts.monitoring.source",
                language: self.language,
                self.sourceCopy(row.usageSource)))
            Text(CodeRelayLocalizer.format(
                "accounts.monitoring.status",
                language: self.language,
                self.statusCopy(row)))

            if !row.isActive {
                Text(CodeRelayLocalizer.format(
                    "accounts.monitoring.readiness",
                    language: self.language,
                    self.readinessCopy(row)))
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func usageCopy(window: RateWindow?) -> String {
        guard let window else {
            return self.localized("accounts.usage.unavailable")
        }

        let used = CodeRelayLocalizer.formattedPercent(window.usedPercent, language: self.language)
        let remaining = CodeRelayLocalizer.formattedPercent(window.remainingPercent, language: self.language)
        let reset = self.resetCopy(window)

        if reset.isEmpty {
            return CodeRelayLocalizer.format(
                "accounts.usage.summary.noReset",
                language: self.language,
                used,
                remaining)
        }

        return CodeRelayLocalizer.format(
            "accounts.usage.summary.withReset",
            language: self.language,
            used,
            remaining,
            reset)
    }

    private func resetCopy(_ window: RateWindow) -> String {
        let description = window.resetDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description?.isEmpty == false ? description : nil

        if let trimmedDescription,
           let date = window.resetsAt
        {
            return "\(trimmedDescription) (\(CodeRelayLocalizer.formattedDate(date, language: self.language)))"
        }

        if let trimmedDescription {
            return trimmedDescription
        }

        if let date = window.resetsAt {
            return CodeRelayLocalizer.formattedDate(date, language: self.language)
        }

        return ""
    }

    private func lastRefreshedCopy(_ date: Date?) -> String {
        guard let date else {
            return self.localized("accounts.usage.unavailable")
        }
        return CodeRelayLocalizer.formattedDate(date, language: self.language)
    }

    private func sourceCopy(_ source: UsageProbeSource) -> String {
        CodeRelayLocalizer.usageSourceLabel(source, language: self.language)
    }

    private func statusCopy(_ row: AccountProjectionRow) -> String {
        let status = CodeRelayLocalizer.usageStatusLabel(row.usageStatus, language: self.language)
        guard let error = row.usageErrorDescription,
              !error.isEmpty,
              row.usageStatus != .fresh
        else {
            return status
        }
        return CodeRelayLocalizer.format("accounts.status.withReason", language: self.language, status, error)
    }

    private func readinessCopy(_ row: AccountProjectionRow) -> String {
        guard let readiness = row.alternateReadiness else {
            return self.localized("accounts.readiness.unavailable")
        }

        if readiness.status == .fresh {
            let fiveHour = readiness.fiveHourRemainingPercent.map { value in
                CodeRelayLocalizer.formattedPercent(value, language: self.language)
            }
            let weekly = readiness.weeklyRemainingPercent.map { value in
                CodeRelayLocalizer.formattedPercent(value, language: self.language)
            }

            if let fiveHour,
               let weekly
            {
                return CodeRelayLocalizer.format("accounts.readiness.both", language: self.language, fiveHour, weekly)
            }

            if let fiveHour {
                return CodeRelayLocalizer.format("accounts.readiness.fiveHour", language: self.language, fiveHour)
            }

            if let weekly {
                return CodeRelayLocalizer.format("accounts.readiness.weekly", language: self.language, weekly)
            }

            return self.localized("accounts.readiness.unknown")
        }

        switch readiness.status {
        case .stale:
            return self.localized("accounts.readiness.stale")
        case .error:
            return self.localized("accounts.readiness.error")
        case .unknown:
            return self.localized("accounts.readiness.unknown")
        case .fresh:
            return self.localized("accounts.readiness.unknown")
        }
    }

    private static func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(Capsule())
    }
}
