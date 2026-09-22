import Foundation
import Testing
@testable import LaunchDeck

struct ApplicationItemTests {
    @Test func searchableTextContainsNameAndBundleIdentifier() {
        let item = ApplicationItem(
            id: "com.example.demo",
            name: "Demo App",
            bundleIdentifier: "com.example.demo",
            url: URL(fileURLWithPath: "/Applications/Demo.app")
        )

        #expect(item.searchableText.contains("demo app"))
        #expect(item.searchableText.contains("com.example.demo"))
    }
}
