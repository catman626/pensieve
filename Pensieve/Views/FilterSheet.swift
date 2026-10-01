import SwiftUI

struct FilterSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("系统范围") {
                    filterButton(.discovery, count: store.unseenCount)
                    filterButton(.important, count: store.importantCount)
                    filterButton(.skipped, count: store.skippedCount)
                }

                if !store.customTags.isEmpty {
                    Section("标签") {
                        ForEach(store.customTags, id: \.self) { tag in
                            filterButton(.tag(tag), count: store.count(for: tag))
                        }
                    }
                }

                Section {
                    LabeledContent("总笔记", value: "\(store.notes.count)")
                    LabeledContent("当前文件夹", value: store.folderName)
                }
            }
            .navigationTitle("选择卡片范围")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func filterButton(_ filter: BrowseFilter, count: Int) -> some View {
        Button {
            store.setFilter(filter)
            dismiss()
        } label: {
            HStack {
                Text(filter.title)
                Spacer()
                Text("\(count)")
                    .foregroundStyle(.secondary)
                if store.activeFilter == filter {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.indigo)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}
