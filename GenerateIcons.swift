#!/usr/bin/env swift
// Run from project root:  swift GenerateIcons.swift

import AppKit
import Foundation
import ImageIO

let outDir = "Suipian/Assets.xcassets/AppIcon.appiconset"

// MARK: - Core helpers

func cgColor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

/// Create a pixel-exact CGContext (no Retina scaling)
func makeCtx(_ size: Int) -> CGContext {
    CGContext(data: nil, width: size, height: size,
              bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func savePNG(_ ctx: CGContext, to path: String) {
    guard let img = ctx.makeImage() else { print("❌ makeImage: \(path)"); return }
    let url = URL(fileURLWithPath: path) as CFURL
    guard let dest = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil) else {
        print("❌ dest: \(path)"); return
    }
    CGImageDestinationAddImage(dest, img, nil)
    print(CGImageDestinationFinalize(dest) ? "✅ \(path)" : "❌ finalize: \(path)")
}

// MARK: - Drawing primitives

func fillRect(_ ctx: CGContext, _ size: CGFloat, _ color: CGColor) {
    ctx.setFillColor(color)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
}

func radialGlow(_ ctx: CGContext, center: CGPoint, innerR: CGFloat, outerR: CGFloat,
                innerColor: CGColor, outerColor: CGColor) {
    guard let grad = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [innerColor, outerColor] as CFArray,
        locations: [0, 1]
    ) else { return }
    ctx.drawRadialGradient(grad,
        startCenter: center, startRadius: innerR,
        endCenter: center, endRadius: outerR, options: [])
}

func drawCard(ctx: CGContext, cx: CGFloat, cy: CGFloat,
              w: CGFloat, h: CGFloat, r: CGFloat, rot: CGFloat,
              fill: CGColor, strokeColor: CGColor? = nil, strokeW: CGFloat = 0,
              shadowBlur: CGFloat = 0, shadowColor: CGColor? = nil) {
    ctx.saveGState()
    ctx.translateBy(x: cx, y: cy)
    ctx.rotate(by: rot * .pi / 180)
    if shadowBlur > 0, let sc = shadowColor {
        ctx.setShadow(offset: CGSize(width: 0, height: -shadowBlur * 0.3), blur: shadowBlur, color: sc)
    }
    let rect = CGRect(x: -w/2, y: -h/2, width: w, height: h)
    let path = CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
    ctx.setFillColor(fill)
    ctx.addPath(path); ctx.fillPath()
    if let sc = strokeColor, strokeW > 0 {
        ctx.setStrokeColor(sc)
        ctx.setLineWidth(strokeW)
        ctx.addPath(path); ctx.strokePath()
    }
    ctx.restoreGState()
}

func drawLines(ctx: CGContext, cx: CGFloat, cy: CGFloat,
               cw: CGFloat, ch: CGFloat, color: CGColor, lw: CGFloat) {
    ctx.saveGState()
    ctx.setStrokeColor(color)
    ctx.setLineWidth(lw)
    ctx.setLineCap(.round)
    let x1 = cx - cw * 0.32, x2 = cx + cw * 0.32
    for (i, frac): (Int, CGFloat) in [(0, 0.13), (1, 0.0), (2, -0.13)] {
        ctx.move(to: CGPoint(x: x1, y: cy + ch * frac))
        ctx.addLine(to: CGPoint(x: x2 - CGFloat(i) * cw * 0.09, y: cy + ch * frac))
    }
    ctx.strokePath()
    ctx.restoreGState()
}

/// Draw a glowing slash line (anime-style zanpakuto cut)
func drawSlash(ctx: CGContext, from p1: CGPoint, to p2: CGPoint,
               glowColor: CGColor, coreColor: CGColor, size: CGFloat) {
    // Outer glow
    ctx.saveGState()
    ctx.setStrokeColor(glowColor)
    ctx.setLineWidth(size * 0.022)
    ctx.setLineCap(.round)
    ctx.move(to: p1); ctx.addLine(to: p2)
    ctx.strokePath()
    ctx.restoreGState()
    // Core line
    ctx.saveGState()
    ctx.setStrokeColor(coreColor)
    ctx.setLineWidth(size * 0.007)
    ctx.setLineCap(.round)
    ctx.move(to: p1); ctx.addLine(to: p2)
    ctx.strokePath()
    ctx.restoreGState()
}

/// Scatter tiny soul-spirit particles
func drawParticles(ctx: CGContext, size: CGFloat, color: CGColor, seed: UInt64) {
    var rng = seed
    func nextFloat() -> CGFloat {
        rng = rng &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(rng >> 33) / CGFloat(UInt32.max)
    }
    ctx.setFillColor(color)
    for _ in 0..<14 {
        let x = nextFloat() * size, y = nextFloat() * size
        let r = (nextFloat() * 0.012 + 0.005) * size
        ctx.fillEllipse(in: CGRect(x: x-r, y: y-r, width: r*2, height: r*2))
    }
}

// MARK: - Light (Any Appearance) — dark theme, Bleach-style

func lightIcon(size: Int) -> CGContext {
    let ctx = makeCtx(size)
    let s = CGFloat(size)

    // Deep black-purple base
    fillRect(ctx, s, cgColor(0.05, 0.04, 0.09))

    // Orange reiatsu glow behind cards (Ichigo's spiritual pressure)
    radialGlow(ctx,
        center: CGPoint(x: s * 0.48, y: s * 0.42),
        innerR: 0, outerR: s * 0.52,
        innerColor: cgColor(0.95, 0.48, 0.08, 0.38),
        outerColor: cgColor(0.95, 0.48, 0.08, 0.0))

    // Subtle blue spirit glow (Soul Society)
    radialGlow(ctx,
        center: CGPoint(x: s * 0.65, y: s * 0.70),
        innerR: 0, outerR: s * 0.35,
        innerColor: cgColor(0.25, 0.45, 0.90, 0.18),
        outerColor: cgColor(0.25, 0.45, 0.90, 0.0))

    let cx = s * 0.50, cy = s * 0.47
    let cw = s * 0.60, ch = s * 0.43, cr = s * 0.048

    // Back card — dark steel, heavily rotated
    drawCard(ctx: ctx, cx: cx - s*0.028, cy: cy + s*0.022,
             w: cw, h: ch, r: cr, rot: -22,
             fill: cgColor(0.12, 0.14, 0.26),
             strokeColor: cgColor(0.30, 0.38, 0.60, 0.4), strokeW: s*0.004)

    // Middle card — deep navy
    drawCard(ctx: ctx, cx: cx - s*0.013, cy: cy + s*0.010,
             w: cw, h: ch, r: cr, rot: -11,
             fill: cgColor(0.18, 0.22, 0.38),
             strokeColor: cgColor(0.40, 0.50, 0.75, 0.35), strokeW: s*0.003)

    // Front card — ice-silver white with soft shadow
    drawCard(ctx: ctx, cx: cx, cy: cy,
             w: cw, h: ch, r: cr, rot: 4,
             fill: cgColor(0.92, 0.94, 0.98),
             strokeColor: cgColor(1, 1, 1, 0.6), strokeW: s*0.003,
             shadowBlur: s * 0.06, shadowColor: cgColor(0, 0, 0, 0.55))

    // Lines on front card
    drawLines(ctx: ctx, cx: cx, cy: cy, cw: cw, ch: ch,
              color: cgColor(0.55, 0.60, 0.72, 0.8), lw: s * 0.014)

    // Orange accent dot (top-right of front card, rotated with card ≈ 4°)
    let dotX = cx + cw * 0.28, dotY = cy + ch * 0.30
    let dotR = s * 0.038
    ctx.setFillColor(cgColor(0.95, 0.48, 0.08))
    ctx.fillEllipse(in: CGRect(x: dotX-dotR, y: dotY-dotR, width: dotR*2, height: dotR*2))

    // Soul particles
    drawParticles(ctx: ctx, size: s, color: cgColor(0.95, 0.55, 0.15, 0.55), seed: 42)

    return ctx
}

// MARK: - Dark Appearance

func darkIcon(size: Int) -> CGContext {
    let ctx = makeCtx(size)
    let s = CGFloat(size)

    // Even deeper black
    fillRect(ctx, s, cgColor(0.03, 0.02, 0.06))

    // Intense orange reiatsu
    radialGlow(ctx,
        center: CGPoint(x: s * 0.46, y: s * 0.44),
        innerR: 0, outerR: s * 0.55,
        innerColor: cgColor(1.0, 0.52, 0.10, 0.45),
        outerColor: cgColor(1.0, 0.52, 0.10, 0.0))

    radialGlow(ctx,
        center: CGPoint(x: s * 0.68, y: s * 0.68),
        innerR: 0, outerR: s * 0.30,
        innerColor: cgColor(0.20, 0.40, 0.90, 0.20),
        outerColor: cgColor(0.20, 0.40, 0.90, 0.0))

    let cx = s * 0.50, cy = s * 0.47
    let cw = s * 0.60, ch = s * 0.43, cr = s * 0.048

    drawCard(ctx: ctx, cx: cx - s*0.028, cy: cy + s*0.022,
             w: cw, h: ch, r: cr, rot: -22,
             fill: cgColor(0.09, 0.10, 0.20),
             strokeColor: cgColor(0.25, 0.32, 0.55, 0.4), strokeW: s*0.004)

    drawCard(ctx: ctx, cx: cx - s*0.013, cy: cy + s*0.010,
             w: cw, h: ch, r: cr, rot: -11,
             fill: cgColor(0.14, 0.18, 0.32),
             strokeColor: cgColor(0.35, 0.45, 0.70, 0.4), strokeW: s*0.003)

    drawCard(ctx: ctx, cx: cx, cy: cy,
             w: cw, h: ch, r: cr, rot: 4,
             fill: cgColor(0.88, 0.91, 0.96),
             strokeColor: cgColor(1, 1, 1, 0.5), strokeW: s*0.003,
             shadowBlur: s * 0.07, shadowColor: cgColor(0, 0, 0, 0.7))

    drawLines(ctx: ctx, cx: cx, cy: cy, cw: cw, ch: ch,
              color: cgColor(0.45, 0.52, 0.65, 0.8), lw: s * 0.014)

    let dotX = cx + cw * 0.28, dotY = cy + ch * 0.30
    let dotR = s * 0.038
    ctx.setFillColor(cgColor(1.0, 0.58, 0.15))
    ctx.fillEllipse(in: CGRect(x: dotX-dotR, y: dotY-dotR, width: dotR*2, height: dotR*2))

    drawParticles(ctx: ctx, size: s, color: cgColor(1.0, 0.58, 0.15, 0.60), seed: 42)

    return ctx
}

// MARK: - Tinted (monochrome-friendly for system tint)

func tintedIcon(size: Int) -> CGContext {
    let ctx = makeCtx(size)
    let s = CGFloat(size)

    fillRect(ctx, s, cgColor(0.08, 0.08, 0.12))

    radialGlow(ctx,
        center: CGPoint(x: s * 0.48, y: s * 0.44),
        innerR: 0, outerR: s * 0.50,
        innerColor: cgColor(0.60, 0.60, 0.70, 0.30),
        outerColor: cgColor(0.60, 0.60, 0.70, 0.0))

    let cx = s * 0.50, cy = s * 0.47
    let cw = s * 0.60, ch = s * 0.43, cr = s * 0.048

    drawCard(ctx: ctx, cx: cx - s*0.028, cy: cy + s*0.022,
             w: cw, h: ch, r: cr, rot: -22,
             fill: cgColor(0.20, 0.22, 0.30),
             strokeColor: cgColor(0.45, 0.48, 0.58, 0.4), strokeW: s*0.004)

    drawCard(ctx: ctx, cx: cx - s*0.013, cy: cy + s*0.010,
             w: cw, h: ch, r: cr, rot: -11,
             fill: cgColor(0.32, 0.34, 0.44),
             strokeColor: cgColor(0.55, 0.58, 0.68, 0.35), strokeW: s*0.003)

    drawCard(ctx: ctx, cx: cx, cy: cy,
             w: cw, h: ch, r: cr, rot: 4,
             fill: cgColor(0.90, 0.91, 0.95),
             strokeColor: cgColor(1, 1, 1, 0.5), strokeW: s*0.003,
             shadowBlur: s * 0.06, shadowColor: cgColor(0, 0, 0, 0.5))

    drawLines(ctx: ctx, cx: cx, cy: cy, cw: cw, ch: ch,
              color: cgColor(0.55, 0.57, 0.65, 0.8), lw: s * 0.014)

    let dotX = cx + cw * 0.28, dotY = cy + ch * 0.30
    let dotR = s * 0.038
    ctx.setFillColor(cgColor(0.70, 0.72, 0.82))
    ctx.fillEllipse(in: CGRect(x: dotX-dotR, y: dotY-dotR, width: dotR*2, height: dotR*2))

    drawParticles(ctx: ctx, size: s, color: cgColor(0.70, 0.72, 0.82, 0.55), seed: 42)

    return ctx
}

// MARK: - Run

savePNG(lightIcon(size: 1024),  to: "\(outDir)/AppIcon.png")
savePNG(darkIcon(size: 1024),   to: "\(outDir)/AppIcon~dark.png")
savePNG(tintedIcon(size: 1024), to: "\(outDir)/AppIcon~tinted.png")
print("\nDone — rebuild in Xcode to see the new icons.")
