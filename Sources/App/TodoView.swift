import SwiftUI

struct TodoView: View {
    @StateObject private var store = TodoStore()
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                inputBar

                if store.items.isEmpty {
                    emptyView
                } else {
                    List {
                        if !store.pending.isEmpty {
                            Section {
                                ForEach(store.pending) { item in
                                    row(item)
                                }
                                .onDelete { store.delete(at: $0, from: store.pending) }
                            } header: {
                                Text("待完成 · \(store.pending.count)")
                            }
                        }

                        if !store.completed.isEmpty {
                            Section {
                                ForEach(store.completed) { item in
                                    row(item)
                                }
                                .onDelete { store.delete(at: $0, from: store.completed) }
                            } header: {
                                HStack {
                                    Text("已完成 · \(store.completed.count)")
                                    Spacer()
                                    Button("清除") {
                                        withAnimation { store.clearCompleted() }
                                    }
                                    .font(.caption.weight(.semibold))
                                    .textCase(nil)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("待办")
        }
    }

    // MARK: - 输入栏

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("添加一件要做的事…", text: $draft)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .submitLabel(.done)
                .onSubmit(commit)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

            Button(action: commit) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(draft.trimmingCharacters(in: .whitespaces).isEmpty
                                  ? Color.gray.opacity(0.35)
                                  : Color.accentColor)
                    )
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            Text("还没有待办")
                .font(.headline)
            Text("在上面输入框里写一件，回车即可添加")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 单行

    private func row(_ item: TodoItem) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) { store.toggle(item) }
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .foregroundStyle(item.isDone ? Color.accentColor : Color.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.body)
                .strikethrough(item.isDone, color: .secondary)
                .foregroundStyle(item.isDone ? .secondary : .primary)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    private func commit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            store.add(text)
        }
        draft = ""
    }
}
