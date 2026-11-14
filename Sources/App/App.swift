import SwiftUI
import UserNotifications

@main
struct FocusApp: App {
    @StateObject private var stats = StatsStore()

    init() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(stats)
        }
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            FocusHomeView()
                .tabItem { Label("专注", systemImage: "timer") }
            ExamView()
                .tabItem { Label("考试", systemImage: "graduationcap") }
            StatsView()
                .tabItem { Label("统计", systemImage: "chart.bar.fill") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}
