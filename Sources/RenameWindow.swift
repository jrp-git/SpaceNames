import Cocoa
import SwiftUI

private struct DisplaySection: Identifiable {
  let id: String
  let title: String
  let spaces: [Space]
}

private struct RenameView: View {
  @ObservedObject var store = NameStore.shared
  let sections: [DisplaySection]

  var body: some View {
    Form {
      ForEach(sections) { section in
        Section(section.title) {
          ForEach(section.spaces, id: \.key) { space in
            TextField(space.defaultTitle, text: binding(for: space.key), prompt: Text(space.defaultTitle))
          }
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 380)
    .fixedSize(horizontal: false, vertical: true)
  }

  private func binding(for key: String) -> Binding<String> {
    Binding(get: { store.names[key] ?? "" }, set: { store.names[key] = $0 })
  }
}

/// Small settings-style window listing every desktop with a name field.
final class RenameWindowController {
  private var window: NSWindow?

  func show() {
    let sections = Spaces.current().enumerated().map { index, display in
      let screenName = NSScreen.screens.first(where: { $0.displayUUID == display.displayUUID })?.localizedName
      return DisplaySection(id: display.displayUUID,
                            title: screenName ?? "Display \(index + 1)",
                            spaces: display.spaces.filter { $0.desktopNumber != nil })
    }

    let window = self.window ?? {
      let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
      window.title = "Desktop Names"
      window.isReleasedWhenClosed = false
      self.window = window
      return window
    }()
    window.contentViewController = NSHostingController(rootView: RenameView(sections: sections))
    window.center()
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }
}
