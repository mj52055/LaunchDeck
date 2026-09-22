import Foundation

struct ApplicationScanner: Sendable {
    func scan() -> [ApplicationItem] {
        let fileManager = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true)
        ]

        var applicationsByID: [String: ApplicationItem] = [:]

        for root in roots where fileManager.fileExists(atPath: root.path) {
            for applicationURL in applicationURLs(below: root) {
                let item = makeItem(from: applicationURL)
                applicationsByID[item.id] = applicationsByID[item.id] ?? item
            }
        }

        return applicationsByID.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private func applicationURLs(below root: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isApplicationKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        return enumerator.compactMap { element in
            guard let url = element as? URL, url.pathExtension.lowercased() == "app" else {
                return nil
            }
            return url
        }
    }

    private func makeItem(from url: URL) -> ApplicationItem {
        let bundle = Bundle(url: url)
        let displayName = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let bundleIdentifier = bundle?.bundleIdentifier
        let identifier = bundleIdentifier ?? url.standardizedFileURL.path

        return ApplicationItem(
            id: identifier,
            name: displayName,
            bundleIdentifier: bundleIdentifier,
            url: url
        )
    }
}
