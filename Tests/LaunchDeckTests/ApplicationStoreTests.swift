import Foundation
import Testing
@testable import LaunchDeck

@MainActor
struct ApplicationStoreTests {
    @Test func paginatesAndNavigatesAcrossPages() {
        let store = makeStore(applicationCount: 36)

        #expect(store.pageCount == 2)
        #expect(store.pageApplications.count == 35)

        store.changePage(by: 1)

        #expect(store.currentPage == 1)
        #expect(store.pageApplications.count == 1)
        #expect(store.selectedApplicationID == "app.35")
        #expect(store.pageTransitionDirection == 1)

        store.changePage(by: -1)

        #expect(store.currentPage == 0)
        #expect(store.pageTransitionDirection == -1)
    }

    @Test func hidingApplicationPersists() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = LayoutRepository(
            fileURL: directory.appendingPathComponent("layout.json")
        )
        let application = makeApplication(index: 0)
        let store = ApplicationStore(
            layoutRepository: repository,
            initialApplications: [application]
        )

        store.hide(application)

        #expect(store.visibleApplications.isEmpty)
        #expect(repository.load().hiddenApplicationIDs == [application.id])
    }

    private func makeStore(applicationCount: Int) -> ApplicationStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = LayoutRepository(
            fileURL: directory.appendingPathComponent("layout.json")
        )
        return ApplicationStore(
            layoutRepository: repository,
            initialApplications: (0..<applicationCount).map(makeApplication)
        )
    }

    private func makeApplication(index: Int) -> ApplicationItem {
        ApplicationItem(
            id: "app.\(index)",
            name: "Application \(index)",
            bundleIdentifier: "app.\(index)",
            url: URL(fileURLWithPath: "/Applications/Application\(index).app")
        )
    }
}
