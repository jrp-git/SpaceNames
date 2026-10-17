import Cocoa

/// One Space as macOS orders it on a display (same order as the Mission Control bar).
struct Space {
  /// Stable identifier used to store the custom name.
  let key: String
  /// The "Desktop N" number macOS shows; nil for full-screen app spaces.
  let desktopNumber: Int?

  var defaultTitle: String { desktopNumber.map { "Desktop \($0)" } ?? "Full-screen app" }
}

struct DisplaySpaces {
  let displayUUID: String
  let spaces: [Space]
}

enum Spaces {
  /// Reads the current Spaces for every display. Read-only; no SIP changes needed.
  static func current() -> [DisplaySpaces] {
    guard let raw = CGSCopyManagedDisplaySpaces(CGSMainConnectionID())?.takeRetainedValue() as? [[String: Any]] else {
      return []
    }
    var desktopCounter = 0
    return raw.map { monitor in
      let spaces = (monitor["Spaces"] as? [[String: Any]] ?? []).map { space -> Space in
        let uuid = space["uuid"] as? String ?? ""
        let managedID = space["ManagedSpaceID"] as? Int ?? 0
        // The original desktop on the main display has an empty uuid; fall back to its ID.
        let key = uuid.isEmpty ? "id:\(managedID)" : uuid
        let isDesktop = (space["type"] as? Int ?? 0) == 0
        if isDesktop { desktopCounter += 1 }
        return Space(key: key, desktopNumber: isDesktop ? desktopCounter : nil)
      }
      return DisplaySpaces(displayUUID: monitor["Display Identifier"] as? String ?? "", spaces: spaces)
    }
  }
}

extension NSScreen {
  var displayUUID: String? {
    guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
          let uuid = CGDisplayCreateUUIDFromDisplayID(number)?.takeRetainedValue() else { return nil }
    return CFUUIDCreateString(nil, uuid) as String
  }

  /// Frame in Accessibility / Quartz coordinates (origin at top-left of the primary display).
  var axFrame: CGRect {
    let primaryHeight = NSScreen.screens.first?.frame.height ?? frame.height
    return CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
  }
}

/// Custom names, persisted in UserDefaults and keyed by `Space.key`.
final class NameStore: ObservableObject {
  static let shared = NameStore()
  private static let defaultsKey = "spaceNames"

  @Published var names: [String: String] {
    didSet { UserDefaults.standard.set(names, forKey: Self.defaultsKey) }
  }

  private init() {
    names = UserDefaults.standard.dictionary(forKey: Self.defaultsKey) as? [String: String] ?? [:]
  }

  func name(for key: String) -> String? {
    guard let name = names[key]?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return nil }
    return name
  }
}
