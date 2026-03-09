#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="$PROJECT_DIR/FileButler.app"

echo "==> Building FileButler.app"

# Create app bundle structure
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy Info.plist
cp "$PROJECT_DIR/FileButler/Info.plist" "$APP_DIR/Contents/Info.plist"

# ── 1. Compile Swift ──────────────────────────────────────────────

SWIFT_FILES=$(find "$PROJECT_DIR/FileButler" -name "*.swift" -type f)
RULES_FILES=$(find "$PROJECT_DIR/Rules" -name "*.swift" -type f)

echo "==> Compiling Swift sources..."
swiftc \
    -o "$APP_DIR/Contents/MacOS/FileButler" \
    -target "$(uname -m)-apple-macosx26.0" \
    -framework Cocoa \
    -framework UserNotifications \
    -framework CoreServices \
    $SWIFT_FILES \
    $RULES_FILES

echo "    Binary compiled"

# ── 2. Generate all icons (programmatic) ──────────────────────────

echo "==> Generating icons..."
ICON_GEN="/tmp/fb_icon_gen.swift"
cat > "$ICON_GEN" << 'ICONSWIFT'
import Cocoa

// Draw a bow tie (Fliege)
func drawBowtie(ctx: CGContext, s: CGFloat, bgColor1: NSColor?, bgColor2: NSColor?, bowtieColor: NSColor, knotColor: NSColor, outlineMode: Bool) {
    let cx = s / 2.0
    let cy = s / 2.0
    let wingW = s * 0.31   // wing width from center
    let wingH = s * 0.16   // wing half-height at outer edge
    let knotRx = s * 0.045
    let knotRy = s * 0.065

    // Background
    if let c1 = bgColor1 {
        let bg = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: s, height: s), xRadius: s * 0.2, yRadius: s * 0.2)
        if let c2 = bgColor2 {
            let gradient = NSGradient(starting: c1, ending: c2)!
            gradient.draw(in: bg, angle: 90)
        } else {
            c1.setFill()
            bg.fill()
        }
    }

    if outlineMode {
        // Menubar: filled rounded rect with bow tie cut out
        NSColor.black.setFill()
        let bg = NSBezierPath(roundedRect: NSRect(x: s * 0.045, y: s * 0.045, width: s * 0.91, height: s * 0.91), xRadius: s * 0.18, yRadius: s * 0.18)
        bg.fill()
        ctx.setBlendMode(.clear)
        for side: CGFloat in [-1, 1] {
            let wing = NSBezierPath()
            wing.move(to: NSPoint(x: cx, y: cy))
            wing.line(to: NSPoint(x: cx + side * wingW, y: cy + wingH))
            wing.line(to: NSPoint(x: cx + side * wingW, y: cy - wingH))
            wing.close()
            wing.fill()
        }
        let knot = NSBezierPath(ovalIn: NSRect(x: cx - knotRx, y: cy - knotRy, width: knotRx * 2, height: knotRy * 2))
        knot.fill()
        ctx.setBlendMode(.normal)
    } else {
        // App icon: colored bow tie
        bowtieColor.setFill()
        for side: CGFloat in [-1, 1] {
            let wing = NSBezierPath()
            wing.move(to: NSPoint(x: cx, y: cy))
            wing.line(to: NSPoint(x: cx + side * wingW, y: cy + wingH))
            wing.line(to: NSPoint(x: cx + side * wingW, y: cy - wingH))
            wing.close()
            wing.fill()
        }
        knotColor.setFill()
        let knot = NSBezierPath(ovalIn: NSRect(x: cx - knotRx, y: cy - knotRy, width: knotRx * 2, height: knotRy * 2))
        knot.fill()
    }
}

func createImage(size: Int, draw: (CGContext) -> Void) -> Data? {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    draw(ctx)
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
    return png
}

let resDir = CommandLine.arguments[1]
let iconsetDir = CommandLine.arguments[2]

// Blue gradient colors
let blue1 = NSColor(red: 0.290, green: 0.565, blue: 0.851, alpha: 1.0)  // #4A90D9
let blue2 = NSColor(red: 0.169, green: 0.369, blue: 0.655, alpha: 1.0)  // #2B5EA7

// Menubar icons (template, black on transparent)
for size in [22, 44] {
    let suffix = size == 44 ? "@2x" : ""
    if let data = createImage(size: size, draw: { ctx in
        drawBowtie(ctx: ctx, s: CGFloat(size), bgColor1: nil, bgColor2: nil, bowtieColor: .black, knotColor: .black, outlineMode: true)
    }) {
        try! data.write(to: URL(fileURLWithPath: resDir + "/MenuBarIcon\(suffix).png"))
    }
}
print("Menubar icons generated")

// App icons (colored, for .icns)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    if let data = createImage(size: size, draw: { ctx in
        drawBowtie(ctx: ctx, s: CGFloat(size), bgColor1: blue1, bgColor2: blue2, bowtieColor: .white, knotColor: NSColor(red: 0.91, green: 0.93, blue: 0.96, alpha: 1.0), outlineMode: false)
    }) {
        try! data.write(to: URL(fileURLWithPath: iconsetDir + "/icon_\(size)x\(size).png"))
    }
}

// Create @2x variants
let fm = FileManager.default
try! fm.copyItem(atPath: iconsetDir + "/icon_32x32.png", toPath: iconsetDir + "/icon_16x16@2x.png")
try! fm.copyItem(atPath: iconsetDir + "/icon_64x64.png", toPath: iconsetDir + "/icon_32x32@2x.png")
try! fm.copyItem(atPath: iconsetDir + "/icon_256x256.png", toPath: iconsetDir + "/icon_128x128@2x.png")
try! fm.copyItem(atPath: iconsetDir + "/icon_512x512.png", toPath: iconsetDir + "/icon_256x256@2x.png")
try! fm.copyItem(atPath: iconsetDir + "/icon_1024x1024.png", toPath: iconsetDir + "/icon_512x512@2x.png")
try! fm.removeItem(atPath: iconsetDir + "/icon_64x64.png")
try! fm.removeItem(atPath: iconsetDir + "/icon_1024x1024.png")
print("App icons generated")
ICONSWIFT

ICONSET_DIR="/tmp/FileButlerIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

swiftc -framework Cocoa -o /tmp/fb_icon_gen "$ICON_GEN"
/tmp/fb_icon_gen "$APP_DIR/Contents/Resources" "$ICONSET_DIR"

iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET_DIR"
echo "    All icons generated"

# ── 4. Code Sign (ad-hoc, required for notifications) ────────────

SIGN_IDENTITY="FileButler Dev"
echo "==> Code signing with '$SIGN_IDENTITY'..."
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"
echo "    Signed"

echo ""
echo "==> Build complete: $APP_DIR"
echo "    Run with: open FileButler.app"
