import CodeRelayCore
import SwiftUI

public enum AccountsViewMode: Sendable {
    case setup
    case management
}

public struct AccountsView: View {
    @ObservedObject private var feature: AccountsFeature
    private let mode: AccountsViewMode

    public init(feature: AccountsFeature, mode: AccountsViewMode = .management) {
        self.feature = feature
        self.mode = mode
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(self.localized(self.mode == .setup ? "setup.title" : "accounts.title"))
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(self.localized(self.mode == .setup ? "setup.subtitle" : "manage.subtitle"))
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

                    if self.mode == .management {
                        Button(self.localized("accounts.action.refreshUsage")) {
                            Task {
                                await self.feature.run(.refreshMonitoring)
                            }
                        }
                        .disabled(self.feature.state.isBusy || self.feature.state.rows.isEmpty)
                    }

                    if self.mode == .setup {
                        Button(self.localized("accounts.action.addAccount")) {
                            Task {
                                await self.feature.run(.addAccount)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(self.feature.state.isBusy)
                    } else {
                        Button(self.localized("accounts.action.addAccount")) {
                            Task {
                                await self.feature.run(.addAccount)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(self.feature.state.isBusy)
                    }
                }
            }

            if let message = self.feature.state.message, !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if self.feature.state.rows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(self.localized(self.mode == .setup ? "setup.empty.title" : "accounts.empty.title"))
                        .font(.headline)
                    Text(self.localized(self.mode == .setup ? "setup.empty.subtitle" : "accounts.empty.subtitle"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: self.mode == .setup ? .center : .topLeading)
                .padding(.top, self.mode == .setup ? 0 : 24)
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

                                Text(AccountsCopy.lastAuthenticated(row.lastAuthenticatedAt, language: self.language))
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

    @ViewBuilder
    private func monitoringDetails(for row: AccountProjectionRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if row.isActive {
                Text(CodeRelayLocalizer.format(
                    "accounts.monitoring.fiveHourUsage",
                    language: self.language,
                    AccountsCopy.usage(window: row.fiveHourWindow, language: self.language)))
                Text(CodeRelayLocalizer.format(
                    "accounts.monitoring.weeklyUsage",
                    language: self.language,
                    AccountsCopy.usage(window: row.weeklyWindow, language: self.language)))
            }

            Text(CodeRelayLocalizer.format(
                "accounts.monitoring.lastRefreshed",
                language: self.language,
                AccountsCopy.lastRefreshed(row.lastUsageRefreshAt, language: self.language)))
            Text(CodeRelayLocalizer.format(
                "accounts.monitoring.source",
                language: self.language,
                AccountsCopy.source(row.usageSource, language: self.language)))
            Text(CodeRelayLocalizer.format(
                "accounts.monitoring.status",
                language: self.language,
                AccountsCopy.status(row, language: self.language)))

            if !row.isActive {
                Text(CodeRelayLocalizer.format(
                    "accounts.monitoring.readiness",
                    language: self.language,
                    AccountsCopy.readiness(row, language: self.language)))
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
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
