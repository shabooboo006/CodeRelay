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
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            switch self.mode {
            case .setup:
                self.setupLayout
            case .management:
                self.managementLayout
            }
        }
    }

    private var setupLayout: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                self.languagePicker
                    .frame(width: 170)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 20) {
                self.headerCopy(
                    titleKey: "setup.title",
                    subtitleKey: "setup.subtitle",
                    titleFont: .system(size: 30, weight: .semibold))

                if let message = self.feature.state.message, !message.isEmpty {
                    self.messageBanner(message)
                }

                self.surface {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(self.localized("setup.empty.title"))
                            .font(.headline)

                        Text(self.localized("setup.empty.subtitle"))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack {
                            Spacer()
                            self.addAccountButton(prominent: true)
                        }
                    }
                }
            }
            .frame(maxWidth: 560, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var managementLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                self.managementHeader

                if let message = self.feature.state.message, !message.isEmpty {
                    self.messageBanner(message)
                }

                if self.feature.state.rows.isEmpty {
                    self.managementEmptyState
                } else {
                    if let featuredRow = self.featuredRow {
                        self.sectionBlock("manage.section.current") {
                            self.currentAccountSection(for: featuredRow)
                        }
                    }

                    self.sectionBlock("manage.section.warnings") {
                        self.warningSettingsSection
                    }

                    self.sectionBlock("manage.section.accounts") {
                        self.managedAccountsSection
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private var managementHeader: some View {
        HStack(alignment: .top, spacing: 24) {
            self.headerCopy(
                titleKey: "accounts.title",
                subtitleKey: "manage.subtitle",
                titleFont: .system(size: 30, weight: .semibold))

            Spacer(minLength: 24)

            self.managementControls
        }
    }

    private var managementControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                self.languagePicker
                    .frame(width: 170)
                self.refreshUsageButton
                self.addAccountButton(prominent: false)
            }

            VStack(alignment: .trailing, spacing: 10) {
                self.languagePicker
                    .frame(width: 170)
                HStack(spacing: 10) {
                    self.refreshUsageButton
                    self.addAccountButton(prominent: false)
                }
            }
        }
    }

    private var managementEmptyState: some View {
        self.surface {
            VStack(alignment: .leading, spacing: 16) {
                Text(self.localized("accounts.empty.title"))
                    .font(.headline)

                Text(self.localized("accounts.empty.subtitle"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    self.addAccountButton(prominent: true)
                }
            }
        }
    }

    private func currentAccountSection(for row: AccountProjectionRow) -> some View {
        self.surface {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(row.email)
                            .font(.headline)

                        HStack(spacing: 8) {
                            if row.isActive {
                                Self.badge(self.localized("accounts.badge.active"), tint: .accentColor)
                            }

                            if row.isLive {
                                Self.badge(self.localized("accounts.badge.live"), tint: .secondary, muted: true)
                            }
                        }
                    }

                    Spacer(minLength: 16)

                    HStack(spacing: 8) {
                        if !row.isActive {
                            Button(self.localized("accounts.action.setActive")) {
                                Task {
                                    await self.feature.run(.setActive(row.id))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(self.feature.state.isBusy)
                        }

                        Button(self.localized("accounts.action.reauthenticate")) {
                            Task {
                                await self.feature.run(.reauthenticate(row.id))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(self.feature.state.isBusy)

                        Button(self.localized("accounts.action.remove"), role: .destructive) {
                            Task {
                                await self.feature.run(.remove(row.id))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(self.feature.state.isBusy)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(CodeRelayLocalizer.supportLabel(row.supportState, language: self.language))
                        .foregroundStyle(.secondary)
                    Text(AccountsCopy.lastAuthenticated(row.lastAuthenticatedAt, language: self.language))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 14) {
                    self.usageRow(
                        title: self.localized("accounts.metric.fiveHour"),
                        window: row.fiveHourWindow)
                    self.usageRow(
                        title: self.localized("accounts.metric.weekly"),
                        window: row.weeklyWindow)
                }

                VStack(alignment: .leading, spacing: 6) {
                    self.secondaryLine(CodeRelayLocalizer.format(
                        "accounts.monitoring.status",
                        language: self.language,
                        AccountsCopy.status(row, language: self.language)))
                    self.secondaryLine(CodeRelayLocalizer.format(
                        "accounts.monitoring.lastRefreshed",
                        language: self.language,
                        AccountsCopy.lastRefreshed(row.lastUsageRefreshAt, language: self.language)))
                    self.secondaryLine(CodeRelayLocalizer.format(
                        "accounts.monitoring.source",
                        language: self.language,
                        AccountsCopy.source(row.usageSource, language: self.language)))
                }
            }
        }
    }

    private var managedAccountsSection: some View {
        self.surface(padding: 0) {
            let rows = self.secondaryRows

            VStack(alignment: .leading, spacing: 0) {
                if rows.isEmpty {
                    Text(self.localized("accounts.other.empty"))
                        .foregroundStyle(.secondary)
                        .padding(20)
                } else {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        self.accountListRow(row)
                            .padding(20)

                        if index < rows.count - 1 {
                            Divider()
                                .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
    }

    private func accountListRow(_ row: AccountProjectionRow) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.email)
                        .font(.headline)

                    Text(CodeRelayLocalizer.supportLabel(row.supportState, language: self.language))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)

                HStack(spacing: 8) {
                    Button(self.localized("accounts.action.setActive")) {
                        Task {
                            await self.feature.run(.setActive(row.id))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(self.feature.state.isBusy || row.isActive)

                    Button(self.localized("accounts.action.reauthenticate")) {
                        Task {
                            await self.feature.run(.reauthenticate(row.id))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(self.feature.state.isBusy)

                    Button(self.localized("accounts.action.remove"), role: .destructive) {
                        Task {
                            await self.feature.run(.remove(row.id))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(self.feature.state.isBusy)
                }
            }

            Text(AccountsCopy.lastAuthenticated(row.lastAuthenticatedAt, language: self.language))
                .font(.footnote)
                .foregroundStyle(.secondary)

            self.secondaryLine(CodeRelayLocalizer.format(
                "accounts.monitoring.readiness",
                language: self.language,
                AccountsCopy.readiness(row, language: self.language)))
        }
    }

    private func usageRow(title: String, window: RateWindow?) -> some View {
        let remainingPercent = window?.remainingPercent ?? 0
        let progressValue = max(0, min(remainingPercent / 100, 1))

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.body.weight(.medium))

                Spacer()

                Text(window.map {
                    CodeRelayLocalizer.formattedPercent($0.remainingPercent, language: self.language)
                } ?? self.localized("accounts.usage.unavailable"))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progressValue)
                .tint(self.usageTint(remainingPercent: remainingPercent))
                .controlSize(.small)

            Text(AccountsCopy.usage(window: window, language: self.language))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var warningSettingsSection: some View {
        self.surface {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(self.localized("warnings.settings.threshold"))
                        Text(self.warningThresholdText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Stepper("", value: self.warningThresholdSelection, in: 5 ... 95, step: 5)
                        .labelsHidden()
                }
                .padding(.bottom, 16)

                Divider()

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(self.localized("warnings.settings.refreshCadence"))
                        Text(self.localized("warnings.settings.refreshHelp"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Picker(self.localized("warnings.settings.refreshCadence"), selection: self.warningRefreshCadenceSelection) {
                        ForEach(WarningRefreshCadence.allCases) { cadence in
                            Text(WarningCopy.refreshCadenceLabel(cadence, language: self.language))
                                .tag(cadence)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 170)
                }
                .padding(.vertical, 16)

                Divider()

                Toggle(self.localized("warnings.settings.notificationsEnabled"), isOn: self.warningNotificationsSelection)
                    .padding(.top, 16)

                Text(self.localized("warnings.settings.notificationsHelp"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                if let activeWarning = self.feature.state.activeWarning {
                    Divider()
                        .padding(.top, 16)

                    self.warningCallout(activeWarning)
                        .padding(.top, 16)
                }
            }
        }
    }

    private func warningCallout(_ warning: ActiveWarning) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(WarningCopy.sectionTitle(for: warning, language: self.language))
                .font(.headline)

            Text(WarningCopy.summary(for: warning, language: self.language))
                .fixedSize(horizontal: false, vertical: true)

            if let suggestionsLine = WarningCopy.suggestionsLine(for: warning, language: self.language) {
                Text(suggestionsLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
    }

    private func sectionBlock<Content: View>(_ key: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(self.localized(key))
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            content()
        }
    }

    private func surface<Content: View>(padding: CGFloat = 20, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.18))
                )
        )
    }

    private func headerCopy(titleKey: String, subtitleKey: String, titleFont: Font) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(self.localized(titleKey))
                .font(titleFont)

            Text(self.localized(subtitleKey))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func messageBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: self.feature.state.isBusy ? "arrow.triangle.2.circlepath" : "info.circle")
                .foregroundStyle(self.feature.state.isBusy ? Color.accentColor : .secondary)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .underPageBackgroundColor))
        )
    }

    private func secondaryLine(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func usageTint(remainingPercent: Double) -> Color {
        switch remainingPercent {
        case ..<20:
            return .red
        case ..<40:
            return .orange
        default:
            return .accentColor
        }
    }

    private var featuredRow: AccountProjectionRow? {
        self.feature.state.rows.first(where: { $0.isActive })
            ?? self.feature.state.rows.first(where: { $0.isLive })
            ?? self.feature.state.rows.first
    }

    private var secondaryRows: [AccountProjectionRow] {
        guard let featuredID = self.featuredRow?.id else {
            return self.feature.state.rows
        }
        return self.feature.state.rows.filter { $0.id != featuredID }
    }

    private var language: AppLanguage {
        self.feature.state.selectedLanguage
    }

    private var languagePicker: some View {
        Picker(self.localized("app.language.label"), selection: self.languageSelection) {
            ForEach(AppLanguage.allCases) { option in
                Text(CodeRelayLocalizer.languageOptionLabel(option, language: self.language))
                    .tag(option)
            }
        }
        .pickerStyle(.menu)
    }

    private var refreshUsageButton: some View {
        Button(self.localized("accounts.action.refreshUsage")) {
            Task {
                await self.feature.run(.refreshMonitoring)
            }
        }
        .buttonStyle(.bordered)
        .disabled(self.feature.state.isBusy || self.feature.state.rows.isEmpty)
    }

    @ViewBuilder
    private func addAccountButton(prominent: Bool) -> some View {
        if prominent {
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

    private var languageSelection: Binding<AppLanguage> {
        Binding(
            get: { self.feature.state.selectedLanguage },
            set: { newValue in
                Task {
                    await self.feature.run(.setLanguage(newValue))
                }
            })
    }

    private var warningThresholdSelection: Binding<Double> {
        Binding(
            get: { self.feature.state.warningPreferences.thresholdPercent },
            set: { newValue in
                Task {
                    await self.feature.run(.setWarningThreshold(newValue.rounded()))
                }
            })
    }

    private var warningRefreshCadenceSelection: Binding<WarningRefreshCadence> {
        Binding(
            get: { self.feature.state.warningPreferences.refreshCadence },
            set: { newValue in
                Task {
                    await self.feature.run(.setWarningRefreshCadence(newValue))
                }
            })
    }

    private var warningNotificationsSelection: Binding<Bool> {
        Binding(
            get: { self.feature.state.warningPreferences.notificationsEnabled },
            set: { newValue in
                Task {
                    await self.feature.run(.setWarningNotificationsEnabled(newValue))
                }
            })
    }

    private var warningThresholdText: String {
        CodeRelayLocalizer.format(
            "warnings.settings.threshold.value",
            language: self.language,
            Int(self.feature.state.warningPreferences.thresholdPercent.rounded()))
    }

    private func localized(_ key: String) -> String {
        CodeRelayLocalizer.text(key, language: self.language)
    }

    private static func badge(_ text: String, tint: Color, muted: Bool = false) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(muted ? Color.primary.opacity(0.72) : tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(muted ? Color.primary.opacity(0.07) : tint.opacity(0.12))
            )
    }
}
