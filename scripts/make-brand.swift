#!/usr/bin/env swift
// Regenerates every Monetic logo file from one set of shapes.
// Run from the repo root: swift scripts/make-brand.swift
// Writes SVG + PNG to Marketing/Brand/, the in-app mark to Assets.xcassets/BrandLogo.imageset,
// and the Icon Composer layers to Monetic/AppIcon.icon/Assets.
import AppKit
import CoreText

let ink = "#1C1B18", paper = "#F7F5F0", charcoal = "#141312"
let amberLight = "#C27C00", amberDark = "#F2B13C", white = "#FFFFFF"

// The mark on a 1024 grid: an M of two peaks, a half sun under the middle stroke, a horizon bar.
// Content box is x 152…872, y 202…822 (centred on 512).
func markShapes(m: String, sun: String) -> String {
    """
    <path d="M232 718 V258 L512 462 L792 258 V718" fill="none" stroke="\(m)" stroke-width="112" stroke-linejoin="round"/>
    <path d="M362 718 A150 150 0 0 1 662 718 Z" fill="\(sun)"/>
    <rect x="152" y="758" width="720" height="64" rx="32" fill="\(sun)"/>
    """
}
func mShape(_ c: String) -> String { markShapes(m: c, sun: "none").components(separatedBy: "\n")[0] }
func sunShapes(_ c: String) -> String { markShapes(m: "none", sun: c).components(separatedBy: "\n").dropFirst().joined(separator: "\n") }
let markBox = CGRect(x: 152, y: 202, width: 720, height: 620)

func svg(_ w: CGFloat, _ h: CGFloat, _ body: String, bg: String? = nil) -> String {
    let fill = bg.map { "<rect width=\"\(w)\" height=\"\(h)\" fill=\"\($0)\"/>\n" } ?? ""
    return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(Int(w)) \(Int(h))\" width=\"\(Int(w))\" height=\"\(Int(h))\">\n\(fill)\(body)\n</svg>\n"
}

// "Monetic" in SF Pro Bold, outlined so the SVG doesn't depend on the font being installed.
func wordmark(size: CGFloat, color: String, x: CGFloat, baseline: CGFloat) -> (svg: String, width: CGFloat, capHeight: CGFloat) {
    let font = NSFont.systemFont(ofSize: size, weight: .bold) as CTFont
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "Monetic", attributes: [.font: font]))
    var d = ""
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let n = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: n), pos = [CGPoint](repeating: .zero, count: n)
        CTRunGetGlyphs(run, CFRange(location: 0, length: n), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: n), &pos)
        for i in 0..<n {
            var t = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: x + pos[i].x, ty: baseline) // flip to SVG y-down
            guard let p = CTFontCreatePathForGlyph(font, glyphs[i], &t) else { continue }
            p.applyWithBlock { e in
                let pt = e.pointee.points
                func f(_ q: CGPoint) -> String { String(format: "%.1f %.1f", q.x, q.y) }
                switch e.pointee.type {
                case .moveToPoint: d += "M\(f(pt[0]))"
                case .addLineToPoint: d += "L\(f(pt[0]))"
                case .addQuadCurveToPoint: d += "Q\(f(pt[0])) \(f(pt[1]))"
                case .addCurveToPoint: d += "C\(f(pt[0])) \(f(pt[1])) \(f(pt[2]))"
                case .closeSubpath: d += "Z"
                @unknown default: break
                }
            }
        }
    }
    return ("<path d=\"\(d)\" fill=\"\(color)\"/>", CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)), CTFontGetCapHeight(font))
}

func write(_ text: String, _ path: String) { try! text.write(toFile: path, atomically: true, encoding: .utf8) }

// Renders SVG text to PNG. opaque: no alpha channel (App Store icons must not have one).
func png(_ svgText: String, _ path: String, width: Int, height: Int, opaque: Bool = false) {
    guard let img = NSImage(data: Data(svgText.utf8)) else { fatalError("can't load SVG for \(path)") }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                               samplesPerPixel: opaque ? 3 : 4, hasAlpha: !opaque, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

// Crops the 1024 mark to its content box, offset to (x, y) at the given scale.
func placedMark(m: String, sun: String, x: CGFloat, y: CGFloat, scale: CGFloat) -> String {
    "<g transform=\"translate(\(x) \(y)) scale(\(scale)) translate(\(-markBox.minX) \(-markBox.minY))\">\n\(markShapes(m: m, sun: sun))\n</g>"
}

let brand = "Marketing/Brand"
assert(FileManager.default.fileExists(atPath: brand), "run from the repo root")

// 1. Mark: two-colour (light and dark) plus single-colour amber, ink and white, transparent.
let marks: [(String, String, String)] = [
    ("monetic-logo-mark", ink, amberLight), ("monetic-logo-mark-dark", paper, amberDark),
    ("monetic-logo-mark-amber", amberLight, amberLight), ("monetic-logo-mark-ink", ink, ink),
    ("monetic-logo-mark-white", white, white),
]
for (name, m, s) in marks {
    let t = svg(1024, 1024, markShapes(m: m, sun: s))
    write(t, "\(brand)/\(name).svg"); png(t, "\(brand)/\(name).png", width: 1024, height: 1024)
}

// 2. Lockups. Horizontal: wordmark cap height = 1/2 the mark height, centred on it.
// Stacked: mark above the wordmark, both centred.
for (suffix, m, s) in [("", ink, amberLight), ("-dark", paper, amberDark)] {
    let textColor = m
    let pad: CGFloat = 48
    do { // horizontal
        let markH: CGFloat = 400, sc = markH / markBox.height, markW = markBox.width * sc
        let probe = wordmark(size: 100, color: textColor, x: 0, baseline: 0)
        let size = 100 * (markH / 2) / probe.capHeight
        let gap = markH * 0.22
        let baseline = pad + markH / 2 + markH / 4
        let w = wordmark(size: size, color: textColor, x: pad + markW + gap, baseline: baseline)
        let W = (pad * 2 + markW + gap + w.width).rounded(.up), H = pad * 2 + markH
        let t = svg(W, H, placedMark(m: m, sun: s, x: pad, y: pad, scale: sc) + "\n" + w.svg)
        write(t, "\(brand)/monetic-logo-horizontal\(suffix).svg")
        png(t, "\(brand)/monetic-logo-horizontal\(suffix).png", width: Int(W) * 2, height: Int(H) * 2)
    }
    do { // stacked (this is monetic-logo.png, the README / store logo)
        let markH: CGFloat = 400, sc = markH / markBox.height, markW = markBox.width * sc
        let probe = wordmark(size: 100, color: textColor, x: 0, baseline: 0)
        let size = 100 * (markH * 0.36) / probe.capHeight
        let textW = wordmark(size: size, color: textColor, x: 0, baseline: 0).width
        let W = (pad * 2 + max(markW, textW)).rounded(.up)
        let capH = markH * 0.36, gap = markH * 0.24
        let w = wordmark(size: size, color: textColor, x: (W - textW) / 2, baseline: pad + markH + gap + capH)
        let H = (pad * 2 + markH + gap + capH + size * 0.06).rounded(.up) // small allowance for descender-free baseline
        let t = svg(W, H, placedMark(m: m, sun: s, x: (W - markW) / 2, y: pad, scale: sc) + "\n" + w.svg)
        write(t, "\(brand)/monetic-logo\(suffix).svg")
        png(t, "\(brand)/monetic-logo\(suffix).png", width: Int(W) * 2, height: Int(H) * 2)
    }
}

// 3. App icon. Art sits at 72% so it clears the iOS mask and Liquid Glass edge.
func iconArt(_ body: String) -> String { "<g transform=\"translate(512 512) scale(0.72) translate(-512 -512)\">\n\(body)\n</g>" }
for (suffix, bg, m, s) in [("", paper, ink, amberLight), ("-dark", charcoal, paper, amberDark)] {
    let t = svg(1024, 1024, iconArt(markShapes(m: m, sun: s)), bg: bg)
    write(t, "\(brand)/monetic-app-icon\(suffix).svg")
    png(t, "\(brand)/monetic-app-icon\(suffix).png", width: 1024, height: 1024, opaque: true)
}
let iconAssets = "Monetic/AppIcon.icon/Assets"
try! FileManager.default.createDirectory(atPath: iconAssets, withIntermediateDirectories: true)
write(svg(1024, 1024, iconArt(mShape(ink))), "\(iconAssets)/m.svg")
write(svg(1024, 1024, iconArt(mShape(paper))), "\(iconAssets)/m-dark.svg")
write(svg(1024, 1024, iconArt(sunShapes(amberLight))), "\(iconAssets)/sun.svg")
write(svg(1024, 1024, iconArt(sunShapes(amberDark))), "\(iconAssets)/sun-dark.svg")

// 4. In-app mark: cropped to its content, amber + ink in light, paper + amber in dark.
let imageset = "Monetic/Assets.xcassets/BrandLogo.imageset"
let crop = "\(Int(markBox.minX)) \(Int(markBox.minY)) \(Int(markBox.width)) \(Int(markBox.height))"
for (name, m, s) in [("BrandLogo", ink, amberLight), ("BrandLogo-dark", paper, amberDark)] {
    write("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"\(crop)\" width=\"\(Int(markBox.width))\" height=\"\(Int(markBox.height))\">\n\(markShapes(m: m, sun: s))\n</svg>\n",
          "\(imageset)/\(name).svg")
}
print("Brand files written.")
