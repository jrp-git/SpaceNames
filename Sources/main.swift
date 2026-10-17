import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private static let opacities: [Double] = [0.25, 0.5, 0.75, 1.0]
  private static let durations: [Double] = [0.5, 1.0, 1.5, 2.0, 3.0]

  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let overlay = OverlayController()
  private var switchBanner: SwitchBanner?
  private let renameWindow = RenameWindowController()
  private let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
  private let bannerItem = NSMenuItem(title: "Show Name When Switching", action: #selector(toggleBanner), keyEquivalent: "")
  private var opacityItems: [NSMenuItem] = []
  private var durationItems: [NSMenuItem] = []

  func applicationDidFinishLaunching(_ notification: Notification) {
    SwitchBannerSettings.registerDefaults()
    statusItem.button?.image = NSImage(systemSymbolName: "flag", accessibilityDescription: "Space Names")

    opacityItems = Self.opacities.map { value in
      let item = NSMenuItem(title: "\(Int(value * 100))%", action: #selector(setOpacity), keyEquivalent: "")
      item.representedObject = value
      return item
    }
    durationItems = Self.durations.map { value in
      let item = NSMenuItem(title: value.formatted() + " s", action: #selector(setDuration), keyEquivalent: "")
      item.representedObject = value
      return item
    }

    let menu = NSMenu()
    menu.delegate = self
    menu.addItem(withTitle: "Rename Desktops…", action: #selector(showRenameWindow), keyEquivalent: ",")
    menu.addItem(.separator())
    menu.addItem(bannerItem)
    menu.addItem(submenuItem("Name Opacity", items: opacityItems))
    menu.addItem(submenuItem("Fade Duration", items: durationItems))
    menu.addItem(.separator())
    menu.addItem(loginItem)
    menu.addItem(.separator())
    menu.addItem(withTitle: "Quit Space Names", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    for item in menu.items + opacityItems + durationItems where item.action != #selector(NSApplication.terminate(_:)) {
      item.target = self
    }
    statusItem.menu = menu

    // Accessibility is the only permission needed: it lets us read where Mission Control draws each desktop.
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    AXIsProcessTrustedWithOptions(options)

    overlay.start()
    switchBanner = SwitchBanner { [weak self] in self?.overlay.isMissionControlRecentlyOpen ?? false }
  }

  private func submenuItem(_ title: String, items: [NSMenuItem]) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    let submenu = NSMenu()
    items.forEach(submenu.addItem)
    item.submenu = submenu
    return item
  }

  func menuWillOpen(_ menu: NSMenu) {
    loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    bannerItem.state = SwitchBannerSettings.isEnabled ? .on : .off
    for item in opacityItems {
      item.state = item.representedObject as? Double == SwitchBannerSettings.opacity ? .on : .off
    }
    for item in durationItems {
      item.state = item.representedObject as? Double == SwitchBannerSettings.duration ? .on : .off
    }
  }

  @objc private func showRenameWindow() {
    renameWindow.show()
  }

  @objc private func toggleBanner() {
    SwitchBannerSettings.isEnabled.toggle()
  }

  @objc private func setOpacity(_ sender: NSMenuItem) {
    if let value = sender.representedObject as? Double { SwitchBannerSettings.opacity = value }
  }

  @objc private func setDuration(_ sender: NSMenuItem) {
    if let value = sender.representedObject as? Double { SwitchBannerSettings.duration = value }
  }

  @objc private func toggleLoginItem() {
    do {
      if SMAppService.mainApp.status == .enabled {
        try SMAppService.mainApp.unregister()
      } else {
        try SMAppService.mainApp.register()
      }
    } catch {
      NSAlert(error: error).runModal()
    }
  }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
