import Foundation

enum VaultScannerError: LocalizedError {
    case accessDenied
    case cannotEnumerate

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "无法访问所选文件夹，请重新授权。"
        case .cannotEnumerate:
            "无法读取所选文件夹。"
        }
    }
}

enum VaultScanner {
    static func scan(folderURL: URL) async throws -> [NoteCard] {
        try await Task.detached(priority: .userInitiated) {
            try scanSynchronously(folderURL: folderURL)
        }.value
    }

    private static func scanSynchronously(folderURL: URL) throws -> [NoteCard] {
        let didAccess = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        let resourceKeys: [URLResourceKey] = [
            .isRegularFileKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw VaultScannerError.cannotEnumerate
        }

        var cards: [NoteCard] = []
        let rootPath = folderURL.standardizedFileURL.path

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "md" else { continue }

            let standardizedPath = fileURL.standardizedFileURL.path
            let relativePath: String
            if standardizedPath.hasPrefix(rootPath + "/") {
                relativePath = String(standardizedPath.dropFirst(rootPath.count + 1))
            } else {
                relativePath = fileURL.lastPathComponent
            }

            let components = relativePath.split(separator: "/").map(String.init)
            if components.contains(".git") || components.contains(".obsidian") {
                continue
            }

            let values = try? fileURL.resourceValues(forKeys: Set(resourceKeys))
            guard values?.isRegularFile != false else { continue }

            if let card = coordinatedRead(
                fileURL: fileURL,
                relativePath: relativePath,
                modifiedAt: values?.contentModificationDate
            ) {
                cards.append(card)
            }
        }

        return cards.sorted {
            $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending
        }
    }

    private static func coordinatedRead(
        fileURL: URL,
        relativePath: String,
        modifiedAt: Date?
    ) -> NoteCard? {
        var coordinatorError: NSError?
        var result: NoteCard?
        let coordinator = NSFileCoordinator(filePresenter: nil)

        coordinator.coordinate(readingItemAt: fileURL, options: [], error: &coordinatorError) { url in
            guard let data = try? Data(contentsOf: url),
                  let rawText = String(data: data, encoding: .utf8) else {
                return
            }

            let title = url.deletingPathExtension().lastPathComponent
            result = NoteCard(
                id: relativePath,
                title: title,
                relativePath: relativePath,
                content: MarkdownCleaner.displayText(from: rawText),
                modifiedAt: modifiedAt
            )
        }

        return result
    }
}

enum MarkdownCleaner {
    static func displayText(from source: String) -> String {
        var text = source

        if text.hasPrefix("---\n"), let end = text.range(of: "\n---\n", range: text.index(text.startIndex, offsetBy: 4)..<text.endIndex) {
            text.removeSubrange(text.startIndex..<end.upperBound)
        }

        text = replacingInlineBase64Images(in: text)

        if let regex = try? NSRegularExpression(pattern: #"!\[\[([^\]]+)\]\]"#) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "[附件：$1]")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replacingInlineBase64Images(in source: String) -> String {
        guard source.contains("data:image") else { return source }

        var result = source
        while let start = result.range(of: "![](data:image") {
            guard let end = result[start.lowerBound...].firstIndex(of: ")") else { break }
            result.replaceSubrange(start.lowerBound...end, with: "[内嵌图片]")
        }
        return result
    }
}
