import Foundation
import SwiftUI

@MainActor
final class UsageStore: ObservableObject {
    @Published var claude: ProviderState = .loading
    @Published var codex: ProviderState = .loading
    @Published var lastRefresh: Date?

    static let baseInterval: TimeInterval = 60
    private var interval: TimeInterval = UsageStore.baseInterval
    private var timerTask: Task<Void, Never>?

    func start() {
        guard timerTask == nil else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                let delay = self?.interval ?? UsageStore.baseInterval
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    func refresh() async {
        async let claudeResult = Self.load(ClaudeProvider.fetch)
        async let codexResult = Self.load(CodexProvider.fetch)
        let (c, x) = await (claudeResult, codexResult)

        // 保留上一次成功数据，避免瞬时网络错误导致界面闪空
        if case .error = c, claude.usage != nil {} else { claude = c }
        if case .error = x, codex.usage != nil {} else { codex = x }
        lastRefresh = Date()

        // 命中 429 时退避，最长 10 分钟
        if case .error(let msg) = c, msg.contains("429") {
            interval = min(interval * 2, 600)
        } else {
            interval = Self.baseInterval
        }
    }

    private static func load(_ fetch: () async throws -> ProviderUsage) async -> ProviderState {
        do { return .ok(try await fetch()) }
        catch { return .error(error.localizedDescription) }
    }

    /// 菜单栏双条图标用：nil 表示暂无数据（只画底轨）
    var claudeSessionPercent: Double? { claude.usage?.sessionWindow?.percent }
    var codexSessionPercent: Double? { codex.usage?.sessionWindow?.percent }
}
