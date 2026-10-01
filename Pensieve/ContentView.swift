import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingFolderPicker = false
    @State private var showingFilter = false
    @State private var showingReflections = false
    @State private var showingReflectionEditor = false
    @State private var showingTagCreator = false

    var body: some View {
        NavigationStack {
            ZStack {
                PensieveBackground()

                if store.folderURL == nil {
                    WelcomeView {
                        showingFolderPicker = true
                    }
                } else if store.isScanning && store.notes.isEmpty {
                    ProgressView("正在读取 \(store.folderName)…")
                        .padding(28)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                } else if let card = store.currentCard {
                    CardDeckView(card: card)
                        .environmentObject(store)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                } else {
                    EmptyDeckView(filterTitle: store.activeFilter.title) {
                        store.setFilter(.discovery)
                    }
                }
            }
            .navigationTitle("Pensieve")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if store.folderURL != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingFilter = true
                        } label: {
                            Label(store.activeFilter.title, systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }

                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            showingReflections = true
                        } label: {
                            Image(systemName: store.pendingReflectionCount > 0 ? "quote.bubble.fill" : "quote.bubble")
                        }
                        .accessibilityLabel("感悟箱")

                        Menu {
                            Button {
                                Task { await store.refresh() }
                            } label: {
                                Label("重新扫描", systemImage: "arrow.clockwise")
                            }

                            Button {
                                showingFolderPicker = true
                            } label: {
                                Label("重新选择文件夹", systemImage: "folder")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if store.currentCard != nil {
                    FloatingActionBar(
                        showingReflectionEditor: $showingReflectionEditor,
                        showingTagCreator: $showingTagCreator
                    )
                    .environmentObject(store)
                }
            }
            .overlay(alignment: .top) {
                if store.isScanning && !store.notes.isEmpty {
                    ProgressView()
                        .padding(10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 4)
                }
            }
        }
        .sheet(isPresented: $showingFolderPicker) {
            FolderPicker { url in
                store.selectFolder(url)
            }
        }
        .sheet(isPresented: $showingFilter) {
            FilterSheet()
                .environmentObject(store)
        }
        .sheet(isPresented: $showingReflections) {
            ReflectionInboxView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showingReflectionEditor) {
            ReflectionEditorView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showingTagCreator) {
            TagCreatorView()
                .environmentObject(store)
        }
        .alert("Pensieve", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("好") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "发生未知错误")
        }
    }
}

private struct PensieveBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.91, green: 0.96, blue: 1.0),
                Color(red: 0.96, green: 0.94, blue: 1.0),
                Color(red: 0.93, green: 0.98, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct WelcomeView: View {
    let chooseFolder: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 64))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.indigo, .cyan)

            VStack(spacing: 10) {
                Text("把旧笔记重新带回眼前")
                    .font(.title2.bold())
                Text("选择一个 Obsidian 文件夹。Pensieve 只读取其中的 Markdown，一篇笔记对应一张卡片。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Button(action: chooseFolder) {
                Label("选择 Obsidian 文件夹", systemImage: "folder.badge.plus")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)

            Text("不会修改或写回原文件")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }
}

private struct EmptyDeckView: View {
    let filterTitle: String
    let returnToDiscovery: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("这里暂时没有卡片", systemImage: "rectangle.stack")
        } description: {
            Text("当前范围：\(filterTitle)")
        } actions: {
            Button("返回发现") {
                returnToDiscovery()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
