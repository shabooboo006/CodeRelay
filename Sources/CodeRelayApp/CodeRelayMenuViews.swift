import AppKit
import SwiftUI

struct CodeRelayMenuSummaryView: View {
    let model: CodeRelayMenuPresentation.Summary
    private let cardWidth: CGFloat = 320

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: self.model.iconName)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(self.model.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    Text(self.model.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if !self.model.badges.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(self.model.badges.enumerated()), id: \.offset) { _, badge in
                        self.badgeView(badge)
                    }
                }
            }

            if !self.model.metrics.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(self.model.metrics, id: \.id) { metric in
                        self.metricView(metric)
                    }
                }
            }

            if !self.model.details.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(self.model.details, id: \.id) { detail in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(detail.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer(minLength: 0)

                            Text(detail.value)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }

            if let notice = self.model.notice {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text(notice.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)

                    Text(notice.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.08))
                )
            }
        }
        .padding(14)
        .frame(width: self.cardWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.18))
                )
        )
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private func badgeView(_ badge: CodeRelayMenuPresentation.Summary.Badge) -> some View {
        Text(badge.text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(badge.kind == .active ? Color.accentColor : Color.primary.opacity(0.72))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(badge.kind == .active ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.07))
            )
    }

    private func metricView(_ metric: CodeRelayMenuPresentation.Summary.Metric) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(metric.title)
                    .font(.caption.weight(.semibold))

                Spacer(minLength: 0)

                Text(metric.value)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: max(0, min(metric.remainingPercent / 100, 1)))
                .tint(self.metricTint(metric.remainingPercent))
                .controlSize(.small)

            Text(metric.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func metricTint(_ remainingPercent: Double) -> Color {
        switch remainingPercent {
        case ..<20:
            return .red
        case ..<40:
            return .orange
        default:
            return .accentColor
        }
    }
}

struct CodeRelayMenuMessageView: View {
    let message: String
    let isBusy: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: self.isBusy ? "arrow.triangle.2.circlepath" : "info.circle")
                .foregroundStyle(self.isBusy ? Color.accentColor : .secondary)
            Text(self.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 320, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .underPageBackgroundColor))
        )
        .padding(.horizontal, 6)
        .padding(.bottom, 4)
    }
}
