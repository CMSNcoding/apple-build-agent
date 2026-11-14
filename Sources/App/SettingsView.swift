import SwiftUI
import UIKit

struct SettingsView: View {
    @AppStorage("pomo.focusMin") private var focusMin: Double = 25
    @AppStorage("pomo.shortMin") private var shortMin: Double = 5
    @AppStorage("pomo.longMin") private var longMin: Double = 15
    @AppStorage("pomo.longEvery") private var longEvery: Int = 4
    @AppStorage("pomo.autoNext") private var autoNext: Bool = true

    @EnvironmentObject private var stats: StatsStore
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Stepper("专注 \(Int(focusMin)) 分钟", value: $focusMin, in: 5...120, step: 5)
                    Stepper("短休息 \(Int(shortMin)) 分钟", value: $shortMin, in: 1...30)
                    Stepper("长休息 \(Int(longMin)) 分钟", value: $longMin, in: 5...60, step: 5)
                    Stepper("每 \(longEvery) 轮一次长休息", value: $longEvery, in: 2...8)
                    Toggle("自动开始下一阶段", isOn: $autoNext)
                } header: {
                    Text("番茄钟")
                } footer: {
                    Text("关闭自动开始时，每个阶段结束后需手动点「继续」。")
                }

                Section {
                    Button(role: .destructive) {
                        confirmClear = true
                    } label: {
                        Text("清除全部专注记录")
                    }
                } header: {
                    Text("数据")
                } footer: {
                    Text("共 \(stats.sessions.count) 条记录，全部保存在本机，不会上传。")
                }

                Section("关于") {
                    LabeledContent("应用", value: "专注")
                    LabeledContent("版本", value: "1.0")
                    LabeledContent("构建", value: "GitHub Actions")
                }
            }
            .navigationTitle("设置")
            .confirmationDialog("确定清除全部专注记录？",
                                isPresented: $confirmClear,
                                titleVisibility: .visible) {
                Button("清除", role: .destructive) {
                    Haptics.warning()
                    stats.clearAll()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作不可撤销。")
            }
        }
    }
}
