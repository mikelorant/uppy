import AppKit
import UppyCore

@MainActor
enum UppyCheckIcons {
  static func image(for type: HealthCheckType) -> NSImage {
    if type == .tcp { return ethernetPort() }
    let symbol = type == .http ? "globe" : "cable.connector"
    return NSImage(systemSymbolName: symbol, accessibilityDescription: type.rawValue) ?? NSImage()
  }

  private static func ethernetPort() -> NSImage {
    let image = NSImage(size: NSSize(width: 24, height: 24), flipped: false) { _ in
      NSColor.black.setStroke()
      let frame = NSBezierPath(
        roundedRect: NSRect(x: 2, y: 2, width: 20, height: 20), xRadius: 1, yRadius: 1)
      frame.lineWidth = 1.8
      frame.stroke()

      let socket = NSBezierPath()
      socket.move(to: NSPoint(x: 6, y: 16))
      socket.line(to: NSPoint(x: 18, y: 16))
      socket.line(to: NSPoint(x: 18, y: 9))
      socket.line(to: NSPoint(x: 15, y: 9))
      socket.line(to: NSPoint(x: 15, y: 6))
      socket.line(to: NSPoint(x: 9, y: 6))
      socket.line(to: NSPoint(x: 9, y: 9))
      socket.line(to: NSPoint(x: 6, y: 9))
      socket.close()
      socket.lineWidth = 1.8
      socket.stroke()
      return true
    }
    image.isTemplate = true
    image.accessibilityDescription = "TCP Ethernet port"
    return image
  }
}
