import SwiftUI

@main
struct AppleBuildAgentApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}

struct RootTabView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            QuoteView()
                .tabItem { Label("一言", systemImage: "quote.bubble") }
                .tag(0)

            NewsView()
                .tabItem { Label("热榜", systemImage: "flame") }
                .tag(1)

            ClockView()
                .tabItem { Label("时钟", systemImage: "clock") }
                .tag(2)

            TodoView()
                .tabItem { Label("待办", systemImage: "checkmark.circle") }
                .tag(3)
        }
        .tint(Color.accentColor)
    }
}
