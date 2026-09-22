import Foundation
import Testing
@testable import LaunchDeck

struct LayoutRepositoryTests {
    @Test func savesAndLoadsLayout() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = LayoutRepository(
            fileURL: directory.appendingPathComponent("layout.json")
        )
        let expected = LauncherLayout(
            orderedApplicationIDs: ["app.three", "app.one", "app.two"],
            hiddenApplicationIDs: ["app.two"]
        )

        try repository.save(expected)
        let loaded = repository.load()

        #expect(loaded == expected)
    }

    @Test func missingFileReturnsEmptyLayout() {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("layout.json")

        let layout = LayoutRepository(fileURL: missingURL).load()

        #expect(layout.orderedApplicationIDs.isEmpty)
        #expect(layout.hiddenApplicationIDs.isEmpty)
    }
}
