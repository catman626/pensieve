import SwiftUI

struct TagCreatorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("新标签") {
                    TextField("例如：关系、工作、行动", text: $name)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit(create)
                }

                if !store.customTags.isEmpty {
                    Section("已有标签") {
                        ForEach(store.customTags, id: \.self) { tag in
                            Button {
                                store.applyTagAndAdvance(tag)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(tag)
                                    Spacer()
                                    if store.currentMetadata.tags.contains(tag) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建", action: create)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func create() {
        store.createTag(name)
        dismiss()
    }
}
