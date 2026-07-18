import SwiftUI
import Combine

// MenuBarExtra 会将 label 强制按模板（单色）渲染，彩色进度条会被抹掉，
// 因此改用 NSStatusItem + NSPopover。
@main
struct AIUsageBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = UsageStore()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var cancellable: AnyCancellable?
    private var appearanceObservation: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)

        popover.contentViewController = NSHostingController(rootView: MenuView(store: store))
        popover.behavior = .transient

        // objectWillChange 在赋值前触发，异步一拍后再读取新值刷新图标
        cancellable = store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updateIcon() }
            }

        // 菜单栏深浅色随壁纸/系统外观变化时重绘（非模板图不会被系统自动反色）
        appearanceObservation = statusItem.button?.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in self?.updateIcon() }
        }

        updateIcon()
        store.start()
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let isDark = button.effectiveAppearance
            .bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        button.image = StatusIcon.image(
            top: store.claudeSessionPercent,
            bottom: store.codexSessionPercent,
            isDark: isDark
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
