import SwiftUI
import UIKit

// MARK: - 正计时

struct CountUpView: View {
    @EnvironmentObject private var stats: StatsStore

    @State private var startDate: Date?
    @State private var accumulated: TimeInterval = 0
    @State private var goalMinutes: Double = 25
    @State private var goalNotified = false

    private var isRunning: Bool { startDate != nil }
    private var hasContent: Bool { isRunning || accumulated >= 1 }

    private func elapsed(at date: Date) -> TimeInterval {
        accumulated + (startDate.map { date.timeIntervalSince($0) } ?? 0)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let e = elapsed(at: ctx.date)
            let frac = goalMinutes > 0
                ? e / (goalMinutes * 60)
                : e.truncatingRemainder(dividingBy: 3600) / 3600
            VStack(spacing: 20) {
                ZStack {
                    RingProgress(progress: frac,
                                 color: Color.accentColor, lineWidth: 18)
                    VStack(spacing: 6) {
                        Text(clockText(e))
                            .font(.system(size: 52, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Text(goalMinutes > 0 ? "目标 \(Int(goalMinutes)) 分钟" : "自由计时")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 258, height: 258)
                .padding(.top, 14)

                goalChips

                controls
            }
            .padding(.bottom, 20)
        }
        .task { await watchGoal() }
        .onDisappear { setKeepAwake(false) }
    }

    private var goalChips: some View {
        HStack(spacing: 10) {
            ForEach([0, 25, 45, 60, 90], id: \.self) { m in
                Button {
                    Haptics.tap()
                    goalMinutes = Double(m)
                } label: {
                    Text(m == 0 ? "不限" : "\(m) 分")
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(
                            Int(goalMinutes) == m
                            ? Color.accentColor.opacity(0.2)
                            : Color(.secondarySystemGroupedBackground)))
                        .foregroundStyle(Int(goalMinutes) == m ? Color.accentColor : Color.primary)
                }
                .disabled(isRunning)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button {
                Haptics.tap()
                if let s = startDate {
                    accumulated += Date().timeIntervalSince(s)
                    startDate = nil
                    setKeepAwake(false)
                } else {
                    goalNotified = false
                    startDate = Date()
                    setKeepAwake(true)
                }
            } label: {
                Text(isRunning ? "暂停" : (accumulated > 0 ? "继续" : "开始"))
                    .font(.headline)
                    .frame(width: 124, height: 50)
                    .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                    .foregroundStyle(Color.accentColor)
            }

            Button {
                stats.record(kind: "正计时", minutes: elapsed(at: Date()) / 60)
                Haptics.success()
                accumulated = 0
                startDate = nil
                setKeepAwake(false)
            } label: {
                Text("结束并记录")
                    .font(.headline)
                    .frame(width: 150, height: 50)
                    .background(Capsule().fill(Color(.secondarySystemGroupedBackground)))
                    .foregroundStyle(.primary)
            }
            .disabled(!hasContent)
        }
    }

    private func watchGoal() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            if isRunning, goalMinutes > 0, !goalNotified,
               elapsed(at: Date()) >= goalMinutes * 60 {
                Haptics.success()
                goalNotified = true
            }
        }
    }
}

// MARK: - 倒计时

struct CountdownView: View {
    @EnvironmentObject private var stats: StatsStore

    @State private var totalMinutes: Double = 25
    @State private var endDate: Date?
    @State private var pausedRemaining: TimeInterval?
    @State private var finished = false

    private var isRunning: Bool { endDate != nil }
    private var total: TimeInterval { totalMinutes * 60 }

    private func remaining(at date: Date) -> TimeInterval {
        if let e = endDate { return max(0, e.timeIntervalSince(date)) }
        if let p = pausedRemaining { return max(0, p) }
        return finished ? 0 : total
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let r = remaining(at: ctx.date)
            VStack(spacing: 20) {
                ZStack {
                    RingProgress(progress: total > 0 ? r / total : 0,
                                 color: finished ? .green : Color.accentColor,
                                 lineWidth: 18)
                    VStack(spacing: 6) {
                        Text(clockText(r))
                            .font(.system(size: 52, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Text(finished ? "时间到，干得漂亮" : "倒计时")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 258, height: 258)
                .padding(.top, 14)

                if !isRunning && !finished {
                    presetChips
                }

                controls
            }
            .padding(.bottom, 20)
        }
        .task { await watchEnd() }
        .onDisappear { setKeepAwake(false) }
    }

    private var presetChips: some View {
        HStack(spacing: 8) {
            ForEach([5, 10, 15, 20, 25, 30, 45, 60, 90], id: \.self) { m in
                Button {
                    Haptics.tap()
                    totalMinutes = Double(m)
                    finished = false
                } label: {
                    Text("\(m)")
                        .font(.footnote.weight(.medium))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(
                            Int(totalMinutes) == m
                            ? Color.accentColor.opacity(0.22)
                            : Color(.secondarySystemGroupedBackground)))
                        .foregroundStyle(Int(totalMinutes) == m ? Color.accentColor : Color.primary)
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button {
                Haptics.tap()
                if let e = endDate {
                    pausedRemaining = e.timeIntervalSinceNow
                    endDate = nil
                    Notifier.cancel(ids: ["countdown.end"])
                    setKeepAwake(false)
                } else {
                    finished = false
                    let d = pausedRemaining ?? total
                    pausedRemaining = nil
                    endDate = Date().addingTimeInterval(d)
                    Notifier.schedule(id: "countdown.end",
                                      title: "倒计时结束",
                                      body: "\(Int(totalMinutes)) 分钟到了",
                                      at: endDate!)
                    setKeepAwake(true)
                }
            } label: {
                Text(isRunning ? "暂停" : (pausedRemaining != nil && !finished ? "继续" : "开始"))
                    .font(.headline)
                    .frame(width: 124, height: 50)
                    .background(Capsule().fill(
                        finished ? Color.green.opacity(0.18) : Color.accentColor.opacity(0.18)))
                    .foregroundStyle(finished ? Color.green : Color.accentColor)
            }
            .disabled(finished)

            Button {
                Haptics.tap()
                endDate = nil
                pausedRemaining = nil
                finished = false
                Notifier.cancel(ids: ["countdown.end"])
                setKeepAwake(false)
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color(.secondarySystemGroupedBackground)))
                    .foregroundStyle(.primary)
            }
            .disabled(!isRunning && pausedRemaining == nil && !finished
                      && remaining(at: Date()) == total)
        }
    }

    private func watchEnd() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            if let e = endDate, Date() >= e {
                Haptics.success()
                stats.record(kind: "倒计时", minutes: totalMinutes)
                endDate = nil
                pausedRemaining = 0
                finished = true
                Notifier.cancel(ids: ["countdown.end"])
                setKeepAwake(false)
            }
        }
    }
}
