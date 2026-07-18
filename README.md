# AIUsageBar

macOS 菜单栏工具：实时跟踪 **Claude Code** 和 **Codex** 的用量限额。

菜单栏显示两行迷你进度条（上 Claude、下 Codex，绿→黄→红对应用量水平）；
点击展开面板，显示每个限额窗口的百分比、进度条，以及 **5 小时窗口的秒级重置倒计时**、
周窗口的重置日期。每 60 秒自动刷新，遇 429 限流自动退避（最长 10 分钟）。
面板左下角可勾选**开机自启动**（也可用命令行：`AIUsageBar --register-login` /
`--unregister-login`）。

## 安装

从 [Releases](https://github.com/wongsiufool/AIUsageBar/releases) 下载 DMG，拖入
「应用程序」即可（已签名并通过 Apple 公证，直接打开）。
首次运行会请求读取钥匙串中 Claude Code 的凭证——输入登录密码并点「始终允许」，仅此一次。

## 构建与运行

```bash
./build-app.sh          # 产出 build/AIUsageBar.app
open build/AIUsageBar.app
```

要求 macOS 14+、Xcode 命令行工具。应用为纯菜单栏应用（不占 Dock）。

构建默认用 Developer ID 证书签名（仅维护者持有；签名身份稳定，重新构建不会重复
触发钥匙串授权）。其他环境没有该证书时自动回落 ad-hoc 签名，可正常本地运行，
但每次重新构建后首次启动会重新弹出钥匙串授权对话框——输入登录密码并点击
「始终允许」即可。维护者发版：`./release.sh <版本号>`（构建 → 签名 → DMG →
公证 → 装订 → GitHub Release 一条龙，需先按脚本注释配置一次 notarytool 凭证）。

应用图标由 `swift scripts/generate-icon.swift` 程序化生成（母版 PNG →
iconutil 编译为 `Resources/AppIcon.icns`），改设计后重新生成提交即可。

## 数据来源

| 服务 | 凭证 | 接口 |
|---|---|---|
| Claude Code | 钥匙串条目 `Claude Code-credentials`（Claude Code 自己维护、自动续期） | `GET https://api.anthropic.com/api/oauth/usage`，需要 `anthropic-beta: oauth-2025-04-20` 和 `User-Agent: claude-code/<版本>`（缺 UA 会命中激进限流桶） |
| Codex | `~/.codex/auth.json` 的 `tokens.access_token` / `account_id`（Codex CLI 自己维护） | `GET https://chatgpt.com/backend-api/wham/usage`，需要 `chatgpt-account-id` 头 |

两个接口返回的数据与各自 CLI 内置的 `/usage`、`/status` 命令一致（官方精确百分比 +
重置时间戳），接口本身未公开文档化，字段变动时需在 Provider 中适配。
Codex 的窗口按 `limit_window_seconds` 动态归类（<6h → "5 小时"，其余 → "每日"/"每周"），
Anthropic 侧解析 `five_hour` / `seven_day` / `seven_day_opus` / `seven_day_sonnet` 字段。

登录过期时面板会提示"请在 CLI 中使用一次以刷新"——在对应 CLI 里跑一条命令即可，
本应用不做任何 OAuth 刷新，也从不写入凭证。

## 代码结构

```
Sources/AIUsageBar/
  AIUsageBarApp.swift   # 入口；NSStatusItem + NSPopover（注意：不能用 MenuBarExtra，
                        #   它会把 label 图标强制单色模板渲染，彩色进度条会被抹掉）
  StatusIcon.swift      # 菜单栏双条图标绘制（drawingHandler 随深浅色自适应）
  UsageStore.swift      # 轮询调度、429 退避、状态发布
  ClaudeProvider.swift  # 钥匙串读取 + Anthropic usage 接口
  CodexProvider.swift   # auth.json 读取 + ChatGPT usage 接口
  MenuView.swift        # 弹出面板（SwiftUI），TimelineView 驱动秒级倒计时
  Models.swift          # UsageWindow / ProviderUsage / 格式化工具
```

参考项目：[CodexBar](https://github.com/steipete/codexbar)（MIT）、
[Usage4Claude](https://github.com/f-is-h/Usage4Claude)（MIT）。
