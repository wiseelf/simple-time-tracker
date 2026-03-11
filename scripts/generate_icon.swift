#!/usr/bin/env swift
// Generates the TimeTracker app icon at all required macOS sizes.
// Run from the repo root: swift scripts/generate_icon.swift

import CoreGraphics
import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]

let outputDir = "Sources/TimeTracker/Assets.xcassets/AppIcon.appiconset"
let fm = FileManager.default
try! fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

func drawIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // ── Background: deep indigo rounded square ──────────────────────────────
    let radius = s * 0.22
    let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                        cornerWidth: radius, cornerHeight: radius, transform: nil)

    let topColor    = CGColor(red: 0.13, green: 0.20, blue: 0.36, alpha: 1) // #213360
    let bottomColor = CGColor(red: 0.06, green: 0.09, blue: 0.20, alpha: 1) // #0F1733

    ctx.addPath(bgPath)
    ctx.clip()

    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [topColor, bottomColor] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: s / 2, y: s),
                           end:   CGPoint(x: s / 2, y: 0),
                           options: [])

    // ── Clock face ──────────────────────────────────────────────────────────
    let cx = s / 2, cy = s / 2
    let faceR = s * 0.36

    // Subtle glow behind face
    ctx.resetClip()
    ctx.addPath(bgPath)
    ctx.clip()
    ctx.setShadow(offset: .zero, blur: s * 0.12,
                  color: CGColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 0.35))
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.0))
    ctx.fillEllipse(in: CGRect(x: cx - faceR, y: cy - faceR, width: faceR * 2, height: faceR * 2))
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    // White circle face
    ctx.setFillColor(CGColor(red: 0.97, green: 0.97, blue: 1.0, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: cx - faceR, y: cy - faceR, width: faceR * 2, height: faceR * 2))

    // Hour tick marks
    let tickOuter = faceR * 0.88
    let tickInner = faceR * 0.74
    let tickInnerMinor = faceR * 0.80
    ctx.setStrokeColor(CGColor(red: 0.18, green: 0.28, blue: 0.52, alpha: 0.6))
    for i in 0..<12 {
        let angle = CGFloat(i) * .pi / 6 - .pi / 2
        let isMajor = i % 3 == 0
        let inner = isMajor ? tickInner : tickInnerMinor
        ctx.setLineWidth(isMajor ? s * 0.018 : s * 0.010)
        ctx.move(to: CGPoint(x: cx + cos(angle) * inner,  y: cy + sin(angle) * inner))
        ctx.addLine(to: CGPoint(x: cx + cos(angle) * tickOuter, y: cy + sin(angle) * tickOuter))
        ctx.strokePath()
    }

    // ── Hands at 10:10 ──────────────────────────────────────────────────────
    // Recompute cleanly
    // Hour hand: 10h10m = 10*30 + 10*0.5 = 305 degrees from 12, clockwise
    // In CGContext (y-flipped): angle from +x axis, counter-clockwise = standard math
    // But NSImage is y-up (Quartz), so clockwise in screen = counter-clockwise in math
    // 12 o'clock = π/2 in math coords (y-up). Going clockwise = decreasing angle.
    let h_deg: CGFloat = 305   // 10h10m clockwise from 12
    let m_deg: CGFloat = 60    // 10m clockwise from 12

    func clockAngle(_ deg: CGFloat) -> CGFloat {
        // Convert clock degrees (0=12, clockwise) to math radians (y-up)
        return (.pi / 2) - deg * .pi / 180
    }

    let hAngle = clockAngle(h_deg)
    let mAngle = clockAngle(m_deg)

    let handColor = CGColor(red: 0.13, green: 0.23, blue: 0.50, alpha: 1)
    let accentColor = CGColor(red: 0.25, green: 0.50, blue: 0.95, alpha: 1)

    // Hour hand
    ctx.setStrokeColor(handColor)
    ctx.setLineWidth(s * 0.045)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: cx - cos(hAngle) * faceR * 0.12,
                         y: cy - sin(hAngle) * faceR * 0.12))
    ctx.addLine(to: CGPoint(x: cx + cos(hAngle) * faceR * 0.52,
                            y: cy + sin(hAngle) * faceR * 0.52))
    ctx.strokePath()

    // Minute hand
    ctx.setStrokeColor(accentColor)
    ctx.setLineWidth(s * 0.032)
    ctx.move(to: CGPoint(x: cx - cos(mAngle) * faceR * 0.14,
                         y: cy - sin(mAngle) * faceR * 0.14))
    ctx.addLine(to: CGPoint(x: cx + cos(mAngle) * faceR * 0.70,
                            y: cy + sin(mAngle) * faceR * 0.70))
    ctx.strokePath()

    // Center dot
    let dotR = s * 0.030
    ctx.setFillColor(handColor)
    ctx.fillEllipse(in: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2))

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, path: String) {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fputs("Failed to encode PNG for \(path)\n", stderr)
        return
    }
    fm.createFile(atPath: path, contents: png)
    print("  wrote \(path)")
}

// Generate all sizes
print("Generating icon assets...")
for size in sizes {
    let img = drawIcon(size: size)
    savePNG(img, path: "\(outputDir)/icon_\(size)x\(size).png")
}

// Write Contents.json
// Each @2x slot reuses the next size up (e.g. 32x32.png = 16x16@2x)
let contents = """
{
  "images" : [
    { "filename" : "icon_16x16.png",   "idiom" : "mac", "scale" : "1x", "size" : "16x16"   },
    { "filename" : "icon_32x32.png",   "idiom" : "mac", "scale" : "2x", "size" : "16x16"   },
    { "filename" : "icon_32x32.png",   "idiom" : "mac", "scale" : "1x", "size" : "32x32"   },
    { "filename" : "icon_64x64.png",   "idiom" : "mac", "scale" : "2x", "size" : "32x32"   },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_1024x1024.png","idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
fm.createFile(atPath: "\(outputDir)/Contents.json", contents: contents.data(using: .utf8))
print("  wrote \(outputDir)/Contents.json")
print("Done.")
