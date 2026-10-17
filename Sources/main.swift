import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let overlay = OverlayController()
  private let renameWindow = RenameWindowController()
  private let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLoginItem), keyEquivalent: "")

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem.button?.image = NSImage(systemSymbolName: "flag", accessibilityDescription: "Space Names")

    let menu = NSMenu()
    menu.delegate = self
    menu.addItem(withTitle: "Rename Desktops…", action: #selector(showRenameWindow), keyEquivalent: ",")
    menu.addItem(.separator())
    menu.addItem(loginItem)
    menu.addItem(.separator())
    menu.addItem(withTitle: "Quit Space Names", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    menu.items.forEach { if $0.action != #selector(NSApplication.terminate(_:)) { $0.target = self } }
    statusItem.menu = menu

    // Accessibility is the only permission needed: it lets us read where Mission Control draws each desktop.
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    AXIsProcessTrustedWithOptions(options)

    overlay.start()
  }

  func menuWillOpen(_ menu: NSMenu) {
    loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
  }

  @objc private func showRenameWindow() {
    renameWindow.show()
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
