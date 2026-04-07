import AppKit

let outputPath = CommandLine.arguments.dropFirst().first ?? "MenuBarIconTemplate.png"

let claudeLines = [
    " ▐▛███▜▌ ",
    "▝▜█████▛▘",
    "  ▘▘ ▝▝  ",
]

func drawClaudeGlyph(
    char: Character,
    row: Int,
    col: Int,
    cellWidth: CGFloat,
    cellHeight: CGFloat,
    origin: CGPoint,
    color: NSColor,
    attributes: [NSAttributedString.Key: Any]
) {
    let x = origin.x + CGFloat(col) * cellWidth
    let y = origin.y + CGFloat(claudeLines.count - row - 1) * cellHeight

    if char == "▘" || char == "▝" {
        let eyeWidth = cellWidth * 0.72
        let eyeHeight = cellHeight * 0.76
        let eyeX = x + (cellWidth - eyeWidth) / 2
        let eyeY = y + cellHeight * 0.08
        let eyeRect = NSRect(x: eyeX, y: eyeY, width: eyeWidth, height: eyeHeight)
        let eyePath = NSBezierPath(roundedRect: eyeRect, xRadius: eyeWidth * 0.18, yRadius: eyeWidth * 0.18)
        color.setFill()
        eyePath.fill()
        return
    }

    let glyph = String(char) as NSString
    let glyphSize = glyph.size(withAttributes: attributes)
    let glyphX = x + (cellWidth - glyphSize.width) / 2
    glyph.draw(at: CGPoint(x: glyphX, y: y), withAttributes: attributes)
}

let canvas = CGSize(width: 72, height: 72)
let image = NSImage(size: canvas)

image.lockFocus()
NSColor.clear.setFill()
NSRect(origin: .zero, size: canvas).fill()

let font = NSFont(name: "Menlo-Bold", size: 19)
    ?? NSFont.monospacedSystemFont(ofSize: 19, weight: .bold)
let cellWidth = ("█" as NSString).size(withAttributes: [.font: font]).width * 0.76
let cellHeight = (font.ascender - font.descender) * 0.84
let maxColumns = claudeLines.map { Array($0).count }.max() ?? 1
let artWidth = CGFloat(maxColumns) * cellWidth
let artHeight = CGFloat(claudeLines.count) * cellHeight
let origin = CGPoint(
    x: floor((canvas.width - artWidth) / 2),
    y: floor((canvas.height - artHeight) / 2) - 1
)

let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.black,
]

for (row, line) in claudeLines.enumerated() {
    for (column, character) in Array(line).enumerated() {
        if character == " " { continue }
        drawClaudeGlyph(
            char: character,
            row: row,
            col: column,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            origin: origin,
            color: .black,
            attributes: attributes
        )
    }
}

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Failed to render menu bar icon\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outputPath))
