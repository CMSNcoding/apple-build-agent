import SwiftUI
import UIKit

enum FocusMode: String, CaseIterable, Identifiable {
    case pomodoro, countUp, countdown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pomodoro: return "番茄钟"
        case .countUp: return "正计时"
        case .countdown: return "倒计时"
        }
    }
}

enum PomodoroPhase {
    case focus, shortBreak, longBreak
}

struct FocusHomeView: View {
    @State private var mode: FocusMode = .pomodoro

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("模式", selection: $mode) {
                    ForEach(FocusMode.allCases) { m in
                        Text(m.title).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 4)

                switch mode {
                case .pomodoro: PomodoroView()
                case .countUp: CountUpView()
                case .countdown: CountdownView()
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("专注")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - 番茄钟

struct PomodoroView: View {
    @AppStorage("pomo.focusMin") private var focusMin: Double = 25
    @AppStorage("pomo.shortMin") private var shortMin: Double = 5
    @AppStorage("pomo.longMin") private var longMin: Double = 15
    @AppStorage("pomo.longEvery") private var longEvery: Int = 4
    @AppStorage("pomo.autoNext") private var autoNext: Bool = true

    @EnvironmentObject private var stats: StatsStore

    @State private var phase: PomodoroPhase = .focus
    @State private var endDate: Date?
    @State private var pausedRemaining: TimeInterval?
    @State private var doneFocus = 0

    private var isRunning: Bool { endDate != nil }

    private var phaseDuration: TimeInterval {
        switch phase {
        case .focus: return focusMin * 60
        case .shortBreak: return shortMin * 60
        case .longBreak: return longMin * 60
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .focus: return Color.accentColor
        case .shortBreak: return .teal
        case .longBreak: return .mint
        }
    }

    private var phaseTitle: String {
        switch phase {
        case .focus: return "专注中"
        case .shortBreak: return "短休息"
        case .longBreak: return "长休息"
        }
    }

    private var buttonTitle: String {
        if isRunning { return "暂停" }
        if pausedRemaining != nil { return "继续" }
        return "开始"
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let remaining = currentRemaining(at: ctx.date)
            let total = max(phaseDuration, 1)
            VStack(spacing: 20) {
                Text("今日已专注 \(minuteText(stats.todayMinutes))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 14)

                ZStack {
                    RingProgress(progress: 1 - remaining / total,
                                 color: phaseColor, lineWidth: 18)
                    VStack(spacing: 6) {
                        Text(clockText(remaining))
                            .font(.system(size: 52, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Text(phaseTitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 258, height: 258)

                dotsRow

                controls
            }
            .padding(.bottom, 20)
        }
        .task { await watchCompletion() }
        .onDisappear { setKeepAwake(false) }
    }

    private var dotsRow: some View {
        let shown = max(longEvery, 1)
        let filled = doneFocus == 0 ? 0 : (doneFocus % shown == 0 ? shown : doneFocus % shown)
        return HStack(spacing: 10) {
            ForEach(0..<shown, id: \.self) { i in
                Circle()
                    .fill(i < filled ? Color.accentColor : Color.gray.opacity(0.28))
                    .frame(width: 10, height: 10)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button {
                toggleRun()
            } label: {
                Text(buttonTitle)
                    .font(.headline)
                    .frame(width: 124, height: 50)
                    .background(Capsule().fill(phaseColor.opacity(0.18)))
                    .foregroundStyle(phaseColor)
            }

            Button {
                Haptics.tap()
                advancePhase(recordFocus: false)
            } label: {
                Image(systemName: "forward.end")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color(.secondarySystemGroupedBackground)))
                    .foregroundStyle(.primary)
            }
            .disabled(doneFocus == 0 && !isRunning && pausedRemaining == nil)

            Button {
                resetAll()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color(.secondarySystemGroupedBackground)))
                    .foregroundStyle(.primary)
            }
            .disabled(doneFocus == 0 && !isRunning && pausedRemaining == nil)
        }
    }

    // MARK: 状态机

    private func currentRemaining(at date: Date) -> TimeInterval {
        if let e = endDate { return max(0, e.timeIntervalSince(date)) }
        if let p = pausedRemaining { return max(0, p) }
        return phaseDuration
    }

    private func toggleRun() {
        Haptics.tap()
        if let e = endDate {
            pausedRemaining = e.timeIntervalSinceNow
            endDate = nil
            Notifier.cancel(ids: ["pomo.end"])
            setKeepAwake(false)
        } else {
            startPhase()
        }
    }

    private func startPhase() {
        let d = pausedRemaining ?? phaseDuration
        pausedRemaining = nil
        endDate = Date().addingTimeInterval(d)
        scheduleEndNotification()
        setKeepAwake(true)
    }

    private func advancePhase(recordFocus: Bool) {
        Haptics.success()
        Notifier.cancel(ids: ["pomo.end"])
        if phase == .focus {
            if recordFocus { stats.record(kind: "番茄钟", minutes: focusMin) }
            doneFocus += 1
            phase = (doneFocus % max(longEvery, 1) == 0) ? .longBreak : .shortBreak
        } else {
            phase = .focus
        }
        endDate = nil
        pausedRemaining = nil
        if autoNext {
            startPhase()
        } else {
            setKeepAwake(false)
        }
    }

    private func resetAll() {
        phase = .focus
        doneFocus = 0
        endDate = nil
        pausedRemaining = nil
        Notifier.cancel(ids: ["pomo.end"])
        setKeepAwake(false)
    }

    private func scheduleEndNotification() {
        guard let e = endDate else { return }
        let title: String
        let body: String
        switch phase {
        case .focus:
            title = "专注完成"
            body = "这轮 \(Int(focusMin)) 分钟结束了，休息一下"
        case .shortBreak:
            title = "短休息结束"
            body = "回来继续专注吧"
        case .longBreak:
            title = "长休息结束"
            body = "状态回来了，开始下一轮"
        }
        Notifier.schedule(id: "pomo.end", title: title, body: body, at: e)
    }

    private func watchCompletion() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            if let e = endDate, Date() >= e {
                advancePhase(recordFocus: true)
            }
        }
    }
}
