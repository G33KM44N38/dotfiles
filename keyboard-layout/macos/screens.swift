import AppKit
import ApplicationServices

func fail(_ message: String) -> Never {
    fputs(message + "\n", stderr)
    exit(1)
}
func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
    return value
}
func rect(_ window: AXUIElement) -> CGRect? {
    guard let p = attribute(window, kAXPositionAttribute), let s = attribute(window, kAXSizeAttribute),
          CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
    var point = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(p as! AXValue, .cgPoint, &point)
    AXValueGetValue(s as! AXValue, .cgSize, &size)
    return CGRect(origin: point, size: size)
}
let screens = NSScreen.screens.sorted {
    if $0.frame.minX != $1.frame.minX { return $0.frame.minX < $1.frame.minX }
    return $0.frame.minY > $1.frame.minY
}
let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
func axFrame(_ frame: CGRect) -> CGRect {
    CGRect(x: frame.minX, y: primaryTop - frame.maxY, width: frame.width, height: frame.height)
}
func ownerScreen(_ frame: CGRect) -> NSScreen? {
    screens.max { a, b in
        let i = frame.intersection(axFrame(a.frame)), j = frame.intersection(axFrame(b.frame))
        return (i.isNull ? 0 : i.width * i.height) < (j.isNull ? 0 : j.width * j.height)
    }
}
let args = Array(CommandLine.arguments.dropFirst())
if args == ["list"] {
    for (i, screen) in screens.enumerated() { print("\(i + 1): \(screen.localizedName) x=\(screen.frame.minX)") }
    exit(0)
}
guard args.count == 2, ["focus", "move"].contains(args[0]), let number = Int(args[1]), (1...3).contains(number) else {
    fail("Usage: screen-control focus|move 1|2|3, or screen-control list")
}
guard number <= screens.count else { fail("Screen \(number) is not connected.") }
guard AXIsProcessTrusted() else { fail("Accessibility permission is required for screen-control (or its launcher Karabiner).") }
let target = screens[number - 1]
if args[0] == "move" {
    let system = AXUIElementCreateSystemWide()
    guard let app = attribute(system, kAXFocusedApplicationAttribute),
          let window = attribute(app as! AXUIElement, kAXFocusedWindowAttribute),
          let frame = rect(window as! AXUIElement), let source = ownerScreen(frame) else { fail("No movable window is focused.") }
    let win = window as! AXUIElement
    if attribute(win, "AXFullScreen") as? Bool == true { fail("Exit native full screen before moving this window.") }
    let from = axFrame(source.visibleFrame), to = axFrame(target.visibleFrame)
    var size = CGSize(width: min(frame.width, to.width), height: min(frame.height, to.height))
    var position = CGPoint(x: to.minX + max(0, min(frame.minX - from.minX, to.width - size.width)),
                           y: to.minY + max(0, min(frame.minY - from.minY, to.height - size.height)))
    // Resize first so a window from a larger screen can fit the destination.
    if size != frame.size, let value = AXValueCreate(.cgSize, &size) {
        guard AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, value) == .success else { fail("This window cannot be resized to fit the screen.") }
    }
    guard let value = AXValueCreate(.cgPoint, &position),
          AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, value) == .success else { fail("This window cannot be moved.") }
    AXUIElementPerformAction(win, kAXRaiseAction as CFString)
} else {
    // CoreGraphics returns visible windows in front-to-back order; skip overlays.
    let visible = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    for item in visible {
        guard item[kCGWindowLayer as String] as? Int == 0,
              let pid = item[kCGWindowOwnerPID as String] as? pid_t,
              let bounds = item[kCGWindowBounds as String] as? [String: Any],
              let cgFrame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
              cgFrame.width > 1, cgFrame.height > 1,
              ownerScreen(cgFrame) == target else { continue }
        let app = AXUIElementCreateApplication(pid)
        guard let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] else { continue }
        for window in windows {
            guard attribute(window, kAXMinimizedAttribute) as? Bool != true,
                  let frame = rect(window), ownerScreen(frame) == target,
                  abs(frame.minX - cgFrame.minX) < 3, abs(frame.minY - cgFrame.minY) < 3 else { continue }
            guard AXUIElementPerformAction(window, kAXRaiseAction as CFString) == .success else { continue }
            NSRunningApplication(processIdentifier: pid)?.activate(options: [])
            let center = CGPoint(x: frame.midX, y: frame.midY)
            CGWarpMouseCursorPosition(center)
            exit(0)
        }
    }
    // Empty display: place the pointer there without clicking arbitrary content.
    let frame = axFrame(target.frame)
    CGWarpMouseCursorPosition(CGPoint(x: frame.midX, y: frame.midY))
}
