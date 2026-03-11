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

    guard NSGraphicsContext.current?.cgContext != nil else {
        image.unlockFocus()
        return image
    }

    let cx = s / 2, cy = s / 2

    // ── SF Symbol "timer" in blue, no background ─────────────────────────────
    let symbolSize = s * 0.92
    let blue = NSColor(red: 0.25, green: 0.55, blue: 0.95, alpha: 1)
    let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium)
        .applying(NSImage.SymbolConfiguration(paletteColors: [blue]))
    if let symbol = NSImage(systemSymbolName: "timer", accessibilityDescription: nil)?
                        .withSymbolConfiguration(config) {
        let symRect = CGRect(
            x: cx - symbolSize / 2,
            y: cy - symbolSize / 2,
            width: symbolSize,
            height: symbolSize
        )
        symbol.draw(in: symRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

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

print("Generating icon assets...")
for size in sizes {
    let img = drawIcon(size: size)
    savePNG(img, path: "\(outputDir)/icon_\(size)x\(size).png")
}

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
