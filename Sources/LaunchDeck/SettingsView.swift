import AppKit
import SwiftUI

struct SettingsView: View {
    @AppStorage(WindowMode.storageKey) private var windowModeRaw = WindowMode.launcher.rawValue

    private var selectedWindowMode: WindowMode {
        WindowMode(rawValue: windowModeRaw) ?? .launcher
    }

    var body: some View {
        Form {
            Section("启动方式") {
                LabeledContent("打开 LaunchDeck", value: "菜单栏图标")
            }

            Section("窗口模式") {
                Picker("显示方式", selection: $windowModeRaw) {
                    ForEach(WindowMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Text(selectedWindowMode.detail)
                    .foregroundStyle(.secondary)
            }

            Section("关于") {
                LabeledContent("版本", value: "0.5.1")
                Text("当前版本默认扫描系统、全局和用户应用目录。")
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: windowModeRaw) {
            NotificationCenter.default.post(
                name: .launchDeckWindowModeChanged,
                object: nil
            )
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 350)
        .navigationTitle("LaunchDeck 设置")
    }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "LaunchDeck 设置"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}
