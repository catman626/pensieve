import SwiftUI

struct ReflectionInboxView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.reflectionRecords.isEmpty {
                    ContentUnavailableView(
                        "还没有感悟",
                        systemImage: "quote.bubble",
                        description: Text("浏览卡片时点击底部的“感悟”按钮即可记录。")
                    )
                } else {
                    List(store.reflectionRecords) { record in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(record.noteTitle)
                                    .font(.headline)
                                Spacer()
                                Text(record.reflection.createdAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(record.reflection.text)
                                .foregroundStyle(record.reflection.isIntegrated ? .secondary : .primary)
                                .strikethrough(record.reflection.isIntegrated, color: .secondary)

                            HStack {
                                Text(record.relativePath)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                Spacer()
                                Button(record.reflection.isIntegrated ? "恢复待整理" : "标记已整合") {
                                    store.setReflectionIntegrated(
                                        cardID: record.cardID,
                                        reflectionID: record.reflection.id,
                                        integrated: !record.reflection.isIntegrated
                                    )
                                }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("感悟箱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
