import SwiftUI
import Combine

struct ClockView: View {
    // 秒表状态
    @State private var startDate: Date?
    @State private var accumulated: TimeInterval = 0
    @State private var laps: [TimeInterval] = []
    @State private var now = Date()

    private let ticker = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    private let cities: [(name: String, tz: String, flag: String)] = [
        ("北京", "Asia/Shanghai", "🇨🇳"),
        ("东京", "Asia/Tokyo", "🇯🇵"),
        ("伦敦", "Europe/London", "🇬🇧"),
        ("纽约", "America/New_York", "🇺🇸")
    ]

    private var isRunning: Bool { startDate != nil }

    private var elapsed: TimeInterval {
        accumulated + (startDate.map { now.timeIntervalSince($0) } ?? 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    worldClockSection
                    stopwatchSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("时钟")
            .onReceive(ticker) { t in
                if isRunning { now = t }
            }
        }
    }

    // MARK: - 世界时钟

    private var worldClockSection: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            VStack(alignment: .leading, spacing: 10) {
                Text("世界时钟")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(cities, id: \.tz) { city in
                        cityCard(city, at: ctx.date)
                    }
                }
            }
        }
    }

    private func cityCard(_ city: (name: String, tz: String, flag: String), at date: Date) -> some View {
        let tz = TimeZone(identifier: city.tz) ?? .current
        let hourF = DateFormatter()
        hourF.timeZone = tz
        hourF.dateFormat = "HH:mm"

        let dayF = DateFormatter()
        dayF.timeZone = tz
        dayF.dateFormat = "MM-dd"

        let offset = (tz.secondsFromGMT(for: date) - TimeZone.current.secondsFromGMT(for: date)) / 3600
        let offsetText = offset == 0 ? "本地" : String(format: "%+d h", offset)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(city.flag).font(.subheadline)
                Text(city.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            Text(hourF.string(from: date))
                .font(.system(size: 30, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)

            HStack(spacing: 6) {
                Text(dayF.string(from: date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(offsetText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - 秒表

    private var stopwatchSection: some View {
        VStack(spacing: 18) {
            Text(timeText(elapsed))
                .font(.system(size: 58, weight: .thin, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

            HStack(spacing: 14) {
                Button {
                    if isRunning { pause() } else { start() }
                } label: {
                    Text(isRunning ? "暂停" : (elapsed > 0 ? "继续" : "开始"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isRunning
                                      ? Color.orange.opacity(0.18)
                                      : Color.accentColor.opacity(0.16))
                        )
                        .foregroundStyle(isRunning ? Color.orange : Color.accentColor)
                }

                Button {
                    if isRunning { lap() } else { reset() }
                } label: {
                    Text(isRunning ? "计次" : "重置")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .foregroundStyle(elapsed > 0 ? .primary : .secondary)
                }
                .disabled(elapsed == 0)
            }

            if !laps.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(laps.indices.reversed()), id: \.self) { i in
                        HStack {
                            Text("第 \(i + 1) 次")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(timeText(laps[i]))
                                .font(.subheadline.weight(.medium).monospacedDigit())
                        }
                        .padding(.vertical, 11)

                        if i > 0 { Divider() }
                    }
                }
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
        }
    }

    // MARK: - 操作

    private func start() {
        now = Date()
        startDate = Date()
    }

    private func pause() {
        accumulated = elapsed
        startDate = nil
    }

    private func lap() {
        laps.append(elapsed)
    }

    private func reset() {
        startDate = nil
        accumulated = 0
        laps.removeAll()
    }

    private func timeText(_ t: TimeInterval) -> String {
        let total = max(0, t)
        let m = Int(total) / 60
        let s = Int(total) % 60
        let cs = Int((total - floor(total)) * 100)
        return String(format: "%02d:%02d.%02d", m, s, cs)
    }
}
