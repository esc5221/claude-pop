import AppKit

let outputPath = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"

let claudeLines = [
    " ▐▛███▜▌ ",
    "▝▜█████▛▘",
    "  ▘▘ ▝▝  ",
]

func glyphImage(fontSize: CGFloat, color: NSColor, padding: CGFloat) -> NSImage {
    let font = NSFont(name: "Menlo-Bold", size: fontSize)
        ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
    let cellWidth = ("█" as NSString).size(withAttributes: [.font: font]).width * 0.75
    let cellHeight = (font.ascender - font.descender) * 0.82
    let maxColumns = claudeLines.map { Array($0).count }.max() ?? 1
    let width = CGFloat(maxColumns) * cellWidth + padding * 2
    let height = CGFloat(claudeLines.count) * cellHeight + padding * 2

    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
    ]

    for (row, line) in claudeLines.enumerated() {
        for (column, character) in Array(line).enumerated() {
            if character == " " { continue }
            let glyph = String(character) as NSString
            let glyphSize = glyph.size(withAttributes: attributes)
            let x = padding + CGFloat(column) * cellWidth + (cellWidth - glyphSize.width) / 2
            let y = padding + CGFloat(claudeLines.count - row - 1) * cellHeight
            glyph.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
        }
    }

    image.unlockFocus()
    return image
}

func roundedRectPath(in rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

let canvas = CGSize(width: 1024, height: 1024)
let image = NSImage(size: canvas)

image.lockFocus()

let bounds = NSRect(origin: .zero, size: canvas)
let shellRect = bounds.insetBy(dx: 72, dy: 72)
let shellPath = roundedRectPath(in: shellRect, radius: 230)

NSColor(calibratedRed: 0.08, green: 0.075, blue: 0.07, alpha: 1.0).setFill()
shellPath.fill()

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.17, green: 0.13, blue: 0.11, alpha: 1.0),
    NSColor(calibratedRed: 0.10, green: 0.095, blue: 0.09, alpha: 1.0),
])!
gradient.draw(in: shellPath, angle: -90)

let innerRect = shellRect.insetBy(dx: 24, dy: 24)
let innerPath = roundedRectPath(in: innerRect, radius: 196)
NSColor.white.withAlphaComponent(0.05).setStroke()
innerPath.lineWidth = 2
innerPath.stroke()

let plateRect = NSRect(x: 180, y: 220, width: 664, height: 508)
let platePath = roundedRectPath(in: plateRect, radius: 110)
let plateGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.29, green: 0.23, blue: 0.19, alpha: 1.0),
    NSColor(calibratedRed: 0.18, green: 0.15, blue: 0.13, alpha: 1.0),
])!
plateGradient.draw(in: platePath, angle: -90)
NSColor.white.withAlphaComponent(0.08).setStroke()
platePath.lineWidth = 2
platePath.stroke()

let auraRect = NSRect(x: 172, y: 264, width: 680, height: 388)
let auraGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.93, green: 0.62, blue: 0.36, alpha: 0.34),
    NSColor(calibratedRed: 0.93, green: 0.62, blue: 0.36, alpha: 0.0),
])!
auraGradient.draw(in: NSBezierPath(ovalIn: auraRect), relativeCenterPosition: NSPoint(x: 0, y: 0))

let shadow = NSShadow()
shadow.shadowBlurRadius = 38
shadow.shadowOffset = .zero
shadow.shadowColor = NSColor(calibratedRed: 0.98, green: 0.74, blue: 0.52, alpha: 0.34)
shadow.set()

let art = glyphImage(
    fontSize: 168,
    color: NSColor(calibratedRed: 0.98, green: 0.78, blue: 0.57, alpha: 1.0),
    padding: 12
)
let artRect = NSRect(
    x: (canvas.width - art.size.width) / 2,
    y: 392,
    width: art.size.width,
    height: art.size.height
)
art.draw(in: artRect)

let dotColor = NSColor(calibratedRed: 0.98, green: 0.78, blue: 0.57, alpha: 0.75)
dotColor.setFill()
for index in 0..<3 {
    let dotRect = NSRect(x: 428 + CGFloat(index) * 34, y: 278, width: 16, height: 16)
    NSBezierPath(ovalIn: dotRect).fill()
}

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Failed to render icon\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outputPath))
