import MailMenuCore
import AppKit
import Foundation

/// Talks to Apple Mail through AppleScript. Never starts Mail by itself.
enum MailReader {
    static let mailBundleID = "com.apple.mail"

    static var isMailRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: mailBundleID).isEmpty
    }

    /// Every script runs here, one after another, never on the main thread: a slow answer from Mail
    /// must not freeze the list. (NSAppleScript must not run twice at the same time.)
    private static let queue = DispatchQueue(label: "com.schabbauer.AMSMailMenu.mail", qos: .userInitiated)

    /// Runs a script and waits for the answer. For one quick action (archive, delete, mark as read).
    static func run(_ source: String) -> Result<NSAppleEventDescriptor, MailAccessProblem> {
        queue.sync { execute(source) }
    }

    /// Runs a script in the background and hands the answer back on the main thread.
    static func runInBackground(_ source: String,
                                then: @escaping @MainActor (Result<NSAppleEventDescriptor, MailAccessProblem>) -> Void) {
        queue.async {
            let result = execute(source)
            DispatchQueue.main.async { MainActor.assumeIsolated { then(result) } }
        }
    }

    private static func execute(_ source: String) -> Result<NSAppleEventDescriptor, MailAccessProblem> {
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
