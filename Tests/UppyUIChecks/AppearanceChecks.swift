import AppKit
import UppyCore

@testable import UppyUI

@MainActor
func checkTrashAppearance() throws {
  let cell = EndpointCells.delete(
    endpoint: HealthCheckEndpoint(host: "example.com"), target: NSObject(),
    action: #selector(NSResponder.cancelOperation(_:)))
  let button = cell.subviews.compactMap { $0 as? NSButton }.first!
  button.frame = NSRect(x: 0, y: 0, width: 37.8, height: 37.8)
  let light = try trashBrightness(button, appearance: .aqua)
  let dark = try trashBrightness(button, appearance: .darkAqua)
  try require(dark > light + 0.5, "Trash glyph must become light in dark mode")
  button.highlight(true)
  let highlighted = try trashBrightness(button, appearance: .darkAqua)
  try require(highlighted > light + 0.5, "Highlighted trash remains visible in dark mode")
  button.highlight(false)
  let switchedBack = try trashBrightness(button, appearance: .aqua)
  try require(
    abs(switchedBack - light) < 0.05, "Trash follows appearance changes without stale tint")
}

@MainActor
private func trashBrightness(_ button: NSButton, appearance: NSAppearance.Name) throws -> CGFloat {
  button.appearance = NSAppearance(named: appearance)
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 76, pixelsHigh: 76, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  bitmap.size = button.bounds.size
  NSGraphicsContext.saveGraphicsState()
  defer { NSGraphicsContext.restoreGraphicsState() }
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  button.effectiveAppearance.performAsCurrentDrawingAppearance {
    NSColor.clear.setFill()
    button.bounds.fill(using: .copy)
    button.draw(button.bounds)
  }
  var total: CGFloat = 0
  var count = 0
  for y in 0..<bitmap.pixelsHigh {
    for x in 0..<bitmap.pixelsWide {
      guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
        color.alphaComponent > 0.8
      else { continue }
      total += (color.redComponent + color.greenComponent + color.blueComponent) / 3
      count += 1
    }
  }
  try require(count > 10, "Trash rendering contains opaque glyph pixels")
  return total / CGFloat(count)
}
