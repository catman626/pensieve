import SwiftUI

struct FloatingActionBar: View {
    @EnvironmentObject private var store: AppStore
    @Binding var showingReflectionEditor: Bool
    @Binding var showingTagCreator: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button {
                showingReflectionEditor = true
            } label: {
                Label("感悟", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)

            if !store.customTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.customTags, id: \.self) { tag in
                            Button {
                                store.toggleTag(tag)
                            } label: {
                                Text(tag)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 8)
                                    .background(
                                        store.currentMetadata.tags.contains(tag)
                                            ? Color.indigo.opacity(0.18)
                                            : Color.secondary.opacity(0.08),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(
                                        store.currentMetadata.tags.contains(tag) ? Color.indigo : Color.primary
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Button {
                showingTagCreator = true
            } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.bordered)
            .clipShape(Circle())
            .accessibilityLabel("创建标签")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
