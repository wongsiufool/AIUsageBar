import Foundation

/// Claude Code 用量：钥匙串 OAuth token → api.anthropic.com/api/oauth/usage
/// 该接口与 Claude Code 内置 /usage 命令使用同一数据源。
enum ClaudeProvider {
    // User-Agent 必须是 claude-code/<版本>，否则会命中激进限流桶（见 anthropics/claude-code#31637）
    static let userAgent = "claude-code/2.1.206"

    static func readAccessToken() throws -> String {
        // 必须经由 /usr/bin/security 读取，不能用 SecItemCopyMatching：
        // 该条目由 Claude Code 通过 security CLI 创建，partition list 仅含 "apple-tool:"，
        // GUI 应用直读会每次强制弹密码授权框（「始终允许」也只按当次构建的 cdhash 放行），
        // 而 security CLI 在条目的 ACL 与 partition list 内，可静默读取。
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        proc.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let stdout = Pipe()
        proc.standardOutput = stdout
        proc.standardError = Pipe()
        guard (try? proc.run()) != nil else {
            throw UsageError.noCredentials("无法调用 security 读取钥匙串")
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0,
              let raw = String(data: data, encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
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
