import Foundation

/// The hint when the pointer rests on the menu bar icon and all is well (the owner's yes, 26 Nov 2026):
/// how many new emails there are and when the newest arrived. A problem's own words win over this.
public enum MenuBarHint {
    public static func text(unread: Int, newest: Date?, calendar: Calendar = .current) -> String {
        guard unread > 0 else { return "No new emails" }
        let count = unread == 1 ? "1 new email" : "\(unread) new emails"
        guard let newest else { return count }
        let lines = MenuBarTime.lines(newest, calendar: calendar)
        return "\(count), newest at \(lines.top)\(lines.bottom)"
    }
}

/// The short menu on a two-finger click on the menu bar icon (the owner's pick, 26 Nov 2026), in its order.
/// `nil` in `layout` is a separator line.
public enum IconMenuEntry: CaseIterable {
    case checkNow, openMail, triage, settings, quit

    public var title: String {
        switch self {
        case .checkNow: return "Check for new mail now"
        case .openMail: return "Open Apple Mail"
        case .triage: return "Triage"
        case .settings: return "Settings…"
        case .quit: return "Quit AMS Mail Menu"
        }
    }

    public static let layout: [IconMenuEntry?] = [.checkNow, .openMail, .triage, .settings, nil, .quit]
}
