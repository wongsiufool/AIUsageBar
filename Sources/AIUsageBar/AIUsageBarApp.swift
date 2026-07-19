import SwiftUI
import Combine
import ServiceManagement

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
    private var lastRendered: (top: Double?, bottom: Double?, isDark: Bool)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 命令行开关：注册/注销开机自启后退出（便于脚本化，不进入常驻模式）
        if CommandLine.arguments.contains("--register-login") {
            do { try SMAppService.mainApp.register(); print("login item: registered") }
            catch { print("login item register failed: \(error)") }
            exit(0)
        }
        if CommandLine.arguments.contains("--unregister-login") {
            do { try SMAppService.mainApp.unregister(); print("login item: unregistered") }
            catch { print("login item unregister failed: \(error)") }
            exit(0)
        }

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
        let top = store.claudeSessionPercent
        let bottom = store.codexSessionPercent

        // 内容没变时绝不能重设 image：赋新图会标脏状态栏，触发系统 replicant 快照，
        // 快照过程又会改动 effectiveAppearance 触发上面的 KVO 再进本方法，
        // 形成主线程 100% CPU 的死循环（macOS 26 实测）。
        if let last = lastRendered,
           last.top == top, last.bottom == bottom, last.isDark == isDark {
            return
        }
        lastRendered = (top, bottom, isDark)

        button.image = StatusIcon.image(top: top, bottom: bottom, isDark: isDark)
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
