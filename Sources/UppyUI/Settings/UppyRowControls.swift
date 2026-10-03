import AppKit

/// A six-dot grip drawn directly so it never depends on SF Symbol availability.
final class UppyDragGripView: NSView {
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func draw(_ dirtyRect: NSRect) {
    NSColor.labelColor.setFill()
    for x in [-2.7, 2.7] {
      for y in [-5.4, 0.0, 5.4] {
        NSBezierPath(
          ovalIn: NSRect(
            x: bounds.midX + x - 1.35,
            y: bounds.midY + y - 1.35,
            width: 2.7,
            height: 2.7
          )
        ).fill()
      }
    }
  }
}

/// Retains native button actions and accessibility with the mock's square surface.
final class UppyRowActionButton: NSButton {
  var showsSurface = true

  // Native button alignment insets can vary by glyph; these custom surfaces do not.
  override var alignmentRectInsets: NSEdgeInsets {
    NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
  }

  override var intrinsicContentSize: NSSize {
    NSSize(width: 37.8, height: 37.8)
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }

  override func draw(_ dirtyRect: NSRect) {
    if showsSurface {
      NSColor.labelColor.withAlphaComponent(isHighlighted ? 0.14 : 0.06).setFill()
      let side: CGFloat = 36
      let surface = NSRect(
        x: bounds.midX - side / 2, y: bounds.midY - side / 2, width: side, height: side)
      NSBezierPath(roundedRect: surface, xRadius: 9, yRadius: 9).fill()
    }
    if let image {
      let rect = NSRect(x: bounds.midX - 9.9, y: bounds.midY - 9.9, width: 19.8, height: 19.8)
      // Drawing an NSImage directly bypasses NSButton's template-image tinting.
      let tint = contentTintColor ?? .labelColor
      let glyph = NSImage(size: rect.size, flipped: false) { bounds in
        image.draw(in: bounds)
        tint.setFill()
        bounds.fill(using: .sourceIn)
        return true
      }
      glyph.draw(
        in: rect,
        from: .zero,
        operation: .sourceOver,
        fraction: isEnabled ? 1 : 0.4,
        respectFlipped: true,
        hints: nil
      )
    }
  }
}
