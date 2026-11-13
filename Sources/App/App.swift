import SwiftUI

@main
struct App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("apple-build-agent")
                .font(.largeTitle.bold())
            Text("built by GitHub Actions")
                .foregroundStyle(.secondary)
            Button("tap me: \(count)") {
                count += 1
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
