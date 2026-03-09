//
//  ThemeColorUtils.swift
//  FloatyBrowser
//
//  Shared utilities for theme color calculations used by both
//  WebViewController and PanelWindow.
//

import Cocoa

enum ThemeColorSource: Int, Comparable {
    case bodyBackground = 0
    case favicon = 1
    case manifest = 2
    case metaTag = 3
    case header = 4

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct ThemeColorUtils {

    // MARK: - Luminance & Contrast

    static func luminance(of color: NSColor) -> CGFloat {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return 0.5 }
        return 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
    }

    static func isDarkColor(_ color: NSColor) -> Bool {
        luminance(of: color) < 0.5
    }

    static func contrastingIconColor(for backgroundColor: NSColor) -> NSColor {
        if isDarkColor(backgroundColor) {
            return NSColor.white.withAlphaComponent(0.9)
        } else {
            return NSColor.black.withAlphaComponent(0.7)
        }
    }

    // MARK: - URL Field Colors

    struct URLFieldColors {
        let background: NSColor
        let text: NSColor
        let border: NSColor
        let placeholder: NSColor
    }

    /// Derive URL field colors from the toolbar's theme color via HSB shifting.
    /// Produces a visibly distinct but cohesive shade for the address bar.
    static func urlFieldColors(for toolbarColor: NSColor) -> URLFieldColors {
        guard let rgb = toolbarColor.usingColorSpace(.deviceRGB) else {
            return URLFieldColors(
                background: NSColor(white: 0.88, alpha: 1),
                text: .black.withAlphaComponent(0.85),
                border: .black.withAlphaComponent(0.1),
                placeholder: .black.withAlphaComponent(0.35)
            )
        }

        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        NSColor(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent, alpha: 1.0)
            .getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let dark = isDarkColor(toolbarColor)

        let background: NSColor
        if saturation < 0.05 {
            // Achromatic (gray / white / black) — simple brightness shift
            let shift: CGFloat = dark ? 0.12 : -0.10
            background = NSColor(white: max(0, min(1, brightness + shift)), alpha: 1.0)
        } else {
            // Chromatic — shift in HSB space, slightly desaturate
            if dark {
                let bg = min(1.0, brightness + 0.12)
                let sat = saturation * 0.7
                background = NSColor(hue: hue, saturation: sat, brightness: bg, alpha: 1.0)
            } else {
                let bg = max(0.0, brightness - 0.10)
                let sat = saturation * 0.6
                background = NSColor(hue: hue, saturation: sat, brightness: bg, alpha: 1.0)
            }
        }

        // Text contrast is based on the URL field background, not the toolbar
        let urlFieldDark = isDarkColor(background)
        let text = urlFieldDark
            ? NSColor.white.withAlphaComponent(0.9)
            : NSColor.black.withAlphaComponent(0.85)
        let border = urlFieldDark
            ? NSColor.white.withAlphaComponent(0.12)
            : NSColor.black.withAlphaComponent(0.08)
        let placeholder = urlFieldDark
            ? NSColor.white.withAlphaComponent(0.4)
            : NSColor.black.withAlphaComponent(0.35)

        return URLFieldColors(background: background, text: text, border: border, placeholder: placeholder)
    }

    // MARK: - Color Processing

    /// Flatten a color for modern, subtle toolbar appearance
    /// (caps saturation, nudges up very dark colors).
    static func flattenColor(_ color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return color }

        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        NSColor(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent, alpha: rgb.alphaComponent)
            .getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let flatSat = min(saturation * 0.7, 0.65)
        var adjBright = brightness
        if brightness < 0.3 {
            adjBright = min(1.0, brightness + 0.15)
        }

        return NSColor(hue: hue, saturation: flatSat, brightness: adjBright, alpha: alpha)
    }

    /// Reject pure black (luminance < 0.03); everything else passes.
    static func validateColorQuality(_ color: NSColor) -> NSColor? {
        luminance(of: color) < 0.03 ? nil : color
    }

    /// Convenience: flatten + validate in one step.
    static func processExtractedColor(_ color: NSColor) -> NSColor? {
        validateColorQuality(flattenColor(color))
    }

    // MARK: - Color Parsing

    /// Parse a CSS color string: #RGB, #RRGGBB, #RRGGBBAA, rgb(), rgba(), hsl(), hsla().
    static func parseColor(from string: String) -> NSColor? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("#") {
            return parseHexColor(String(trimmed.dropFirst()))
        }
        if trimmed.hasPrefix("rgb") {
            return parseRGBColor(trimmed)
        }
        if trimmed.hasPrefix("hsl") {
            return parseHSLColor(trimmed)
        }
        return nil
    }

    // MARK: - Private Parsers

    private static func parseHexColor(_ hex: String) -> NSColor? {
        let expanded: String
        switch hex.count {
        case 3:
            expanded = hex.map { String(repeating: $0, count: 2) }.joined()
        case 6, 8:
            expanded = hex
        default:
            return nil
        }

        let scanner = Scanner(string: String(expanded.prefix(6)))
        var hexNumber: UInt64 = 0
        guard scanner.scanHexInt64(&hexNumber) else { return nil }

        let r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(hexNumber & 0x0000FF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    private static let rgbRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"rgba?\((\d+),\s*(\d+),\s*(\d+)"#)
    }()

    private static func parseRGBColor(_ string: String) -> NSColor? {
        guard let regex = rgbRegex,
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) else {
            return nil
        }
        let ns = string as NSString
        guard let red = Int(ns.substring(with: match.range(at: 1))),
              let green = Int(ns.substring(with: match.range(at: 2))),
              let blue = Int(ns.substring(with: match.range(at: 3))) else { return nil }
        return NSColor(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }

    private static let hslRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"hsla?\(\s*(\d+\.?\d*)\s*,\s*(\d+\.?\d*)%?\s*,\s*(\d+\.?\d*)%?"#)
    }()

    private static func parseHSLColor(_ string: String) -> NSColor? {
        guard let regex = hslRegex,
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) else {
            return nil
        }
        let ns = string as NSString
        guard let h = Double(ns.substring(with: match.range(at: 1))),
              let s = Double(ns.substring(with: match.range(at: 2))),
              let l = Double(ns.substring(with: match.range(at: 3))) else { return nil }

        let hNorm = CGFloat(h) / 360.0
        let sNorm = CGFloat(s) / 100.0
        let lNorm = CGFloat(l) / 100.0

        // HSL → HSB conversion
        let bHSB = lNorm + sNorm * min(lNorm, 1 - lNorm)
        let sHSB: CGFloat = bHSB == 0 ? 0 : 2 * (1 - lNorm / bHSB)

        return NSColor(hue: hNorm, saturation: sHSB, brightness: bHSB, alpha: 1.0)
    }
}
