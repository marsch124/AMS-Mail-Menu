import MailMenuCore
import AppKit
import Foundation

/// Talks to Apple Mail through AppleScript. Never starts Mail by itself.
enum MailReader {
    static let mailBundleID = "com.apple.mail"

    static var isMailRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: mailBundleID).isEmpty
    }

    /// Runs a script. Must be called on the main thread (NSAppleScript is not thread-safe).
    static func run(_ source: String) -> Result<NSAppleEventDescriptor, MailAccessProblem> {
        guard isMailRunning else { return .failure(.mailNotRunning) }
        guard let script = NSAppleScript(source: source) else {
            return .failure(.other("Internal error: script could not be created."))
        }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let number = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
            let message = (errorInfo[NSAppleScript.errorMessage] as? String) ?? ""
            return .failure(MailAccessProblem.from(errorNumber: number, message: message))
        }
        return .success(result)
    }

    /// Opens Mail without bringing it to the front.
    static func launchMailHidden() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: mailBundleID) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.hides = true
        NSWorkspace.shared.openApplication(at: url, configuration: config)
    }

    /// Opens System Settings at Privacy & Security → Automation.
    static func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}
