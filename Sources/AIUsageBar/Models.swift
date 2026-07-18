import Foundation

/// 一个限额窗口（如 5 小时窗、7 天窗）
struct UsageWindow: Identifiable, Equatable {
    let id: String
    let label: String          // 展示名，如 "5 小时" / "每周"
    let percent: Double        // 已用百分比 0-100
    let resetsAt: Date?        // 重置时间
    let isSession: Bool        // 是否为短周期会话窗（用于菜单栏展示与倒计时）

    var remaining: TimeInterval? {
        guard let resetsAt else { return nil }
        return max(0, resetsAt.timeIntervalSinceNow)
    }
}

struct ProviderUsage: Equatable {
    let windows: [UsageWindow]
    let planNote: String?      // 如 codex 的 plan_type
    let fetchedAt: Date

    var sessionWindow: UsageWindow? { windows.first(where: { $0.isSession }) ?? windows.first }
}

enum ProviderState: Equatable {
    case loading
    case ok(ProviderUsage)
    case error(String)

    var usage: ProviderUsage? {
        if case .ok(let u) = self { return u }
        return nil
    }
}

enum UsageError: LocalizedError {
    case noCredentials(String)
    case http(Int)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .noCredentials(let hint): return hint
        case .http(let code): return code == 401 ? "登录已过期，请在 CLI 中使用一次以刷新" : "HTTP \(code)"
        case .badResponse: return "响应格式无法解析"
        }
    }
}

enum Formatters {
    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static let isoNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parseISO(_ s: String) -> Date? {
        iso.date(from: s) ?? isoNoFraction.date(from: s)
    }

    /// 秒数 → "2时08分" / "3天2时" 之类的紧凑倒计时
    static func countdown(_ t: TimeInterval) -> String {
        let total = Int(t)
        let d = total / 86400, h = (total % 86400) / 3600
        let m = (total % 3600) / 60, s = total % 60
        if d > 0 { return "\(d)天\(h)时\(m)分" }
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    /// 窗口时长 → 标签
    static func windowLabel(seconds: Int) -> String {
        switch seconds {
        case ..<21600: return "5 小时"
        case ..<172800: return "每日"
        default: return "每周"
        }
    }
}
