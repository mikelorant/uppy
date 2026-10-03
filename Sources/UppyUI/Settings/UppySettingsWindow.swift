import AppKit

/// Supplies standard text shortcuts without requiring an application Edit menu.
final class UppySettingsWindow: NSWindow {
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    guard modifiers.contains(.command),
      !modifiers.contains(.control),
      !modifiers.contains(.option),
      let editor = firstResponder as? NSTextView,
      let key = event.charactersIgnoringModifiers?.lowercased()
    else {
      return super.performKeyEquivalent(with: event)
    }

    switch key {
    case "c": editor.copy(nil)
    case "v": editor.paste(nil)
    case "x": editor.cut(nil)
    case "a": editor.selectAll(nil)
    case "z":
      if modifiers.contains(.shift) {
        if editor.undoManager?.canRedo == true { editor.undoManager?.redo() }
      } else if editor.undoManager?.canUndo == true {
        editor.undoManager?.undo()
      }
    default: return super.performKeyEquivalent(with: event)
    }
    return true
  }
}
