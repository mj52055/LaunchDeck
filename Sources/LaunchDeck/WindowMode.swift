import Foundation

enum WindowMode: String, CaseIterable, Identifiable {
    case launcher
    case standard

    static let storageKey = "windowMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .launcher: "启动台模式"
        case .standard: "标准窗口模式"
        }
    }

    var detail: String {
        switch self {
        case .launcher:
            "无边框全屏覆盖，点击空白或按 Esc 隐藏。"
        case .standard:
            "使用系统红黄绿按钮，可移动、缩放并进入原生全屏。"
        }
    }

    static var current: WindowMode {
        guard let value = UserDefaults.standard.string(forKey: storageKey),
              let mode = WindowMode(rawValue: value) else {
            return .launcher
        }
        return mode
    }
}

extension Notification.Name {
    static let launchDeckWindowModeChanged = Notification.Name("LaunchDeck.windowModeChanged")
}
