// 生成应用图标母版 build/icon_1024.png
// 设计：深色渐变圆角方块 + 两根进度条（上 Claude 珊瑚橙、下 Codex 青绿），呼应菜单栏双条
import AppKit

let canvas: CGFloat = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS 图标网格：824×824 圆角方块居中，圆角约 185
let iconRect = NSRect(x: 100, y: 100, width: 824, height: 824)
let bg = NSBezierPath(roundedRect: iconRect, xRadius: 185, yRadius: 185)
NSGradient(colors: [
    NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.24, alpha: 1),
    NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.12, alpha: 1),
])!.draw(in: bg, angle: -90)

// 顶部高光描边
NSColor.white.withAlphaComponent(0.08).setStroke()
bg.lineWidth = 6
bg.stroke()

func bar(y: CGFloat, fillRatio: CGFloat, color: NSColor) {
    let w: CGFloat = 520, h: CGFloat = 96
    let x = (canvas - w) / 2
    let track = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: h / 2, yRadius: h / 2)
    NSColor.white.withAlphaComponent(0.16).setFill()
    track.fill()
    let fill = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: max(h, w * fillRatio), height: h), xRadius: h / 2, yRadius: h / 2)
    color.setFill()
    fill.fill()
}

// 上：Claude（珊瑚橙，Anthropic 风格），下：Codex（青绿，OpenAI 风格）
bar(y: 548, fillRatio: 0.62, color: NSColor(calibratedRed: 0.85, green: 0.47, blue: 0.34, alpha: 1))
bar(y: 380, fillRatio: 0.36, color: NSColor(calibratedRed: 0.06, green: 0.64, blue: 0.50, alpha: 1))

NSGraphicsContext.restoreGraphicsState()

let out = URL(fileURLWithPath: "build/icon_1024.png")
try! FileManager.default.createDirectory(atPath: "build", withIntermediateDirectories: true)
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("written: \(out.path)")
