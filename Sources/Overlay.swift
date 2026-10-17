import Cocoa

/// Black flag that hangs below a desktop thumbnail, with rounded bottom corners.
/// When the desktop is selected, Mission Control's blue band is continued around the flag.
final class FlagView: NSView {
  static let height: CGFloat = 24
  /// Mission Control's selection band: 3pt stroke, 1pt gap from the thumbnail.
  static let bandWidth: CGFloat = 3
  static let bandGap: CGFloat = 1
  static var bandOutset: CGFloat { bandWidth + bandGap }
  private static let bandColor = NSColor(srgbRed: 0x3B / 255, green: 0x99 / 255, blue: 0xFC / 255, alpha: 1)
  private static let cornerRadius: CGFloat = 6
  private static let font = NSFont.systemFont(ofSize: 12, weight: .medium)

  var text = "" {
    didSet { if text != oldValue { needsDisplay = true } }
  }

  var isSelected = false {
    didSet { if isSelected != oldValue { needsDisplay = true } }
  }

  /// Rect open at the top with rounded bottom corners (view is not flipped: y = 0 is the bottom).
  private static func flagPath(_ rect: NSRect, radius r: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: rect.minX, y: rect.maxY))
    path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
    path.line(to: NSPoint(x: rect.maxX, y: rect.minY + r))
    path.appendArc(withCenter: NSPoint(x: rect.maxX - r, y: rect.minY + r), radius: r, startAngle: 0, endAngle: 270, clockwise: true)
    path.line(to: NSPoint(x: rect.minX + r, y: rect.minY))
    path.appendArc(withCenter: NSPoint(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: 270, endAngle: 180, clockwise: true)
    path.close()
    return path
  }

  override func draw(_ dirtyRect: NSRect) {
    var flagRect = bounds
    if isSelected {
      // Band ring concentric with the flag; the 1pt gap stays transparent like Mission Control's.
      let outset = Self.bandOutset
      flagRect = NSRect(x: outset, y: outset, width: bounds.width - 2 * outset, height: bounds.height - outset)
      let ring = Self.flagPath(bounds, radius: Self.cornerRadius + outset)
      let gapRect = NSRect(x: Self.bandWidth, y: Self.bandWidth,
                           width: bounds.width - 2 * Self.bandWidth, height: bounds.height - Self.bandWidth)
      ring.append(Self.flagPath(gapRect, radius: Self.cornerRadius + Self.bandGap))
      ring.windingRule = .evenOdd
      Self.bandColor.setFill()
      ring.fill()
    }

    NSColor.black.setFill()
    Self.flagPath(flagRect, radius: Self.cornerRadius).fill()

    let style = NSMutableParagraphStyle()
    style.alignment = .center
    style.lineBreakMode = .byTruncatingTail
    let attributes: [NSAttributedString.Key: Any] = [.font: Self.font, .foregroundColor: NSColor.white, .paragraphStyle: style]
    let lineHeight = ceil(Self.font.ascender - Self.font.descender)
    let textRect = NSRect(x: flagRect.minX + 6, y: flagRect.minY + (flagRect.height - lineHeight) / 2,
                          width: flagRect.width - 12, height: lineHeight)
    (text as NSString).draw(with: textRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes)
  }
}

/// Watches for Mission Control and shows a flag under every renamed desktop.
final class OverlayController {
  private static let idleInterval: TimeInterval = 0.15
  private static let activeInterval: TimeInterval = 1.0 / 60
  private static let spacesRefreshInterval: TimeInterval = 0.25

  private let reader = MissionControlReader()
  private var flags: [String: (window: NSWindow, view: FlagView)] = [:]
  private var timer: Timer?
  private var isActive = false
  private var closedAt = Date.distantPast
  private var cachedSpaces: [DisplaySpaces] = []

  /// True while Mission Control is open or was closed moments ago (e.g. by clicking a desktop).
  var isMissionControlRecentlyOpen: Bool {
    isActive || Date().timeIntervalSince(closedAt) < 1
  }
  private var spacesReadAt = Date.distantPast

  func start() {
    schedule(interval: Self.idleInterval)
  }

  private func schedule(interval: TimeInterval) {
    timer?.invalidate()
    let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.tick() }
    timer.tolerance = interval * 0.2
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  private func tick() {
    guard AXIsProcessTrusted(), let bars = reader.spacesBars() else {
      if isActive {
        isActive = false
        closedAt = Date()
        flags.values.forEach { $0.window.orderOut(nil) }
        schedule(interval: Self.idleInterval)
      }
      return
    }
    let justOpened = !isActive
    if justOpened {
      isActive = true
      spacesReadAt = .distantPast
      schedule(interval: Self.activeInterval)
    }
    update(bars, fadeIn: justOpened)
  }

  private func update(_ bars: [SpacesBar], fadeIn: Bool) {
    // Spaces can be added, removed or reordered while Mission Control is open.
    if Date().timeIntervalSince(spacesReadAt) > Self.spacesRefreshInterval {
      cachedSpaces = Spaces.current()
      spacesReadAt = Date()
    }
    let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
    var shown = Set<String>()

    for bar in bars {
      guard let screen = NSScreen.screens.first(where: { $0.axFrame.integral == bar.displayFrame.integral }),
            let uuid = screen.displayUUID else { continue }
      // With "Displays have separate Spaces" off there is a single entry for all displays.
      guard let display = cachedSpaces.first(where: { $0.displayUUID == uuid })
              ?? (cachedSpaces.count == 1 ? cachedSpaces[0] : nil),
            display.spaces.count == bar.buttonFrames.count else { continue }

      for (index, (space, button)) in zip(display.spaces, bar.buttonFrames).enumerated() {
        guard let name = NameStore.shared.name(for: space.key) else { continue }
        let selected = index == bar.selectedIndex
        var frame = NSRect(x: button.minX, y: primaryHeight - button.maxY - FlagView.height,
                           width: button.width, height: FlagView.height)
        if selected {
          // Make room for the band on the sides and bottom; the top stays flush with the thumbnail.
          let outset = FlagView.bandOutset
          frame = NSRect(x: frame.minX - outset, y: frame.minY - outset,
                         width: frame.width + 2 * outset, height: frame.height + outset)
        }
        show(name, key: space.key, frame: frame, selected: selected, fadeIn: fadeIn)
        shown.insert(space.key)
      }
    }

    for (key, flag) in flags where !shown.contains(key) {
      flag.window.orderOut(nil)
    }
  }

  private func show(_ name: String, key: String, frame: NSRect, selected: Bool, fadeIn: Bool) {
    let flag = flags[key] ?? makeFlag(key: key)
    flag.view.text = name
    flag.view.isSelected = selected
    if flag.window.frame != frame {
      flag.window.setFrame(frame, display: true)
    }
    if !flag.window.isVisible {
      flag.window.alphaValue = fadeIn ? 0 : 1
      flag.window.orderFrontRegardless()
      if fadeIn {
        NSAnimationContext.runAnimationGroup { context in
          context.duration = 0.2
          flag.window.animator().alphaValue = 1
        }
      }
    }
  }

  private func makeFlag(key: String) -> (window: NSWindow, view: FlagView) {
    let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
    window.level = .popUpMenu
    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.ignoresMouseEvents = true
    window.isReleasedWhenClosed = false
    let view = FlagView()
    window.contentView = view
    flags[key] = (window, view)
    return (window, view)
  }
}
