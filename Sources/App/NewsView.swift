import SwiftUI
import UIKit

struct NewsView: View {
    @State private var items: [NewsItem] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var isFallback = false
    @State private var updatedAt: Date?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && items.isEmpty {
                    loadingView
                } else if items.isEmpty {
                    emptyView
                } else {
                    listView
                }
            }
            .navigationTitle("热榜")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .refreshable { await load() }
            .task {
                if items.isEmpty { await load() }
            }
        }
    }

    // MARK: - 子视图

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("正在拉取全网热榜…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("暂时没有内容")
                .font(.headline)
            Text(errorText ?? "下拉可重试")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("重试") { Task { await load() } }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listView: some View {
        List {
            if isFallback {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "wifi.exclamationmark")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("当前显示本地示例")
                                .font(.footnote.weight(.semibold))
                            Text(errorText ?? "无法连接热榜接口")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                ForEach(items.indices, id: \.self) { i in
                    row(index: i + 1, item: items[i])
                }
            } footer: {
                if let d = updatedAt {
                    Text("更新于 " + d.formatted(date: .omitted, time: .shortened))
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func row(index: Int, item: NewsItem) -> some View {
        Button {
            guard let url = URL(string: item.urlString), !item.urlString.isEmpty else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text("\(index)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(index <= 3 ? Color.accentColor : .secondary)
                    .frame(width: 22, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)

                    HStack(spacing: 8) {
                        Text(item.source)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let hot = item.hot, !hot.isEmpty {
                            Text(hot)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 数据

    @MainActor
    private func load() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            let fresh = try await NewsService.fetch()
            if fresh.isEmpty { throw URLError(.zeroByteResource) }
            items = fresh
            isFallback = false
            updatedAt = Date()
        } catch {
            errorText = (error as NSError).localizedDescription
            if items.isEmpty {
                items = NewsService.fallback
                isFallback = true
                updatedAt = Date()
            }
        }
    }
}
