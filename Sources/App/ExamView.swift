import SwiftUI
import UIKit

struct ExamSection: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var minutes: Double
}

struct ExamView: View {
    @EnvironmentObject private var stats: StatsStore

    static let defaultSections: [ExamSection] = [
        ExamSection(name: "听力", minutes: 30),
        ExamSection(name: "阅读", minutes: 40),
        ExamSection(name: "写作", minutes: 30)
    ]
    private let saveKey = "exam.sections.v1"
    private let notifPrefix = "exam."

    @State private var sections: [ExamSection] = ExamView.defaultSections
    @State private var editing = false

    @State private var running = false
    @State private var finished = false
    @State private var runStart: Date?
    @State private var elapsedBefore: TimeInterval = 0
    @State private var lastSectionIdx = 0
    @State private var warned5 = false
    @State private var warned1 = false

    init() {
        if let data = UserDefaults.standard.data(forKey: "exam.sections.v1"),
           let s = try? JSONDecoder().decode([ExamSection].self, from: data),
           !s.isEmpty {
            _sections = State(initialValue: s)
        }
    }

    private var totalMinutes: Double {
        sections.reduce(0) { $0 + $1.minutes }
    }

    private var totalDuration: TimeInterval { totalMinutes * 60 }

    private func elapsed(at date: Date) -> TimeInterval {
        elapsedBefore + (runStart.map { date.timeIntervalSince($0) } ?? 0)
    }

    private func sectionIndex(at t: TimeInterval) -> Int {
        var cum: TimeInterval = 0
        for i in sections.indices {
            cum += sections[i].minutes * 60
            if t < cum { return i }
        }
        return max(sections.count - 1, 0)
    }

    private func sectionEndTime(_ idx: Int) -> TimeInterval {
        var cum: TimeInterval = 0
        for i in 0...min(idx, sections.count - 1) {
            cum += sections[i].minutes * 60
        }
        return cum
    }

    var body: some View {
        NavigationStack {
            Group {
                if running || finished {
                    TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                        runArea(at: ctx.date)
                    }
                } else {
                    configArea
                }
            }
            .navigationTitle("考试模式")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .task { await watchExam() }
            .onDisappear { setKeepAwake(false) }
        }
    }

    // MARK: - 配置区

    private var configArea: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("科目与时长")
                        .font(.headline)
                    Spacer()
                    Button(editing ? "完成" : "编辑") {
                        Haptics.tap()
                        if editing { saveSections() }
                        editing.toggle()
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    ForEach(sections.indices, id: \.self) { i in
                        sectionRow(i)
                        if i < sections.count - 1 { Divider().padding(.leading, 16) }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground)))

                if editing {
                    Button {
                        sections.append(ExamSection(name: "新科目", minutes: 15))
                        saveSections()
                        Haptics.tap()
                    } label: {
                        Label("添加科目", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentColor.opacity(0.12)))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }

                Text("总时长 \(minuteText(totalMinutes))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    startExam()
                } label: {
                    Text("开始考试")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 14)
                            .fill(Color.accentColor))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(sections.isEmpty)

                Text("每科结束会震动提醒并推送通知；最后 5 分钟与 1 分钟另有提醒。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
        }
    }

    private func sectionRow(_ i: Int) -> some View {
        HStack(spacing: 10) {
            if editing {
                Button {
                    guard sections.count > 1 else { return }
                    Haptics.tap()
                    sections.remove(at: i)
                    saveSections()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            TextField("科目", text: bindingName(i))
                .textFieldStyle(.roundedBorder)

            Text("\(Int(sections[i].minutes)) 分")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize()

            if editing {
                Stepper("", value: bindingMinutes(i), in: 1...240, step: 5)
                    .labelsHidden()
                    .fixedSize()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func bindingName(_ i: Int) -> Binding<String> {
        Binding(
            get: { i < sections.count ? sections[i].name : "" },
            set: {
                guard i < sections.count else { return }
                sections[i].name = $0
                saveSections()
            })
    }

    private func bindingMinutes(_ i: Int) -> Binding<Double> {
        Binding(
            get: { i < sections.count ? sections[i].minutes : 1 },
            set: {
                guard i < sections.count else { return }
                sections[i].minutes = $0
                saveSections()
            })
    }

    private func saveSections() {
        if let data = try? JSONEncoder().encode(sections) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    // MARK: - 运行区

    private func runArea(at date: Date) -> some View {
        let t = elapsed(at: date)
        let idx = min(sectionIndex(at: t), sections.count - 1)
        let secRemaining = max(0, sectionEndTime(idx) - t)
        let totalRemaining = max(0, totalDuration - t)
        return VStack(spacing: 20) {
            segmentedBar(current: idx)
                .padding(.horizontal, 16)
                .padding(.top, 18)

            VStack(spacing: 6) {
                Text(finished ? "考试结束" : sections[idx].name)
                    .font(.title2.weight(.semibold))
                Text(clockText(finished ? 0 : secRemaining))
                    .font(.system(size: 58, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text("本场剩余 · 全程剩余 \(clockText(totalRemaining))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 8)

            runControls
        }
    }

    private func segmentedBar(current idx: Int) -> some View {
        GeometryReader { geo in
            HStack(spacing: 4) {
                ForEach(sections.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor(i, current: idx))
                        .frame(width: barWidth(i, total: geo.size.width))
                }
            }
        }
        .frame(height: 10)
    }

    private func barColor(_ i: Int, current: Int) -> Color {
        if finished || i < current { return Color.accentColor }
        if i == current { return Color.accentColor.opacity(0.55) }
        return Color.gray.opacity(0.25)
    }

    private func barWidth(_ i: Int, total: CGFloat) -> CGFloat {
        let gaps = CGFloat(max(sections.count - 1, 0)) * 4
        let unit = max(total - gaps, 1) / CGFloat(max(totalMinutes, 1))
        return unit * CGFloat(sections[i].minutes)
    }

    private var runControls: some View {
        HStack(spacing: 14) {
            if finished {
                Button {
                    Haptics.tap()
                    resetExam()
                } label: {
                    Text("再来一场")
                        .font(.headline)
                        .frame(width: 160, height: 50)
                        .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                        .foregroundStyle(Color.accentColor)
                }
            } else {
                Button {
                    Haptics.tap()
                    if running {
                        elapsedBefore = elapsed(at: Date())
                        runStart = nil
                        running = false
                        cancelExamNotifications()
                        setKeepAwake(false)
                    } else {
                        runStart = Date()
                        running = true
                        scheduleExamNotifications()
                        setKeepAwake(true)
                    }
                } label: {
                    Text(running ? "暂停" : "继续")
                        .font(.headline)
                        .frame(width: 124, height: 50)
                        .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                        .foregroundStyle(Color.accentColor)
                }

                Button {
                    Haptics.tap()
                    stopExam()
                } label: {
                    Text("结束")
                        .font(.headline)
                        .frame(width: 124, height: 50)
                        .background(Capsule().fill(Color(.secondarySystemGroupedBackground)))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: - 状态流转

    private func startExam() {
        Haptics.tap()
        running = true
        finished = false
        elapsedBefore = 0
        runStart = Date()
        lastSectionIdx = 0
        warned5 = false
        warned1 = false
        scheduleExamNotifications()
        setKeepAwake(true)
    }

    private func stopExam() {
        let spent = elapsed(at: Date()) / 60
        if spent >= 1 { stats.record(kind: "考试", minutes: spent) }
        running = false
        finished = false
        runStart = nil
        elapsedBefore = 0
        cancelExamNotifications()
        setKeepAwake(false)
    }

    private func finishExam() {
        Haptics.success()
        stats.record(kind: "考试", minutes: totalMinutes)
        running = false
        finished = true
        runStart = nil
        elapsedBefore = 0
        cancelExamNotifications()
        setKeepAwake(false)
    }

    private func resetExam() {
        finished = false
        elapsedBefore = 0
        runStart = nil
        lastSectionIdx = 0
        warned5 = false
        warned1 = false
    }

    private func scheduleExamNotifications() {
        let now = Date()
        for i in sections.indices {
            let fire = now.addingTimeInterval(sectionEndTime(i) - elapsedBefore)
            Notifier.schedule(id: "\(notifPrefix)\(i)",
                              title: "时间到",
                              body: "「\(sections[i].name)」部分结束",
                              at: fire)
        }
    }

    private func cancelExamNotifications() {
        Notifier.cancel(ids: sections.indices.map { "\(notifPrefix)\($0)" })
    }

    private func watchExam() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            guard running, runStart != nil else { continue }

            let t = elapsed(at: Date())
            let idx = sectionIndex(at: t)
            if idx != lastSectionIdx {
                Haptics.warning()
                lastSectionIdx = idx
                warned5 = false
                warned1 = false
            }
            if sections.count > 1 {
                let secRemaining = sectionEndTime(idx) - t
                if !warned5 && secRemaining <= 300 && secRemaining > 60 {
                    Haptics.warning()
                    warned5 = true
                }
                if !warned1 && secRemaining <= 60 && secRemaining > 0 {
                    Haptics.warning()
                    warned1 = true
                }
            }
            if t >= totalDuration {
                finishExam()
            }
        }
    }
}
