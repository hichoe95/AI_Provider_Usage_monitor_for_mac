import AppKit
import UsageMonitorCore

enum BrandColor {
    static let claude = NSColor(red: 0.87, green: 0.45, blue: 0.34, alpha: 1)       // #DE7356
    static let codex = NSColor(red: 0.0, green: 0.65, blue: 0.49, alpha: 1)         // #00A67E
    static let copilot = NSColor(red: 0.18, green: 0.63, blue: 0.97, alpha: 1)      // #2DA0F7
    static let gemini = NSColor(red: 0.30, green: 0.42, blue: 0.95, alpha: 1)       // #4D6BF3
    static let openRouter = NSColor(red: 0.39, green: 0.40, blue: 0.95, alpha: 1)   // #6366F1
    static let openRouterStrong = NSColor(red: 0.06, green: 0.50, blue: 0.95, alpha: 1)
}

enum ProviderLogo {
    static func load(_ name: String) -> NSImage? {
        let candidates = ["png", "pdf", "jpg", "jpeg"]
        for ext in candidates {
            if let url = Bundle.module.url(forResource: name, withExtension: ext),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }
    static var claude: NSImage? { load("claude_logo") }
    static var codex: NSImage? { load("codex_logo") }
    static var copilot: NSImage? { load("copilot_logo") }
    static var gemini: NSImage? { load("gemini_logo") }
    static var openRouter: NSImage? { load("openrouter_logo") ?? load("openrouter") }
}

enum MenuBuilder {
    private static let menuWidth: CGFloat = 300

    @MainActor
    static func buildMenu(
        claudeData: UsageData?,
        codexData: UsageData?,
        copilotData: UsageData?,
        geminiData: UsageData?,
        openRouterData: UsageData?,
        isLoading: Bool,
        providerErrors: [String: String],
        onRefresh: @escaping () -> Void,
        onSettings: @escaping () -> Void
    ) -> NSMenu {
        let menu = NSMenu()

        func isProviderEnabled(_ key: String, default defaultValue: Bool) -> Bool {
            guard UserDefaults.standard.object(forKey: key) != nil else {
                return defaultValue
            }
            return UserDefaults.standard.bool(forKey: key)
        }

        let claudeEnabled = isProviderEnabled("claudeEnabled", default: true)
        let codexEnabled = isProviderEnabled("codexEnabled", default: true)
        let copilotEnabled = isProviderEnabled("copilotEnabled", default: false)
        let geminiEnabled = isProviderEnabled("geminiEnabled", default: false)
        let openRouterEnabled = isProviderEnabled("openRouterEnabled", default: false)

        if isLoading {
            let item = NSMenuItem(title: "Refreshing...", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            menu.addItem(NSMenuItem.separator())
        }

        var hasProviderSection = false

        if claudeEnabled {
            addGaugeItem(to: menu, name: "Claude", logo: ProviderLogo.claude, color: BrandColor.claude,
                         data: claudeData, error: providerErrors["Claude Code"])
            hasProviderSection = true
        }

        if codexEnabled {
            if hasProviderSection { menu.addItem(NSMenuItem.separator()) }
            addGaugeItem(to: menu, name: "Codex", logo: ProviderLogo.codex, color: BrandColor.codex,
                         data: codexData, error: providerErrors["Codex"])
            hasProviderSection = true
        }

        if copilotEnabled {
            if hasProviderSection { menu.addItem(NSMenuItem.separator()) }
            addGaugeItem(to: menu, name: "Copilot", logo: ProviderLogo.copilot, color: BrandColor.copilot,
                         data: copilotData, error: providerErrors["Copilot"])
            hasProviderSection = true
        }

        if geminiEnabled {
            if hasProviderSection { menu.addItem(NSMenuItem.separator()) }
            addGaugeItem(to: menu, name: "Gemini", logo: ProviderLogo.gemini, color: BrandColor.gemini,
                         data: geminiData, error: providerErrors["Gemini"])
            hasProviderSection = true
        }

        if openRouterEnabled {
            if hasProviderSection { menu.addItem(NSMenuItem.separator()) }
            addOpenRouterItem(to: menu, data: openRouterData, error: providerErrors["OpenRouter"])
            hasProviderSection = true
        }

        if !hasProviderSection {
            let item = NSMenuItem(title: "No providers enabled", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(MenuActionHandler.handleRefresh), keyEquivalent: "r")
        refreshItem.target = MenuActionHandler.shared
        refreshItem.representedObject = onRefresh
        menu.addItem(refreshItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(MenuActionHandler.openSettings), keyEquivalent: ",")
        settingsItem.target = MenuActionHandler.shared
        settingsItem.representedObject = onSettings
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
    }

    @MainActor
    private static func addGaugeItem(to menu: NSMenu, name: String, logo: NSImage?, color: NSColor,
                                     data: UsageData?, error: String?) {
        let item = NSMenuItem()
        item.view = ProviderGaugeView(name: name, logo: logo, color: color,
                                      sessionUsage: data?.sessionUsage, weeklyUsage: data?.weeklyUsage,
                                      error: error, width: menuWidth)
        menu.addItem(item)
    }

    @MainActor
    private static func addOpenRouterItem(to menu: NSMenu, data: UsageData?, error: String?) {
        let item = NSMenuItem()
        item.view = OpenRouterGaugeView(remainingCredits: data?.remainingCredits,
                                        error: error, width: menuWidth)
        menu.addItem(item)
    }
}

private final class ProviderGaugeView: NSView {
    private let name: String
    private let logo: NSImage?
    private let color: NSColor
    private let sessionUsage: Double?
    private let weeklyUsage: Double?
    private let error: String?

    private let logoSize: CGFloat = 16
    private let pad: CGFloat = 14
    private let barHeight: CGFloat = 5
    private let barRadius: CGFloat = 2.5

    init(name: String, logo: NSImage?, color: NSColor,
         sessionUsage: Double?, weeklyUsage: Double?, error: String?, width: CGFloat) {
        self.name = name
        self.logo = logo
        self.color = color
        self.sessionUsage = sessionUsage
        self.weeklyUsage = weeklyUsage
        self.error = error

        let hasSession = sessionUsage != nil
        let hasWeekly = weeklyUsage != nil
        let rowCount = (hasSession ? 1 : 0) + (hasWeekly ? 1 : 0)
        let height: CGFloat = error != nil ? 52 : (rowCount == 0 ? 36 : CGFloat(20 + rowCount * 16))
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let titleY = bounds.height - 18
        drawLogo(at: NSPoint(x: pad, y: titleY), size: logoSize)

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        NSString(string: name).draw(at: NSPoint(x: pad + logoSize + 6, y: titleY), withAttributes: titleAttrs)

        if let error {
            let errAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.systemOrange,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.lineBreakMode = .byTruncatingTail
                    return style
                }()
            ]
            let message = error.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            let errorRect = NSRect(
                x: pad + logoSize + 6,
                y: 6,
                width: bounds.width - (pad + logoSize + 6) - pad,
                height: max(14, titleY - 8)
            )
            NSString(string: "⚠ \(message)").draw(
                with: errorRect,
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: errAttrs
            )
            return
        }

        let labelWidth: CGFloat = 22
        let pctWidth: CGFloat = 36
        let barX = pad + labelWidth
        let barMaxWidth = bounds.width - barX - pad - pctWidth - 4

        let pctAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        var y = titleY - 18

        if let session = sessionUsage {
            let pct = normalizedPercent(session)
            let sessionLabelAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .bold),
                .foregroundColor: color
            ]
            NSString(string: "5h").draw(at: NSPoint(x: pad, y: y - 1), withAttributes: sessionLabelAttrs)
            drawGaugeBar(at: NSPoint(x: barX, y: y + 1), width: barMaxWidth, height: barHeight,
                         percent: pct, color: color)
            let pctStr = String(format: "%2.0f%%", pct)
            NSString(string: pctStr).draw(at: NSPoint(x: barX + barMaxWidth + 4, y: y - 1), withAttributes: pctAttrs)
            y -= 16
        }

        if let weekly = weeklyUsage {
            let pct = normalizedPercent(weekly)
            let weeklyColor = desaturatedTint(color)
            let weeklyLabelAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: weeklyColor.withAlphaComponent(0.7)
            ]
            NSString(string: "7d").draw(at: NSPoint(x: pad, y: y - 1), withAttributes: weeklyLabelAttrs)
            drawGaugeBar(at: NSPoint(x: barX, y: y + 1), width: barMaxWidth, height: barHeight,
                         percent: pct, color: weeklyColor)
            let pctStr = String(format: "%2.0f%%", pct)
            NSString(string: pctStr).draw(at: NSPoint(x: barX + barMaxWidth + 4, y: y - 1), withAttributes: pctAttrs)
        }

        if sessionUsage == nil && weeklyUsage == nil && error == nil {
            let noData: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.tertiaryLabelColor
            ]
            NSString(string: "No data").draw(at: NSPoint(x: pad + logoSize + 6, y: titleY - 16), withAttributes: noData)
        }
    }

    private func drawLogo(at point: NSPoint, size: CGFloat) {
        if let logo {
            logo.draw(in: NSRect(x: point.x, y: point.y, width: size, height: size))
        } else {
            let rect = NSRect(x: point.x, y: point.y, width: size, height: size)
            let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
            color.withAlphaComponent(0.15).setFill()
            path.fill()
            let initial = String(name.prefix(1))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: color
            ]
            let strSize = (initial as NSString).size(withAttributes: attrs)
            let strX = point.x + (size - strSize.width) / 2
            let strY = point.y + (size - strSize.height) / 2
            NSString(string: initial).draw(at: NSPoint(x: strX, y: strY), withAttributes: attrs)
        }
    }

    private func drawGaugeBar(at origin: NSPoint, width: CGFloat, height: CGFloat,
                              percent: CGFloat, color: NSColor) {
        let bgRect = NSRect(x: origin.x, y: origin.y, width: width, height: height)
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: barRadius, yRadius: barRadius)
        NSColor.quaternaryLabelColor.setFill()
        bgPath.fill()

        let fillWidth = max(0, min(width * percent / 100.0, width))
        if fillWidth > 0 {
            let fillRect = NSRect(x: origin.x, y: origin.y, width: fillWidth, height: height)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: barRadius, yRadius: barRadius)
            gaugeColor(for: percent, brand: color).setFill()
            fillPath.fill()
        }
    }

    private func gaugeColor(for percent: CGFloat, brand: NSColor) -> NSColor {
        if percent > 90 { return NSColor.systemRed }
        if percent > 80 { return NSColor.systemOrange }
        if percent > 60 { return NSColor.systemYellow }
        return brand
    }

    private func desaturatedTint(_ color: NSColor) -> NSColor {
        guard let c = color.usingColorSpace(.deviceRGB) else { return color }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(hue: h, saturation: s * 0.65, brightness: min(b + 0.08, 1.0), alpha: a * 0.85)
    }

    private func normalizedPercent(_ value: Double) -> CGFloat {
        let pct = value < 1 ? value * 100 : value
        return CGFloat(max(0, min(pct, 100)))
    }
}

private final class OpenRouterGaugeView: NSView {
    private let remainingCredits: Double?
    private let error: String?
    private let pad: CGFloat = 14
    private let logoSize: CGFloat = 16

    init(remainingCredits: Double?, error: String?, width: CGFloat) {
        self.remainingCredits = remainingCredits
        self.error = error
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 32))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let titleY = bounds.height - 22

        if let logo = ProviderLogo.openRouter {
            logo.draw(in: NSRect(x: pad, y: titleY + 2, width: logoSize, height: logoSize))
        } else {
            drawOpenRouterFallback(at: NSPoint(x: pad, y: titleY + 2), size: logoSize)
        }

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        NSString(string: "OpenRouter").draw(at: NSPoint(x: pad + logoSize + 6, y: titleY), withAttributes: titleAttrs)

        let valueX = bounds.width - pad - 80

        if error != nil {
            let errAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.systemOrange
            ]
            NSString(string: "⚠ Error").draw(at: NSPoint(x: valueX, y: titleY + 2), withAttributes: errAttrs)
            return
        }

        if let credits = remainingCredits {
            let dollarAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold),
                .foregroundColor: BrandColor.openRouterStrong
            ]
            let dollarStr = String(format: "$%.2f", credits)
            NSString(string: dollarStr).draw(at: NSPoint(x: valueX, y: titleY - 1), withAttributes: dollarAttrs)
        } else {
            let noData: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.tertiaryLabelColor
            ]
            NSString(string: "No data").draw(at: NSPoint(x: valueX, y: titleY), withAttributes: noData)
        }
    }

    private func drawOpenRouterFallback(at point: NSPoint, size: CGFloat) {
        let rect = NSRect(x: point.x, y: point.y, width: size, height: size)
        let bg = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        BrandColor.openRouter.withAlphaComponent(0.15).setFill()
        bg.fill()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: BrandColor.openRouter
        ]
        let label = "OR"
        let sizeText = (label as NSString).size(withAttributes: attrs)
        let textX = point.x + (size - sizeText.width) / 2
        let textY = point.y + (size - sizeText.height) / 2
        NSString(string: label).draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)
    }
}

@MainActor
private final class MenuActionHandler: NSObject {
    static let shared = MenuActionHandler()

    @objc func openSettings(_ sender: NSMenuItem) {
        if let onSettings = sender.representedObject as? (() -> Void) {
            onSettings()
        }
    }

    @objc func handleRefresh(_ sender: NSMenuItem) {
        if let onRefresh = sender.representedObject as? (() -> Void) {
            onRefresh()
        }
    }
}
