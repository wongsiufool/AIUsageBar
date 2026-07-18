import Foundation

/// Codex 用量：~/.codex/auth.json token → chatgpt.com/backend-api/wham/usage
/// 与 Codex CLI /status 显示的 rate limit 数据一致。
enum CodexProvider {
    static var authURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/auth.json")
    }

    static func readAuth() throws -> (token: String, accountID: String) {
        guard let data = try? Data(contentsOf: authURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any],
              let token = tokens["access_token"] as? String,
              let account = tokens["account_id"] as? String
        else {
            throw UsageError.noCredentials("未找到 Codex 登录凭证（~/.codex/auth.json）")
        }
        return (token, account)
    }

    static func fetch() async throws -> ProviderUsage {
        let (token, account) = try readAuth()
        var req = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(account, forHTTPHeaderField: "chatgpt-account-id")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw UsageError.badResponse }
        guard http.statusCode == 200 else { throw UsageError.http(http.statusCode) }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rateLimit = json["rate_limit"] as? [String: Any]
        else { throw UsageError.badResponse }

        var windows: [UsageWindow] = []
        func window(_ key: String) {
            guard let w = rateLimit[key] as? [String: Any],
                  let pct = w["used_percent"] as? Double,
                  let windowSeconds = w["limit_window_seconds"] as? Int else { return }
            let resets: Date?
            if let ts = w["reset_at"] as? Double {
                resets = Date(timeIntervalSince1970: ts)
            } else if let after = w["reset_after_seconds"] as? Double {
                resets = Date().addingTimeInterval(after)
            } else {
                resets = nil
            }
            windows.append(UsageWindow(
                id: key,
                label: Formatters.windowLabel(seconds: windowSeconds),
                percent: pct,
                resetsAt: resets,
                isSession: windowSeconds < 21600
            ))
        }
        window("primary_window")
        window("secondary_window")

        guard !windows.isEmpty else { throw UsageError.badResponse }
        let plan = (json["plan_type"] as? String).map { "Codex \($0.capitalized)" }
        return ProviderUsage(windows: windows, planNote: plan, fetchedAt: Date())
    }
}
