import Foundation

struct LauncherLayout: Codable, Equatable, Sendable {
    var orderedApplicationIDs: [String] = []
    var hiddenApplicationIDs: Set<String> = []
}

struct LayoutRepository: Sendable {
    let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            self.fileURL = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            .appendingPathComponent("LaunchDeck", isDirectory: true)
            .appendingPathComponent("layout.json", isDirectory: false)
        }
    }

    func load() -> LauncherLayout {
        guard let data = try? Data(contentsOf: fileURL),
              let layout = try? JSONDecoder().decode(LauncherLayout.self, from: data) else {
            return LauncherLayout()
        }
        return layout
    }

    func save(_ layout: LauncherLayout) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.prettyPrinted.encode(layout)
        try data.write(to: fileURL, options: .atomic)
    }
}

private extension JSONEncoder {
    static var prettyPrinted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
