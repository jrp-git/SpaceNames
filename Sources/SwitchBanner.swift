import Cocoa

/// Shows the desktop's name across the screen when switching spaces outside Mission Control
/// (Control-←/→, trackpad swipe), then fades it out.
final class SwitchBanner {
  private let isSuppressed: () -> Bool
  private var currentKeys: [String: String] = [:]
  private var banners: [String: (window: NSWindow, label: NSTextField, generation: Int)] = [:]

  init(isSuppressed: @escaping () -> Bool) {
    self.isSuppressed = isSuppressed
    currentKeys = Self.snapshot(Spaces.current())
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(activeSpaceDidChange),
      name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
  }

  private static func snapshot(_ displays: [DisplaySpaces]) -> [String: String] {
    Dictionary(displays.compactMap { d in d.currentKey.map { (d.displayUUID, $0) } }, uniquingKeysWith: { a, _ in a })
  }

  @objc private func activeSpaceDidChange() {
    let displays = Spaces.current()
    let previous = currentKeys
    currentKeys = Self.snapshot(displays)
    guard SwitchBannerSettings.isEnabled, !isSuppressed() else { return }

    // Only the display(s) whose space actually changed.
    for display in displays {
      guard let key = display.currentKey, previous[display.displayUUID] != key,
            let name = NameStore.shared.name(for: key) else { continue }
      // With "Displays have separate Spaces" off the identifier isn't a screen UUID.
      let screen = NSScreen.screens.first { $0.displayUUID == display.displayUUID } ?? NSScreen.main
      if let screen { show(name, on: screen, displayUUID: display.displayUUID) }
    }
  }

  private func show(_ name: String, on screen: NSScreen, displayUUID: String) {
    let banner = banners[displayUUID] ?? makeBanner(displayUUID: displayUUID)
    let generation = banner.generation + 1
    banners[displayUUID]?.generation = generation

    let label = banner.label
    label.stringValue = name
    label.font = .systemFont(ofSize: min(screen.frame.width * 0.06, 140), weight: .bold)
    let height = ceil(label.intrinsicContentSize.height)
    label.frame = NSRect(x: 40, y: (screen.frame.height - height) / 2,
                         width: screen.frame.width - 80, height: height)

    let window = banner.window
    window.setFrame(screen.frame, display: true)
    window.alphaValue = SwitchBannerSettings.opacity
    window.orderFrontRegardless()

    NSAnimationContext.runAnimationGroup({ context in
      context.duration = SwitchBannerSettings.duration
      // Ease in: the name stays readable at first, then fades away quickly.
      context.timingFunction = CAMediaTimingFunction(name: .easeIn)
      window.animator().alphaValue = 0
    }, completionHandler: { [weak self] in
      // A newer switch may have restarted the banner meanwhile.
      if self?.banners[displayUUID]?.generation == generation { window.orderOut(nil) }
    })
  }

  private func makeBanner(displayUUID: String) -> (window: NSWindow, label: NSTextField, generation: Int) {
    let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
    window.level = .screenSaver
    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.ignoresMouseEvents = true
    window.isReleasedWhenClosed = false

    let label = NSTextField(labelWithString: "")
    label.textColor = .white
    label.alignment = .center
    label.lineBreakMode = .byTruncatingTail
    // A soft shadow keeps white text legible on light wallpapers.
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 12
    label.shadow = shadow
    window.contentView?.addSubview(label)

    let banner = (window: window, label: label, generation: 0)
    banners[displayUUID] = banner
    return banner
  }
}
