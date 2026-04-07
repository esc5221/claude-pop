import AppKit
import QuartzCore
import ServiceManagement

// MARK: - Constants

private let kAnimationDuration: TimeInterval = 0.35
private let kWindowWidth: CGFloat = 430
private let kCornerRadius: CGFloat = 16
private let kTopMargin: CGFloat = 8
private let notificationName = Notification.Name("com.mainpy.dev.claude-pop")

private let claudeLines = [
    " ▐▛███▜▌ ",
    "▝▜█████▛▘",
    "  ▘▘ ▝▝  ",
]

private func drawClaudeGlyph(
    char: Character,
    row: Int,
    col: Int,
    cellWidth: CGFloat,
    cellHeight: CGFloat,
    canvasHeight: CGFloat,
    color: NSColor,
    attributes: [NSAttributedString.Key: Any]
) {
    let x = CGFloat(col) * cellWidth
    let y = canvasHeight - CGFloat(row + 1) * cellHeight

    if char == "▘" || char == "▝" {
        let eyeWidth = cellWidth * 0.68
        let eyeHeight = cellHeight * 0.74
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
    glyph.draw(at: NSPoint(x: glyphX, y: y), withAttributes: attributes)
}

private enum Defaults {
    static let titleTemplate = "{project} ✓"
    static let descriptionTemplate = "{response}"
    static let duration: TimeInterval = 3.0
}

private enum DefaultsKey {
    static let titleTemplate = "titleTemplate"
    static let descriptionTemplate = "descriptionTemplate"
    static let duration = "duration"
}

private struct PopPayload {
    let project: String
    let cwd: String?
    let response: String?
    let durationOverride: TimeInterval?
}

private struct RenderedPayload {
    let title: String
    let description: String?
    let duration: TimeInterval
}

private enum LaunchMode {
    case daemon
    case cli(PopPayload)
}

private final class SettingsStore {
    private let defaults = UserDefaults.standard

    var titleTemplate: String {
        get {
            let stored = defaults.string(forKey: DefaultsKey.titleTemplate)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (stored?.isEmpty == false) ? stored! : Defaults.titleTemplate
        }
        set {
            defaults.set(newValue, forKey: DefaultsKey.titleTemplate)
        }
    }

    var descriptionTemplate: String {
        get {
            defaults.string(forKey: DefaultsKey.descriptionTemplate) ?? Defaults.descriptionTemplate
        }
        set {
            defaults.set(newValue, forKey: DefaultsKey.descriptionTemplate)
        }
    }

    var duration: TimeInterval {
        get {
            let stored = defaults.double(forKey: DefaultsKey.duration)
            return stored > 0 ? stored : Defaults.duration
        }
        set {
            defaults.set(max(0.5, newValue), forKey: DefaultsKey.duration)
        }
    }

    func reset() {
        defaults.removeObject(forKey: DefaultsKey.titleTemplate)
        defaults.removeObject(forKey: DefaultsKey.descriptionTemplate)
        defaults.removeObject(forKey: DefaultsKey.duration)
    }
}

private func renderTemplate(_ template: String, payload: PopPayload) -> String {
    let replacementMap: [String: String] = [
        "{project}": payload.project,
        "{cwd}": payload.cwd ?? "",
        "{response}": payload.response ?? "",
    ]

    var rendered = template
    for (token, value) in replacementMap {
        rendered = rendered.replacingOccurrences(of: token, with: value)
    }
    return rendered.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func renderPayload(_ payload: PopPayload, settings: SettingsStore) -> RenderedPayload {
    let renderedTitle = renderTemplate(settings.titleTemplate, payload: payload)
    let renderedDescription = renderTemplate(settings.descriptionTemplate, payload: payload)

    return RenderedPayload(
        title: renderedTitle.isEmpty ? payload.project : renderedTitle,
        description: renderedDescription.isEmpty ? nil : renderedDescription,
        duration: payload.durationOverride ?? settings.duration
    )
}

private func renderClaudeArt(fontSize: CGFloat) -> NSImage {
    let font = NSFont(name: "Menlo-Bold", size: fontSize)
        ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
    let cellW = ("█" as NSString).size(withAttributes: [.font: font]).width * 0.76
    let cellH = (font.ascender - font.descender) * 0.82
    let maxCols = claudeLines.map({ Array($0).count }).max() ?? 1
    let imgW = CGFloat(maxCols) * cellW
    let imgH = CGFloat(claudeLines.count) * cellH

    let image = NSImage(size: NSSize(width: imgW, height: imgH))
    image.lockFocus()

    let color = NSColor(calibratedRed: 0.85, green: 0.55, blue: 0.35, alpha: 1.0)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]

    for (row, line) in claudeLines.enumerated() {
        for (col, char) in Array(line).enumerated() {
            if char == " " { continue }
            drawClaudeGlyph(
                char: char,
                row: row,
                col: col,
                cellWidth: cellW,
                cellHeight: cellH,
                canvasHeight: imgH,
                color: color,
                attributes: attrs
            )
        }
    }

    image.unlockFocus()
    return image
}

private func loadMenuBarImage() -> NSImage? {
    guard let url = Bundle.main.url(forResource: "MenuBarIconTemplate", withExtension: "png"),
          let image = NSImage(contentsOf: url) else {
        return nil
    }
    image.isTemplate = true
    image.size = NSSize(width: 18, height: 18)
    return image
}

// MARK: - Pop Window

private final class PopWindow: NSPanel {
    private(set) var targetY: CGFloat = 0
    private(set) var actualHeight: CGFloat = 80

    init(title: String, description: String?, screen: NSScreen) {
        let hasDescription = description != nil && !(description?.isEmpty ?? true)
        let windowHeight: CGFloat = hasDescription ? 102 : 76

        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - kWindowWidth / 2
        let yVisible = screenFrame.maxY - windowHeight - kTopMargin
        let yHidden = screenFrame.maxY + 10

        super.init(
            contentRect: NSRect(x: x, y: yHidden, width: kWindowWidth, height: windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        animationBehavior = .none
        actualHeight = windowHeight

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: kWindowWidth, height: windowHeight))

        let vibrancy = NSVisualEffectView(frame: contentView.bounds)
        vibrancy.autoresizingMask = [.width, .height]
        vibrancy.material = .hudWindow
        vibrancy.state = .active
        vibrancy.blendingMode = .behindWindow
        vibrancy.wantsLayer = true
        vibrancy.layer?.cornerRadius = kCornerRadius
        vibrancy.layer?.masksToBounds = true
        contentView.addSubview(vibrancy)

        let borderLayer = CALayer()
        borderLayer.frame = contentView.bounds
        borderLayer.cornerRadius = kCornerRadius
        borderLayer.borderWidth = 0.5
        borderLayer.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        vibrancy.layer?.addSublayer(borderLayer)

        let charImage = renderClaudeArt(fontSize: 16)
        let charView = NSImageView(frame: NSRect(
            x: 16,
            y: (windowHeight - charImage.size.height) / 2,
            width: charImage.size.width,
            height: charImage.size.height
        ))
        charView.image = charImage
        charView.imageScaling = .scaleNone
        contentView.addSubview(charView)

        let textX = charView.frame.maxX + 14
        let textWidth = kWindowWidth - textX - 16

        if hasDescription, let description {
            let titleLabel = NSTextField(labelWithString: title)
            titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
            titleLabel.textColor = .labelColor
            titleLabel.alignment = .left
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.maximumNumberOfLines = 1
            titleLabel.frame = NSRect(x: textX, y: windowHeight - 36, width: textWidth, height: 18)
            contentView.addSubview(titleLabel)

            let descriptionLabel = NSTextField(wrappingLabelWithString: description)
            descriptionLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
            descriptionLabel.textColor = .secondaryLabelColor
            descriptionLabel.alignment = .left
            descriptionLabel.maximumNumberOfLines = 2
            descriptionLabel.lineBreakMode = .byTruncatingTail
            descriptionLabel.frame = NSRect(x: textX, y: 9, width: textWidth, height: 38)
            contentView.addSubview(descriptionLabel)
        } else {
            let titleLabel = NSTextField(labelWithString: title)
            titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
            titleLabel.textColor = .labelColor
            titleLabel.alignment = .left
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.maximumNumberOfLines = 2
            titleLabel.frame = NSRect(x: textX, y: (windowHeight - 34) / 2, width: textWidth, height: 34)
            contentView.addSubview(titleLabel)
        }

        self.contentView = contentView
        targetY = yVisible
    }

    func showAnimated(duration: TimeInterval, completion: @escaping () -> Void) {
        orderFrontRegardless()
        alphaValue = 0

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = kAnimationDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().setFrame(
                NSRect(x: frame.origin.x, y: targetY, width: kWindowWidth, height: actualHeight),
                display: true
            )
            animator().alphaValue = 1.0
        }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = kAnimationDuration
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    self.animator().alphaValue = 0
                }) {
                    self.orderOut(nil)
                    completion()
                }
            }
        }
    }
}

// MARK: - Status Bar

private final class StatusBarController: NSObject, NSMenuDelegate {
    private let settings: SettingsStore
    private let showPreview: () -> Void
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()

    init(settings: SettingsStore, showPreview: @escaping () -> Void) {
        self.settings = settings
        self.showPreview = showPreview
        super.init()
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            if let image = loadMenuBarImage() {
                button.image = image
                button.imagePosition = .imageOnly
            } else {
                button.title = "◆"
                button.font = NSFont.systemFont(ofSize: 13, weight: .bold)
            }
        }
        menu.delegate = self
        statusItem?.menu = menu
        rebuildMenu()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    func rebuildMenu() {
        menu.removeAllItems()

        let header = NSMenuItem(title: "claude-pop", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let titleItem = NSMenuItem(
            title: "Title Template: \(settings.titleTemplate)",
            action: #selector(editTitleTemplate),
            keyEquivalent: ""
        )
        titleItem.target = self
        menu.addItem(titleItem)

        let descriptionValue = settings.descriptionTemplate.isEmpty ? "(hidden)" : settings.descriptionTemplate
        let descriptionItem = NSMenuItem(
            title: "Description Template: \(descriptionValue)",
            action: #selector(editDescriptionTemplate),
            keyEquivalent: ""
        )
        descriptionItem.target = self
        menu.addItem(descriptionItem)

        let durationItem = NSMenuItem(
            title: String(format: "Duration: %.1fs", settings.duration),
            action: #selector(editDuration),
            keyEquivalent: ""
        )
        durationItem.target = self
        menu.addItem(durationItem)

        menu.addItem(.separator())

        let previewItem = NSMenuItem(title: "Test Notification", action: #selector(runPreview), keyEquivalent: "t")
        previewItem.target = self
        menu.addItem(previewItem)

        let resetItem = NSMenuItem(title: "Reset to Defaults", action: #selector(resetDefaults), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(.separator())

        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = LaunchAtLoginManager.isEnabled ? .on : .off
        menu.addItem(launchItem)

        let githubItem = NSMenuItem(title: "Star on GitHub", action: #selector(openGitHub), keyEquivalent: "")
        githubItem.target = self
        menu.addItem(githubItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    @objc private func editTitleTemplate() {
        let value = prompt(
            title: "Title Template",
            message: "Use {project}, {cwd}, {response}. Example: {project} ✓",
            defaultValue: settings.titleTemplate
        )
        guard let value else { return }
        settings.titleTemplate = value.isEmpty ? Defaults.titleTemplate : value
        rebuildMenu()
    }

    @objc private func editDescriptionTemplate() {
        let value = prompt(
            title: "Description Template",
            message: "Use {project}, {cwd}, {response}. Leave empty to hide it.",
            defaultValue: settings.descriptionTemplate
        )
        guard let value else { return }
        settings.descriptionTemplate = value
        rebuildMenu()
    }

    @objc private func editDuration() {
        guard let value = prompt(
            title: "Duration",
            message: "Enter display duration in seconds.",
            defaultValue: String(format: "%.1f", settings.duration)
        ) else {
            return
        }

        guard let seconds = Double(value), seconds > 0 else {
            showInfo(title: "Invalid Duration", message: "Please enter a number greater than zero.")
            return
        }

        settings.duration = seconds
        rebuildMenu()
    }

    @objc private func runPreview() {
        showPreview()
    }

    @objc private func resetDefaults() {
        settings.reset()
        rebuildMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if LaunchAtLoginManager.isEnabled {
                try LaunchAtLoginManager.disable()
            } else {
                try LaunchAtLoginManager.enable()
            }
            rebuildMenu()
        } catch {
            showInfo(title: "Launch at Login", message: error.localizedDescription)
        }
    }

    @objc private func openGitHub() {
        guard let url = URL(string: "https://github.com/esc5221/claude-pop") else { return }
        NSWorkspace.shared.open(url)
    }

    private func prompt(title: String, message: String, defaultValue: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        input.stringValue = defaultValue
        alert.accessoryView = input

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        return input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func showInfo(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

// MARK: - Launch at Login

@available(macOS 13.0, *)
private enum ModernLaunchAtLoginManager {
    static var service: SMAppService { .mainApp }

    static var isEnabled: Bool {
        service.status == .enabled
    }

    static func enable() throws {
        try service.register()
    }

    static func disable() throws {
        try service.unregister()
    }
}

private enum LaunchAtLoginManager {
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return ModernLaunchAtLoginManager.isEnabled
        }
        return false
    }

    static func enable() throws {
        if #available(macOS 13.0, *) {
            try ModernLaunchAtLoginManager.enable()
        }
    }

    static func disable() throws {
        if #available(macOS 13.0, *) {
            try ModernLaunchAtLoginManager.disable()
        }
    }
}

// MARK: - App Delegate

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private lazy var statusBar = StatusBarController(settings: settings) { [weak self] in
        self?.showPreview()
    }

    private var observer: NSObjectProtocol?
    private var queue: [PopPayload] = []
    private var activeWindow: PopWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar.setup()
        startObservingNotifications()
    }

    private func startObservingNotifications() {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: notificationName,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleNotification(notification)
        }
    }

    private func handleNotification(_ notification: Notification) {
        let userInfo = notification.userInfo ?? [:]
        guard let project = userInfo["project"] as? String, !project.isEmpty else { return }
        let cwd = userInfo["cwd"] as? String
        let response = userInfo["response"] as? String
        let duration = userInfo["duration"] as? Double
        enqueue(PopPayload(project: project, cwd: cwd, response: response, durationOverride: duration))
    }

    private func enqueue(_ payload: PopPayload) {
        queue.append(payload)
        showNextIfNeeded()
    }

    private func showNextIfNeeded() {
        guard activeWindow == nil, !queue.isEmpty else { return }
        let payload = queue.removeFirst()
        let rendered = renderPayload(payload, settings: settings)
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let window = PopWindow(title: rendered.title, description: rendered.description, screen: screen)
        activeWindow = window
        window.showAnimated(duration: rendered.duration) { [weak self] in
            self?.activeWindow = nil
            self?.showNextIfNeeded()
        }
    }

    private func showPreview() {
        enqueue(
            PopPayload(
                project: "claude-pop",
                cwd: "/Users/lullu/mainpy/claude-pop",
                response: "Response preview from /Users/lullu/mainpy/claude-pop",
                durationOverride: nil
            )
        )
    }
}

// MARK: - CLI

private func printUsage() {
    let usage = """
    claude-pop — Claude Code completion overlay for macOS

    Usage:
      claude-pop --project "name" [--cwd "path"] [--response "text"] [--duration 3]
      claude-pop --daemon
      claude-pop --help
    """
    print(usage)
}

private func parseArguments() -> LaunchMode? {
    let args = CommandLine.arguments.dropFirst()
    var project: String?
    var cwd: String?
    var response: String?
    var duration: TimeInterval?
    var isDaemon = false

    if args.isEmpty {
        return .daemon
    }

    var iterator = args.makeIterator()
    while let arg = iterator.next() {
        switch arg {
        case "--help", "-h":
            printUsage()
            return nil
        case "--daemon":
            isDaemon = true
        case "--project":
            project = iterator.next()
        case "--cwd":
            cwd = iterator.next()
        case "--response":
            response = iterator.next()
        case "--duration", "-d":
            if let value = iterator.next(), let seconds = Double(value) {
                duration = seconds
            }
        default:
            break
        }
    }

    if isDaemon {
        return .daemon
    }

    guard let project, !project.isEmpty else {
        printUsage()
        exit(1)
    }

    return .cli(PopPayload(project: project, cwd: cwd, response: response, durationOverride: duration))
}

private func sendDistributedNotification(payload: PopPayload) {
    var userInfo: [String: Any] = ["project": payload.project]
    if let cwd = payload.cwd {
        userInfo["cwd"] = cwd
    }
    if let response = payload.response {
        userInfo["response"] = response
    }
    if let duration = payload.durationOverride {
        userInfo["duration"] = duration
    }

    DistributedNotificationCenter.default().postNotificationName(
        notificationName,
        object: nil,
        userInfo: userInfo,
        options: [.deliverImmediately]
    )
}

// MARK: - Main

guard let launchMode = parseArguments() else {
    exit(0)
}

switch launchMode {
case .cli(let payload):
    sendDistributedNotification(payload: payload)
    exit(0)
case .daemon:
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
