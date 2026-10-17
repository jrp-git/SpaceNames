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
  /// Key of the space currently shown on this display.
  let currentKey: String?
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
        let isDesktop = (space["type"] as? Int ?? 0) == 0
        if isDesktop { desktopCounter += 1 }
        return Space(key: key(for: space), desktopNumber: isDesktop ? desktopCounter : nil)
      }
      return DisplaySpaces(displayUUID: monitor["Display Identifier"] as? String ?? "",
                           spaces: spaces,
                           currentKey: (monitor["Current Space"] as? [String: Any]).map(key))
    }
  }

  private static func key(for space: [String: Any]) -> String {
    let uuid = space["uuid"] as? String ?? ""
    // The original desktop on the main display has an empty uuid; fall back to its ID.
    return uuid.isEmpty ? "id:\(space["ManagedSpaceID"] as? Int ?? 0)" : uuid
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

/// Options for the name shown when switching spaces, set from the menu bar menu.
enum SwitchBannerSettings {
  static let enabledKey = "switchBannerEnabled"
  static let opacityKey = "switchBannerOpacity"
  static let durationKey = "switchBannerDuration"

  static func registerDefaults() {
    UserDefaults.standard.register(defaults: [enabledKey: true, opacityKey: 0.5, durationKey: 1.0])
  }

  static var isEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: enabledKey) }
    set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
  }

  static var opacity: Double {
    get { UserDefaults.standard.double(forKey: opacityKey) }
    set { UserDefaults.standard.set(newValue, forKey: opacityKey) }
  }

  static var duration: Double {
    get { UserDefaults.standard.double(forKey: durationKey) }
    set { UserDefaults.standard.set(newValue, forKey: durationKey) }
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
