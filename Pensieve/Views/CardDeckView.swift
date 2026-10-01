import SwiftUI
import UIKit

struct CardDeckView: View {
    @EnvironmentObject private var store: AppStore
    let card: NoteCard

    @State private var horizontalOffset: CGFloat = 0
    @State private var isCommittingAction = false

    var body: some View {
        ZStack {
            cardSurface

            if horizontalOffset < -24 {
                actionBadge(title: "跳过", icon: "arrow.left", color: .gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(24)
            } else if horizontalOffset > 24 {
                actionBadge(title: "重要", icon: "star.fill", color: .orange)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(24)
            }
        }
        .offset(x: horizontalOffset)
        .rotationEffect(.degrees(Double(horizontalOffset / 32)))
        .opacity(isCommittingAction ? 0.25 : 1)
        .simultaneousGesture(horizontalSwipe)
        .onChange(of: card.id) {
            horizontalOffset = 0
            isCommittingAction = false
            store.markCurrentViewed()
        }
        .onAppear {
            store.markCurrentViewed()
        }
    }

    private var cardSurface: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(card.title)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    Text(card.relativePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        statusPill

                        if !store.currentMetadata.reflections.isEmpty {
                            Label("\(store.currentMetadata.reflections.count) 条感悟", systemImage: "quote.bubble")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                if card.content.isEmpty {
                    Text("这篇笔记目前没有正文。")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    Text(card.content)
                        .font(.body)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Color.clear.frame(height: 24)
            }
            .padding(22)
        }
        .scrollIndicators(.visible)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.7), lineWidth: 1)
        }
        .shadow(color: .indigo.opacity(0.12), radius: 20, y: 10)
    }

    @ViewBuilder
    private var statusPill: some View {
        let status = store.currentMetadata.classification
        switch status {
        case .unseen:
            Label("未标记", systemImage: "circle")
                .statusPillStyle(color: .blue)
        case .important:
            Label("重要", systemImage: "star.fill")
                .statusPillStyle(color: .orange)
        case .skipped:
            Label("已跳过", systemImage: "arrowshape.turn.up.left")
                .statusPillStyle(color: .gray)
        }
    }

    private var horizontalSwipe: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                guard !isCommittingAction else { return }
                let translation = value.translation
                guard abs(translation.width) > abs(translation.height) * 1.2 else { return }
                horizontalOffset = translation.width
            }
            .onEnded { value in
                guard !isCommittingAction else { return }
                let translation = value.translation
                let predicted = value.predictedEndTranslation.width
                let isHorizontal = abs(translation.width) > abs(translation.height) * 1.2
                let shouldCommit = abs(translation.width) > 110 || abs(predicted) > 180

                guard isHorizontal, shouldCommit else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                        horizontalOffset = 0
                    }
                    return
                }

                let classification: CardClassification = translation.width > 0 ? .important : .skipped
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                isCommittingAction = true

                withAnimation(.easeIn(duration: 0.18)) {
                    horizontalOffset = translation.width > 0 ? 700 : -700
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.19) {
                    store.classifyCurrent(as: classification)
                    horizontalOffset = 0
                    isCommittingAction = false
                }
            }
    }

    private func actionBadge(title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.thickMaterial, in: Capsule())
    }
}

private extension View {
    func statusPillStyle(color: Color) -> some View {
        self
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }
}
