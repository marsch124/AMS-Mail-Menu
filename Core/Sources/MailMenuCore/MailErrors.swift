import Foundation

/// Problems talking to Apple Mail, with plain-language explanations.
public enum MailAccessProblem: Error, Equatable {
    case mailNotRunning
    case permissionDenied
    case permissionNotYetAsked
    /// Mail did not answer in time (AppleScript -1712).
    case mailBusy
    case other(String)

    /// AppleScript error numbers that mean "not allowed".
    /// -1743: the user refused Automation access. -1744: permission would need to be asked first.
    public static func from(errorNumber: Int, message: String) -> MailAccessProblem {
        switch errorNumber {
        case -1743: return .permissionDenied
        case -1744: return .permissionNotYetAsked
        case -600, -609: return .mailNotRunning
        case -1712: return .mailBusy
        default: return .other(message.isEmpty ? "Error \(errorNumber)" : message)
        }
    }

    public var title: String {
        switch self {
        case .mailNotRunning: return "Apple Mail is not open"
        case .permissionDenied: return "Access to Mail is turned off"
        case .permissionNotYetAsked: return "Access to Mail is needed"
        case .mailBusy: return "Apple Mail is busy"
        case .other: return "Mail could not be read"
        }
    }

    /// The hint shown when the pointer rests on the menu bar icon: the heading, then what to do.
    public var hoverText: String { "\(title)\n\(explanation)" }

    public var explanation: String {
        switch self {
        case .mailNotRunning:
            return "This app reads your emails from Apple Mail. Please open Mail (it may stay hidden)."
        case .permissionDenied:
            return "To fix it: System Settings → Privacy & Security → Automation → AMS Mail Menu → switch on “Mail”."
        case .permissionNotYetAsked:
            return "Click “Refresh”. macOS will ask whether AMS Mail Menu may control Mail. Please click “Allow”."
        case .mailBusy:
            return "Mail did not answer in time. It may still be fetching your mail. The list tries again by itself."
        case .other(let text):
            return text
        }
    }
}
