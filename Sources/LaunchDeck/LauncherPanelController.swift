import AppKit
import SwiftUI

@MainActor
final class LauncherPanelController: NSWindowController, NSWindowDelegate {
    let store: ApplicationStore
    private var keyMonitor: Any?
    private var scrollMonitor: Any?
    private var accumulatedHorizontalScroll: CGFloat = 0
    private var changedPageDuringCurrentGesture = false
    private var previousPresentationOptions: NSApplication.PresentationOptions?
    private var standardWindowFrame: NSRect?

    init(store: ApplicationStore) {
        self.store = store

        let rootView = LauncherView(store: store)
        let panel = LauncherWindow(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.contentView = NSHostingView(rootView: rootView)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow
        panel.isReleasedWhenClosed = false

        super.init(window: panel)
        panel.delegate = self

        NotificationCenter.default.addObserver(
            forName: .launchDeckRequestClose,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
        NotificationCenter.default.addObserver(
            forName: .launchDeckWindowModeChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.windowModeDidChange() }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func toggle() {
        window?.isVisible == true ? hide() : show()
    }

    func show() {
        guard let panel = window else { return }
        store.prepareForPresentation()
        let screen = screenContainingMouse() ?? NSScreen.main
        guard let screen else { return }

        applyWindowMode(WindowMode.current, on: screen)
        NSApp.activate(ignoringOtherApps: true)
        if panel.isMiniaturized {
            panel.deminiaturize(nil)
        }
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
        installScrollMonitor()
    }

    func hide() {
        removeKeyMonitor()
        removeScrollMonitor()
        if WindowMode.current == .standard,
           let window,
           !window.styleMask.contains(.fullScreen) {
            standardWindowFrame = window.frame
        }
        restoreSystemPresentation()
        store.query = ""
        window?.orderOut(nil)
        NSApp.hide(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        // Notification Center and other system overlays briefly take key-window
        // status. Keep LaunchDeck visible behind them instead of closing it.
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }

    private func screenContainingMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }

    private func windowModeDidChange() {
        guard let window else { return }

        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(650))
                self?.applyCurrentWindowModeIfVisible()
            }
        } else {
            applyCurrentWindowModeIfVisible()
        }
    }

    private func applyCurrentWindowModeIfVisible() {
        guard let window, window.isVisible,
              let screen = window.screen ?? screenContainingMouse() ?? NSScreen.main else { return }
        applyWindowMode(WindowMode.current, on: screen)
        window.makeKeyAndOrderFront(nil)
    }

    private func applyWindowMode(_ mode: WindowMode, on screen: NSScreen) {
        guard let window else { return }

        switch mode {
        case .launcher:
            if previousPresentationOptions == nil {
                previousPresentationOptions = NSApp.presentationOptions
            }
            NSApp.presentationOptions = [.autoHideDock, .autoHideMenuBar]
            window.styleMask = [.borderless, .fullSizeContentView]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            window.isMovableByWindowBackground = false
            window.setFrame(screen.frame, display: true)

        case .standard:
            restoreSystemPresentation()
            window.styleMask = [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .fullSizeContentView
            ]
            window.title = "LaunchDeck"
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = true
            window.level = .normal
            window.collectionBehavior = [.managed, .fullScreenPrimary]
            window.isMovableByWindowBackground = false

            let visibleFrame = screen.visibleFrame
            let width = min(1_180, visibleFrame.width - 80)
            let height = min(760, visibleFrame.height - 80)
            let defaultFrame = NSRect(
                x: visibleFrame.midX - width / 2,
                y: visibleFrame.midY - height / 2,
                width: width,
                height: height
            )
            window.setFrame(standardWindowFrame ?? defaultFrame, display: true, animate: true)
        }
    }

    private func restoreSystemPresentation() {
        if let previousPresentationOptions {
            NSApp.presentationOptions = previousPresentationOptions
            self.previousPresentationOptions = nil
        }
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard self.window?.attachedSheet == nil else { return event }

            switch event.keyCode {
            case 123:
                store.moveSelection(horizontal: -1)
            case 124:
                store.moveSelection(horizontal: 1)
            case 125:
                store.moveSelection(vertical: 1)
            case 126:
                store.moveSelection(vertical: -1)
            case 116:
                store.changePage(by: -1)
            case 121:
                store.changePage(by: 1)
            case 36, 76:
                store.launchSelected { [weak self] in self?.hide() }
            case 53:
                if !store.query.isEmpty {
                    store.query = ""
                } else if WindowMode.current == .launcher {
                    hide()
                } else {
                    return event
                }
            default:
                return event
            }
            return nil
        }
    }

    private func removeKeyMonitor() {
        guard let keyMonitor else { return }
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
    }

    private func installScrollMonitor() {
        removeScrollMonitor()
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self,
                  let window = self.window,
                  window.isVisible,
                  event.hasPreciseScrollingDeltas,
                  abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) * 1.6 else {
                return event
            }
            guard event.momentumPhase.isEmpty else { return nil }

            if let contentView = window.contentView,
               event.locationInWindow.x >= contentView.bounds.width - 96 {
                accumulatedHorizontalScroll = 0
                changedPageDuringCurrentGesture = false
                return event
            }

            if event.phase == .began {
                accumulatedHorizontalScroll = 0
                changedPageDuringCurrentGesture = false
            }

            accumulatedHorizontalScroll += event.scrollingDeltaX
            if !changedPageDuringCurrentGesture, abs(accumulatedHorizontalScroll) >= 72 {
                let pageOffset = accumulatedHorizontalScroll < 0 ? 1 : -1
                store.changePage(by: pageOffset)
                changedPageDuringCurrentGesture = true
            }

            if event.phase == .ended || event.phase == .cancelled {
                accumulatedHorizontalScroll = 0
                changedPageDuringCurrentGesture = false
            }
            return changedPageDuringCurrentGesture ? nil : event
        }
    }

    private func removeScrollMonitor() {
        guard let scrollMonitor else { return }
        NSEvent.removeMonitor(scrollMonitor)
        self.scrollMonitor = nil
        accumulatedHorizontalScroll = 0
        changedPageDuringCurrentGesture = false
    }
}

final class LauncherWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

extension Notification.Name {
    static let launchDeckRequestClose = Notification.Name("LaunchDeck.requestClose")
}
