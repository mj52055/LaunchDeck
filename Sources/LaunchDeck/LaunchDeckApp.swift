import AppKit
import SwiftUI

@main
struct LaunchDeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: LauncherPanelController?
    private var settingsWindowController: SettingsWindowController?
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let store = ApplicationStore()
        panelController = LauncherPanelController(store: store)
        configureStatusItem()
        store.reload()
        panelController?.show()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        panelController?.show()
        return true
    }

    @objc private func toggleLauncher() {
        panelController?.toggle()
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else {
            toggleLauncher()
            return
        }

        if event.type == .rightMouseUp,
           let button = statusItem?.button,
           let statusMenu {
            statusMenu.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: button.bounds.height + 4),
                in: button
            )
        } else {
            toggleLauncher()
        }
    }

    @objc private func rescanApplications() {
        panelController?.store.reload()
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.present()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "square.grid.3x3.fill",
            accessibilityDescription: "LaunchDeck"
        )
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let menu = NSMenu()
        menu.addItem(withTitle: "打开 LaunchDeck", action: #selector(toggleLauncher), keyEquivalent: "")
        menu.addItem(withTitle: "重新扫描应用", action: #selector(rescanApplications), keyEquivalent: "r")
        menu.addItem(withTitle: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 LaunchDeck", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusMenu = menu
        statusItem = item
    }

}
