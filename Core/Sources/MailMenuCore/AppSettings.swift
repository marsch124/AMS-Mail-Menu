import Foundation

/// Where an email opens when clicked.
public enum OpenTarget: String, CaseIterable, Identifiable {
    case appWindow
    case appleMail
    case spark

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .appWindow: return "Small window in this app"
        case .appleMail: return "Apple Mail, at that email"
        case .spark: return "Spark (only brings Spark to the front)"
        }
    }
}

/// Keys and defaults for the settings (stored in the Mac's user defaults).
public enum SettingsKey {
    public static let emailCount = "emailCount"
    public static let showPreview = "showPreview"
    public static let showAccount = "showAccount"
    public static let menuBarStyle = "menuBarStyle"
    public static let menuBarShowTime = "menuBarShowTime"
    public static let openTarget = "openTarget"
    public static let refreshSeconds = "refreshSeconds"
}

public enum SettingsDefault {
    public static let emailCount = 20
    public static let showPreview = true
    public static let showAccount = true
    public static let menuBarStyle = MenuBarStyle.blueFill.rawValue
    public static let menuBarShowTime = true
    public static let openTarget = OpenTarget.appWindow.rawValue
    public static let refreshSeconds = 60
}

/// Colour family for the small account dot: iCloud blue, Gmail orange, others grey.
public enum AccountKind: Equatable {
    case iCloud, gmail, other

    /// Decided from the account's name as set in Apple Mail (e.g. "iCloud", "Google", "Gmail").
    public static func from(accountName: String) -> AccountKind {
        let n = accountName.lowercased()
        if n.contains("icloud") { return .iCloud }
        if n.contains("gmail") || n.contains("google") { return .gmail }
        return .other
    }
}

/// How the menu bar icon shows that new (unread) mail is waiting.
public enum MenuBarStyle: String, CaseIterable, Identifiable {
    case blueFill, count, dot

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .blueFill: return "Turns blue"
        case .count: return "Shows the count"
        case .dot: return "Dot only"
        }
    }
}
