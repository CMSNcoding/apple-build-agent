import SwiftUI

struct QuoteView: View {
    @State private var quote: Quote = QuoteLibrary.cached() ?? QuoteLibrary.quoteOfTheDay()
    @State private var appeared = false
    @State private var spin = 0.0

    private var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M 月 d 日  EEEE"
        return f.string(from: Date())
    }

    @MainActor
    private func apply(_ q: Quote) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            quote = q
            appeared = false
        }
        withAnimation(.easeOut(duration: 0.32).delay(0.06)) {
            appeared = true
        }
    }

    /// 进入页面时：先展示缓存/本地那条，再静默换成远程一言
    private func loadDaily() async {
        if let remote = try? await QuoteLibrary.fetchDaily() {
            await apply(remote)
        }
    }

    /// 「换一条」：请求新的一条，失败就退回本地随机
    private func refreshQuote() async {
        if let remote = try? await QuoteLibrary.fetchFresh() {
            await apply(remote)
        } else {
            await apply(QuoteLibrary.random(excluding: quote))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.36, green: 0.30, blue: 0.62),
                             Color(red: 0.18, green: 0.16, blue: 0.36)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // 背景装饰圆
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 280)
                    .offset(x: 120, y: -180)
                    .blur(radius: 2)

                VStack(spacing: 0) {
                    Spacer(minLength: 20)

                    Text(dateText)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .tracking(1.2)

                    Spacer(minLength: 24)

                    VStack(alignment: .leading, spacing: 20) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.38))

                        Text(quote.text)
                            .font(.system(size: 23, weight: .medium, design: .serif))
                            .foregroundStyle(.white)
                            .lineSpacing(9)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 14)

                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(.white.opacity(0.55))
                                .frame(width: 22, height: 1)
                            Text(quote.author)
                                .font(.subheadline.weight(.regular))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .opacity(appeared ? 1 : 0)
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(.white.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 22)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.5)) { spin += 360 }
                        Task { await refreshQuote() }
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .rotationEffect(.degrees(spin))
                            Text("换一条")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 13)
                        .background(
                            Capsule().fill(.white.opacity(0.16))
                                .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1))
                        )
                    }
                    .padding(.bottom, 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
        .task { await loadDaily() }
    }
}
