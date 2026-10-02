import SwiftUI
import UIKit

struct FloatingActionBar: View {
    @EnvironmentObject private var store: AppStore
    @Binding var showingReflectionEditor: Bool
    @Binding var showingTagCreator: Bool
    let isCardTransitioning: Bool
    let onTag: (String) -> Void

    @State private var activatingTag: String?

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
                                activate(tag)
                            } label: {
                                Text(tag)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 8)
                                    .background(
                                        isTagHighlighted(tag)
                                            ? Color.indigo.opacity(0.18)
                                            : Color.secondary.opacity(0.08),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(
                                        isTagHighlighted(tag) ? Color.indigo : Color.primary
                                    )
                                    .overlay {
                                        if activatingTag == tag {
                                            Capsule()
                                                .stroke(Color.indigo.opacity(0.65), lineWidth: 1.5)
                                        }
                                    }
                                    .scaleEffect(activatingTag == tag ? 0.92 : 1)
                            }
                            .buttonStyle(.plain)
                            .disabled(isCardTransitioning)
                            .animation(.easeOut(duration: 0.12), value: activatingTag)
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

    private func isTagHighlighted(_ tag: String) -> Bool {
        activatingTag == tag || store.currentMetadata.tags.contains(tag)
    }

    private func activate(_ tag: String) {
        guard !isCardTransitioning else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.1)) {
            activatingTag = tag
        }
        onTag(tag)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            if activatingTag == tag {
                activatingTag = nil
            }
        }
    }
}
