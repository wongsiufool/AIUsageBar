import AppKit

/// 菜单栏图标：两行 [标签 + 迷你进度条]（上 = Claude Code 5 小时窗，下 = Codex）
enum StatusIcon {
    private static let barWidth: CGFloat = 30
    private static let barHeight: CGFloat = 5.5
    private static let gap: CGFloat = 4

    /// isDark: 菜单栏当前是否为深色（来自 status button 的 effectiveAppearance）。
    /// 非模板图不会被系统自动反色，文字/底轨颜色必须在这里显式解析。
    static func image(top: Double?, bottom: Double?, isDark: Bool) -> NSImage {
        let font = NSFont.systemFont(ofSize: 7.5, weight: .semibold)
        let textColor: NSColor = isDark ? NSColor.white.withAlphaComponent(0.95)
                                        : NSColor.black.withAlphaComponent(0.85)
        func label(_ s: String) -> NSAttributedString {
            NSAttributedString(string: s, attributes: [
                .font: font,
                .foregroundColor: textColor,
            ])
        }
        let claudeLabel = label("Claude")
        let codexLabel = label("Codex")
        let textWidth = ceil(max(claudeLabel.size().width, codexLabel.size().width))
        let size = NSSize(width: textWidth + gap + barWidth, height: 17)

        let image = NSImage(size: size, flipped: false) { _ in
            let barX = textWidth + gap
            drawRow(label: claudeLabel, textWidth: textWidth, barX: barX, barY: 10, percent: top, isDark: isDark)
            drawRow(label: codexLabel, textWidth: textWidth, barX: barX, barY: 2, percent: bottom, isDark: isDark)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func drawRow(label: NSAttributedString, textWidth: CGFloat,
                                barX: CGFloat, barY: CGFloat, percent: Double?, isDark: Bool) {
        let textSize = label.size()
        let barCenter = barY + barHeight / 2
        label.draw(at: NSPoint(x: textWidth - textSize.width, y: barCenter - textSize.height / 2))
        drawBar(x: barX, y: barY, percent: percent, isDark: isDark)
    }

    private static func drawBar(x: CGFloat, y: CGFloat, percent: Double?, isDark: Bool) {
        let h = barHeight
        let track = NSBezierPath(
            roundedRect: NSRect(x: x, y: y, width: barWidth, height: h),
            xRadius: h / 2, yRadius: h / 2
        )
        (isDark ? NSColor.white.withAlphaComponent(0.28)
                : NSColor.black.withAlphaComponent(0.18)).setFill()
        track.fill()

        guard let percent else { return }
        let fillWidth = max(h, barWidth * min(percent, 100) / 100)
        let color: NSColor = percent < 60 ? .systemGreen : percent < 85 ? .systemYellow : .systemRed
        let fill = NSBezierPath(
            roundedRect: NSRect(x: x, y: y, width: fillWidth, height: h),
            xRadius: h / 2, yRadius: h / 2
        )
        color.setFill()
        fill.fill()
    }
}
