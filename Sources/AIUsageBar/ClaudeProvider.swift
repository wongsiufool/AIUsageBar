import Foundation
import Security

/// Claude Code 用量：钥匙串 OAuth token → api.anthropic.com/api/oauth/usage
/// 该接口与 Claude Code 内置 /usage 命令使用同一数据源。
enum ClaudeProvider {
    // User-Agent 必须是 claude-code/<版本>，否则会命中激进限流桶（见 anthropics/claude-code#31637）
    static let userAgent = "claude-code/2.1.206"

    static func readAccessToken() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String
        else {
            throw UsageError.noCredentials("未找到 Claude Code 登录凭证（钥匙串）")
        }
        return token
    }

    static func fetch() async throws -> ProviderUsage {
        let token = try readAccessToken()
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw UsageError.badResponse }
        guard http.statusCode == 200 else { throw UsageError.http(http.statusCode) }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError.badResponse
        }

        var windows: [UsageWindow] = []
        func window(_ key: String, label: String, isSession: Bool) {
            guard let w = json[key] as? [String: Any],
                  let pct = w["utilization"] as? Double else { return }
            let resets = (w["resets_at"] as? String).flatMap(Formatters.parseISO)
            windows.append(UsageWindow(id: key, label: label, percent: pct, resetsAt: resets, isSession: isSession))
        }
        window("five_hour", label: "5 小时", isSession: true)
        window("seven_day", label: "每周", isSession: false)
        window("seven_day_opus", label: "每周 Opus", isSession: false)
        window("seven_day_sonnet", label: "每周 Sonnet", isSession: false)

        guard !windows.isEmpty else { throw UsageError.badResponse }
        return ProviderUsage(windows: windows, planNote: nil, fetchedAt: Date())
    }
}
