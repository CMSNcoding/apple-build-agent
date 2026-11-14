import SwiftUI
import UIKit
import UserNotifications

// MARK: - 数据模型

struct FocusSession: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let minutes: Double
    let kind: String
}

struct DayStat: Identifiable {
    var id: Int { offset }
    let offset: Int
    let label: String
    let minutes: Double
    let isToday: Bool
}

// MARK: - 专注记录仓库

final class StatsStore: ObservableObject {
    @Published private(set) var sessions: [FocusSession] = []

    private let key = "focus.sessions.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([FocusSession].self, from: data) {
            sessions = decoded
        }
    }

    func record(kind: String, minutes: Double, date: Date = Date()) {
        guard minutes >= 1 else { return }
        sessions.insert(FocusSession(date: date, minutes: minutes, kind: kind), at: 0)
        if sessions.count > 500 {
            sessions = Array(sessions.prefix(500))
        }
        save()
    }

    func delete(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
        save()
    }

    func clearAll() {
        sessions.removeAll()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func startOfDay(_ d: Date) -> Date {
        Calendar.current.startOfDay(for: d)
    }

    func minutesOn(_ day: Date) -> Double {
        let s = startOfDay(day)
        let e = s.addingTimeInterval(86_400)
        return sessions
            .filter { $0.date >= s && $0.date < e }
            .reduce(0) { $0 + $1.minutes }
    }

    var todayMinutes: Double { minutesOn(Date()) }

    var weekMinutes: Double {
        last7Days.reduce(0) { $0 + $1.minutes }
    }

    var last7Days: [DayStat] {
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]
        var out: [DayStat] = []
        for offset in (0...6).reversed() {
            let day = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let label = offset == 0 ? "今天" : symbols[Calendar.current.component(.weekday, from: day) - 1]
            out.append(DayStat(offset: offset,
                               label: label,
                               minutes: minutesOn(day),
                               isToday: offset == 0))
        }
        return out
    }

    var streakDays: Int {
        var n = 0
        var offset = minutesOn(Date()) >= 1 ? 0 : 1
        while offset < 400 {
            let day = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            if minutesOn(day) >= 1 {
                n += 1
                offset += 1
            } else {
                break
            }
        }
        return n
    }
}

// MARK: - 本地通知

enum Notifier {
    static func schedule(id: String, title: String, body: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel(ids: [String]) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ids)
    }
}

// MARK: - 触感

enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

// MARK: - 格式化与通用组件

func clockText(_ t: TimeInterval) -> String {
    let total = max(0, t)
    let h = Int(total) / 3600
    let m = (Int(total) % 3600) / 60
    let s = Int(total) % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%02d:%02d", m, s)
}

func minuteText(_ m: Double) -> String {
    if m >= 60 {
        let h = Int(m) / 60
        let mm = Int(m) % 60
        return mm == 0 ? "\(h) 小时" : "\(h) 小时 \(mm) 分"
    }
    return String(format: "%.0f 分钟", m)
}

struct RingProgress: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 16

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

func setKeepAwake(_ on: Bool) {
    UIApplication.shared.isIdleTimerDisabled = on
}
