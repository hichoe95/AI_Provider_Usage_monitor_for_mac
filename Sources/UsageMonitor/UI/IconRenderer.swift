import AppKit

struct ProviderSegmentData {
    let icon: NSImage?
    let brandColor: NSColor
    let session: Double?
    let weekly: Double?
}

struct OpenRouterSegmentData {
    let icon: NSImage?
    let brandColor: NSColor
    let credits: Double?
}

enum StatusBarIcon {
    static var claude: NSImage? { ProviderLogo.claude }
    static var codex: NSImage? { ProviderLogo.codex }
    static var openRouter: NSImage? { ProviderLogo.openRouter }
    static var copilot: NSImage? { ProviderLogo.copilot }
    static var gemini: NSImage? { ProviderLogo.gemini }
}

@MainActor
enum IconRenderer {
    static func renderProviderIcon(
        sessionUsage: Double?,
        weeklyUsage: Double?,
        isStale: Bool = false
    ) -> NSImage {
        let size = NSSize(width: 24, height: 24)
        let image = NSImage(size: size)

        image.lockFocus()
        let context = NSGraphicsContext.current!.cgContext

        context.setFillColor(NSColor.clear.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        let barHeight: CGFloat = 11
        let barGap: CGFloat = 1
        let barsOriginY = (size.height - (barHeight * 2 + barGap)) / 2
        let fullBarWidth = size.width
        let weeklyTrackRect = CGRect(x: 0, y: barsOriginY, width: fullBarWidth, height: barHeight)
        let sessionTrackRect = CGRect(x: 0, y: barsOriginY + barHeight + barGap, width: fullBarWidth, height: barHeight)

        context.setFillColor(gaugeTrackColor().cgColor)
        fillRoundedRect(weeklyTrackRect, cornerRadius: barHeight / 2, in: context)
        fillRoundedRect(sessionTrackRect, cornerRadius: barHeight / 2, in: context)
        context.setStrokeColor(gaugeStrokeColor().cgColor)
        strokeRoundedRect(weeklyTrackRect, cornerRadius: barHeight / 2, lineWidth: 0.6, in: context)
        strokeRoundedRect(sessionTrackRect, cornerRadius: barHeight / 2, lineWidth: 0.6, in: context)

        if let session = sessionUsage {
            let normalized = normalizedPercent(session)
            let barWidth = size.width * normalized / 100.0
            let fillRect = CGRect(x: 0, y: barsOriginY + barHeight + barGap, width: barWidth, height: barHeight)
            context.setFillColor(NSColor.systemBlue.cgColor)
            fillRoundedRect(fillRect, cornerRadius: min(barHeight / 2, barWidth / 2), in: context)
            context.setStrokeColor(gaugeStrokeColor().cgColor)
            strokeRoundedRect(fillRect, cornerRadius: min(barHeight / 2, barWidth / 2), lineWidth: 0.6, in: context)
        }

        if let weekly = weeklyUsage {
            let normalized = normalizedPercent(weekly)
            let barWidth = size.width * normalized / 100.0
            let fillRect = CGRect(x: 0, y: barsOriginY, width: barWidth, height: barHeight)
            context.setFillColor(NSColor.systemGreen.cgColor)
            fillRoundedRect(fillRect, cornerRadius: min(barHeight / 2, barWidth / 2), in: context)
            context.setStrokeColor(gaugeStrokeColor().cgColor)
            strokeRoundedRect(fillRect, cornerRadius: min(barHeight / 2, barWidth / 2), lineWidth: 0.6, in: context)
        }

        if isStale {
            context.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    static func renderDetailedProvidersIcon(
        barProviders: [ProviderSegmentData],
        openRouter: OpenRouterSegmentData?,
        isStale: Bool = false
    ) -> NSImage {
        let providerWidth: CGFloat = 40
        let providerSpacing: CGFloat = 5
        let leftPad: CGFloat = 2
        let rightPad: CGFloat = 2
        let height: CGFloat = 22

        let providersWidth: CGFloat = barProviders.isEmpty
            ? 0
            : CGFloat(barProviders.count) * providerWidth + CGFloat(max(0, barProviders.count - 1)) * providerSpacing

        let openRouterWidth = openRouter.map(openRouterSegmentWidth) ?? 0

        let separatorWidth: CGFloat = (!barProviders.isEmpty && openRouter != nil) ? 5 : 0
        let width = max(18, leftPad + providersWidth + separatorWidth + openRouterWidth + rightPad)

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()

        let context = NSGraphicsContext.current!.cgContext
        context.setFillColor(NSColor.clear.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        var x = leftPad
        for provider in barProviders {
            drawProviderSegment(provider, atX: x, context: context, totalHeight: height)
            x += providerWidth + providerSpacing
        }

        if let openRouter {
            if !barProviders.isEmpty {
                x += 2
            }
            drawOpenRouterSegment(openRouter, atX: x, context: context, totalHeight: height)
        }

        if isStale {
            context.setFillColor(NSColor.black.withAlphaComponent(0.25).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func drawProviderSegment(
        _ provider: ProviderSegmentData,
        atX x: CGFloat,
        context: CGContext,
        totalHeight: CGFloat
    ) {
        let iconSize: CGFloat = 17
        let iconRect = CGRect(
            x: x,
            y: (totalHeight - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        if let icon = provider.icon {
            icon.draw(in: iconRect)
        } else {
            let fallbackRect = iconRect
            context.setFillColor(provider.brandColor.withAlphaComponent(0.3).cgColor)
            context.fillEllipse(in: fallbackRect)
        }

        let barX = x + iconSize + 3
        let barWidth: CGFloat = 20
        let barHeight: CGFloat = 5
        let barGap: CGFloat = 2
        let barsOriginY = (totalHeight - (barHeight * 2 + barGap)) / 2
        let weeklyY = barsOriginY
        let sessionY = barsOriginY + barHeight + barGap

        let sessionTrackRect = CGRect(x: barX, y: sessionY, width: barWidth, height: barHeight)
        let weeklyTrackRect = CGRect(x: barX, y: weeklyY, width: barWidth, height: barHeight)
        context.setFillColor(gaugeTrackColor().cgColor)
        fillRoundedRect(sessionTrackRect, cornerRadius: barHeight / 2, in: context)
        fillRoundedRect(weeklyTrackRect, cornerRadius: barHeight / 2, in: context)
        context.setStrokeColor(gaugeStrokeColor().cgColor)
        strokeRoundedRect(sessionTrackRect, cornerRadius: barHeight / 2, lineWidth: 0.6, in: context)
        strokeRoundedRect(weeklyTrackRect, cornerRadius: barHeight / 2, lineWidth: 0.6, in: context)

        if let session = provider.session {
            let pct = normalizedPercent(session)
            let fillWidth = max(0, barWidth * pct / 100)
            if fillWidth > 0 {
                let fillRect = CGRect(x: barX, y: sessionY, width: fillWidth, height: barHeight)
                context.setFillColor(provider.brandColor.cgColor)
                fillRoundedRect(
                    fillRect,
                    cornerRadius: min(barHeight / 2, fillWidth / 2),
                    in: context
                )
                context.setStrokeColor(gaugeStrokeColor().cgColor)
                strokeRoundedRect(
                    fillRect,
                    cornerRadius: min(barHeight / 2, fillWidth / 2),
                    lineWidth: 0.5,
                    in: context
                )
            }
        }

        if let weekly = provider.weekly {
            let pct = normalizedPercent(weekly)
            let weeklyColor = provider.brandColor.withAlphaComponent(0.6)
            let fillWidth = max(0, barWidth * pct / 100)
            if fillWidth > 0 {
                let fillRect = CGRect(x: barX, y: weeklyY, width: fillWidth, height: barHeight)
                context.setFillColor(weeklyColor.cgColor)
                fillRoundedRect(
                    fillRect,
                    cornerRadius: min(barHeight / 2, fillWidth / 2),
                    in: context
                )
                context.setStrokeColor(gaugeStrokeColor().cgColor)
                strokeRoundedRect(
                    fillRect,
                    cornerRadius: min(barHeight / 2, fillWidth / 2),
                    lineWidth: 0.5,
                    in: context
                )
            }
        }

        if provider.session == nil {
            context.setFillColor(NSColor.tertiaryLabelColor.withAlphaComponent(0.4).cgColor)
            fillRoundedRect(
                CGRect(x: barX, y: sessionY, width: 2.2, height: barHeight),
                cornerRadius: 1.1,
                in: context
            )
        }

        if provider.weekly == nil {
            context.setFillColor(NSColor.tertiaryLabelColor.withAlphaComponent(0.35).cgColor)
            fillRoundedRect(
                CGRect(x: barX, y: weeklyY, width: 2.2, height: barHeight),
                cornerRadius: 1.1,
                in: context
            )
        }
    }

    private static func drawOpenRouterSegment(
        _ openRouter: OpenRouterSegmentData,
        atX x: CGFloat,
        context: CGContext,
        totalHeight: CGFloat
    ) {
        let iconSize: CGFloat = 17
        let iconRect = CGRect(
            x: x,
            y: (totalHeight - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        if let icon = openRouter.icon {
            icon.draw(in: iconRect)
        } else {
            context.setFillColor(openRouter.brandColor.withAlphaComponent(0.3).cgColor)
            context.fillEllipse(in: iconRect)
        }

        guard let credits = openRouter.credits else {
            return
        }

        let value = openRouterValueText(credits)
        let attrs = openRouterTextAttributes()
        let textSize = NSString(string: value).size(withAttributes: attrs)
        let textY = (totalHeight - textSize.height) / 2
        NSString(string: value).draw(at: NSPoint(x: x + iconSize + 4, y: textY), withAttributes: attrs)
    }

    private static func openRouterSegmentWidth(_ openRouter: OpenRouterSegmentData) -> CGFloat {
        let iconSize: CGFloat = 17
        let textGap: CGFloat = 4
        let rightPad: CGFloat = 5
        guard let credits = openRouter.credits else {
            return iconSize + rightPad
        }

        let value = openRouterValueText(credits)
        let attrs = openRouterTextAttributes()
        let textWidth = NSString(string: value).size(withAttributes: attrs).width
        return ceil(iconSize + textGap + textWidth + rightPad)
    }

    private static func openRouterValueText(_ credits: Double) -> String {
        credits >= 100
            ? String(format: "$%.0f", credits)
            : String(format: "$%.1f", credits)
    }

    private static func openRouterTextAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold),
            .foregroundColor: BrandColor.openRouterStrong
        ]
    }

    private static func normalizedPercent(_ value: Double) -> CGFloat {
        let pct = value < 1 ? value * 100 : value
        return CGFloat(max(0, min(pct, 100)))
    }

    private static var isDarkAppearance: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private static func gaugeTrackColor() -> NSColor {
        isDarkAppearance
            ? NSColor.white.withAlphaComponent(0.24)
            : NSColor.black.withAlphaComponent(0.13)
    }

    private static func gaugeStrokeColor() -> NSColor {
        isDarkAppearance
            ? NSColor.white.withAlphaComponent(0.30)
            : NSColor.black.withAlphaComponent(0.18)
    }

    private static func fillRoundedRect(
        _ rect: CGRect,
        cornerRadius: CGFloat,
        in context: CGContext
    ) {
        guard rect.width > 0, rect.height > 0 else {
            return
        }

        let path = CGPath(
            roundedRect: rect,
            cornerWidth: max(0, cornerRadius),
            cornerHeight: max(0, cornerRadius),
            transform: nil
        )
        context.addPath(path)
        context.fillPath()
    }

    private static func strokeRoundedRect(
        _ rect: CGRect,
        cornerRadius: CGFloat,
        lineWidth: CGFloat,
        in context: CGContext
    ) {
        guard rect.width > 0, rect.height > 0 else {
            return
        }

        let path = CGPath(
            roundedRect: rect,
            cornerWidth: max(0, cornerRadius),
            cornerHeight: max(0, cornerRadius),
            transform: nil
        )
        context.setLineWidth(lineWidth)
        context.addPath(path)
        context.strokePath()
    }
}
