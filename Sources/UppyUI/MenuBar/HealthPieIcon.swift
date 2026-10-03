import AppKit

@MainActor
enum HealthPieIcon {
  static func image(online: Int, offline: Int) -> NSImage {
    let size: CGFloat = 22
    let pixels = Int(size * (NSScreen.main?.backingScaleFactor ?? 2))
    guard
      let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
      )
    else { return NSImage(size: NSSize(width: size, height: size)) }
    bitmap.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    draw(online: online, offline: offline)
    NSGraphicsContext.restoreGraphicsState()
    let image = NSImage(size: bitmap.size)
    image.addRepresentation(bitmap)
    image.isTemplate = false
    return image
  }

  private static func draw(online: Int, offline: Int) {
    let rect = NSRect(x: 3, y: 3, width: 16, height: 16)
    if online == 0 || offline == 0 {
      (online + offline == 0 ? NSColor.systemGray : online == 0 ? .systemRed : .systemGreen)
        .setFill()
      NSBezierPath(ovalIn: rect).fill()
    } else {
      let redEnd = 90 - 360 * CGFloat(offline) / CGFloat(online + offline)
      wedge(in: rect, from: 90, to: redEnd, color: .systemRed)
      wedge(in: rect, from: redEnd, to: -270, color: .systemGreen)
    }
    NSColor.labelColor.setStroke()
    let outline = NSBezierPath(ovalIn: rect)
    outline.lineWidth = 1.5
    outline.stroke()
  }

  private static func wedge(in rect: NSRect, from start: CGFloat, to end: CGFloat, color: NSColor) {
    let center = NSPoint(x: rect.midX, y: rect.midY)
    let path = NSBezierPath()
    path.move(to: center)
    path.appendArc(
      withCenter: center, radius: rect.width / 2, startAngle: start, endAngle: end, clockwise: true)
    path.close()
    color.setFill()
    path.fill()
  }
}
