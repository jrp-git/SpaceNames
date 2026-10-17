import Cocoa

/// The Spaces bar of one display, as the Dock exposes it through Accessibility while
/// Mission Control is open. All rects are in Accessibility coordinates (top-left origin).
struct SpacesBar {
  let displayFrame: CGRect
  let buttonFrames: [CGRect]
  /// Index of the highlighted (blue-banded) space, if any.
  let selectedIndex: Int?
}

/// Reads Mission Control's layout from the Dock's accessibility tree.
final class MissionControlReader {
  private var dockPID: pid_t = 0
  private var dock: AXUIElement?

  /// Returns nil when Mission Control is not open.
  func spacesBars() -> [SpacesBar]? {
    guard let dock = dockElement(),
          let mc = children(dock).first(where: { identifier($0) == "mc" }) else { return nil }

    return children(mc).filter { identifier($0) == "mc.display" }.map { display in
      let list = children(display)
        .filter { identifier($0) == "mc.spaces" }
        .flatMap(children)
        .first { identifier($0) == "mc.spaces.list" }
      let buttons = list.map(children) ?? []
      let selected = list.flatMap { attribute($0, kAXSelectedChildrenAttribute) as? [AXUIElement] }?.first
      return SpacesBar(displayFrame: frame(display),
                       buttonFrames: buttons.map(frame),
                       selectedIndex: selected.flatMap { s in buttons.firstIndex { CFEqual($0, s) } })
    }
  }

  private func dockElement() -> AXUIElement? {
    // Re-resolve if the Dock restarted.
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
      return nil
    }
    if app.processIdentifier != dockPID {
      dockPID = app.processIdentifier
      dock = AXUIElementCreateApplication(dockPID)
    }
    return dock
  }

  private func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
  }

  private func children(_ element: AXUIElement) -> [AXUIElement] {
    attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
  }

  private func identifier(_ element: AXUIElement) -> String {
    attribute(element, kAXIdentifierAttribute) as? String ?? ""
  }

  private func frame(_ element: AXUIElement) -> CGRect {
    var origin = CGPoint.zero
    var size = CGSize.zero
    if let value = attribute(element, kAXPositionAttribute) { AXValueGetValue(value as! AXValue, .cgPoint, &origin) }
    if let value = attribute(element, kAXSizeAttribute) { AXValueGetValue(value as! AXValue, .cgSize, &size) }
    return CGRect(origin: origin, size: size)
  }
}
