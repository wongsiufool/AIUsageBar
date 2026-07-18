import SwiftUI

struct MenuView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ProviderSection(name: "Claude Code", icon: "asterisk.circle.fill", tint: .orange, state: store.claude)
            Divider()
            ProviderSection(name: "Codex", icon: "chevron.left.forwardslash.chevron.right", tint: .teal, state: store.codex)
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 300)
    }

    private var footer: some View {
        HStack {
            if let t = store.lastRefresh {
                Text("更新于 \(t.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("立即刷新")
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("退出")
        }
    }
}

private struct ProviderSection: View {
    let name: String
    let icon: String
    let tint: Color
    let state: ProviderState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(name).font(.headline)
                Spacer()
                if let note = state.usage?.planNote {
                    Text(note).font(.caption2).foregroundStyle(.secondary)
                }
            }
            switch state {
            case .loading:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("加载中…").font(.caption).foregroundStyle(.secondary)
                }
            case .error(let msg):
                Label(msg, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            case .ok(let usage):
                ForEach(usage.windows) { w in
                    WindowRow(window: w)
                }
            }
        }
    }
}

private struct WindowRow: View {
    let window: UsageWindow

    private var barColor: Color {
        switch window.percent {
        case ..<60: return .green
        case ..<85: return .yellow
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(window.label).font(.subheadline)
                Spacer()
                Text("\(Int(window.percent.rounded()))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(barColor)
            }
            ProgressView(value: min(window.percent, 100), total: 100)
                .tint(barColor)
                .controlSize(.small)
            if let resetsAt = window.resetsAt {
                // 会话窗显示秒级实时倒计时；长窗口显示重置日期
                TimelineView(.periodic(from: .now, by: window.isSession ? 1 : 60)) { _ in
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        if window.isSession {
                            Text("重置倒计时 \(Formatters.countdown(max(0, resetsAt.timeIntervalSinceNow)))")
                                .monospacedDigit()
                        } else {
                            Text("重置于 \(resetsAt.formatted(.dateTime.month().day().weekday().hour().minute()))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}
