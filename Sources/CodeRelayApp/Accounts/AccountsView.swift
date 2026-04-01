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
                    Text("Phase 1 keeps the surface scoped to add, re-authenticate, select active, and remove.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

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
}
