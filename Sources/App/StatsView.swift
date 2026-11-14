import SwiftUI
import UIKit

struct StatsView: View {
    @EnvironmentObject private var stats: StatsStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryRow
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }
                Section("近 7 天") {
                    barChart
                        .padding(.vertical, 8)
                }
                Section("专注记录") {
                    if stats.sessions.isEmpty {
                        Text("还没有记录，去专注一轮回来看看")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(stats.sessions) { s in
                            sessionRow(s)
                        }
                        .onDelete { stats.delete(at: $0) }
                    }
                }
            }
            .navigationTitle("统计")
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 10) {
            summaryCard(title: "今日", value: minuteText(stats.todayMinutes))
            summaryCard(title: "本周", value: minuteText(stats.weekMinutes))
            summaryCard(title: "连续", value: "\(stats.streakDays) 天")
        }
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground)))
    }

    private var barChart: some View {
        let days = stats.last7Days
        let maxV = max(days.map(\.minutes).max() ?? 1, 10)
        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(days) { d in
                VStack(spacing: 6) {
                    Text(d.minutes >= 1 ? "\(Int(d.minutes))" : " ")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(d.isToday ? Color.accentColor : Color.accentColor.opacity(0.35))
                        .frame(height: CGFloat(8 + 120 * d.minutes / maxV))
                    Text(d.label)
                        .font(.caption2)
                        .foregroundStyle(d.isToday ? Color.accentColor : Color.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func sessionRow(_ s: FocusSession) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol(for: s.kind))
                .font(.system(size: 17))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(s.kind)
                    .font(.subheadline.weight(.medium))
                Text(s.date.formatted(.dateTime.month().day().hour().minute()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text(minuteText(s.minutes))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 3)
    }

    private func symbol(for kind: String) -> String {
        switch kind {
        case "番茄钟": return "timer"
        case "正计时": return "stopwatch"
        case "倒计时": return "hourglass"
        case "考试": return "graduationcap"
        default: return "checkmark.circle"
        }
    }
}
