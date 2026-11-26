import MailMenuCore
import AppKit
import Darwin
import Foundation

/// Talks to Apple Mail through AppleScript. Never starts Mail by itself.
enum MailReader {
    static let mailBundleID = "com.apple.mail"

    private static var lastMailPID: pid_t = 0

    static var isMailRunning: Bool {
        if let mail = NSRunningApplication.runningApplications(withBundleIdentifier: mailBundleID).first {
            lastMailPID = mail.processIdentifier
            return true
        }
        // The Mac's list of running apps is now and then empty for an instant while Mail is open (seen
        // 23 Nov 2026: "Apple Mail is not open" after 0.0 s, twice in two minutes). The process itself is
        // the proof: the one last seen as Mail is still alive and still is Mail.
        guard lastMailPID > 0, kill(lastMailPID, 0) == 0 else { return false }
        var path = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(lastMailPID, &path, UInt32(path.count)) > 0 else { return false }
        return String(cString: path).hasSuffix("/Mail.app/Contents/MacOS/Mail")
    }

    // Asking Mail is only quick from a program's main thread: the answers arrive there. From any other
    // thread each answer waits until the main thread happens to look (measured 23 Nov 2026: 0.8 s on the
    // main thread, 30 to 40 s from a background queue). So there are two ways to run a script:
    //  - `run`: on the main thread, waiting. For one quick action (archive, delete, mark as read).
    //  - `runInBackground`: in a helper copy of this app (`--worker`), which runs the script on ITS main
    //    thread at full speed while this app's window stays free. For the regular reading and the first lines.

    /// Runs a script on the main thread and waits for the answer.
    static func run(_ source: String) -> Result<NSAppleEventDescriptor, MailAccessProblem> {
        execute(source)
    }

    /// Runs a script in a helper copy of the app and hands the answer back on the main thread.
    @MainActor
    static func runInBackground(_ source: String,
                                then: @escaping @MainActor (Result<NSAppleEventDescriptor, MailAccessProblem>) -> Void) {
        // Asked here, on the main thread: from a background thread the Mac sometimes answers "not open"
        // while Mail is open (seen 23 Nov 2026: the first lines stopped after two).
        guard isMailRunning else { then(.failure(.mailNotRunning)); return }
        DispatchQueue.global(qos: .userInitiated).async {
            let result = runInWorker(source)
            DispatchQueue.main.async { MainActor.assumeIsolated { then(result) } }
        }
    }

    /// Starts the helper copy, gives it the script, waits for its answer. Never call on the main thread
    /// of the app with its window open (the self-check does, on purpose).
    static func runInWorker(_ source: String) -> Result<NSAppleEventDescriptor, MailAccessProblem> {
        guard let program = Bundle.main.executableURL else { return .failure(.other("Internal error: the app could not find itself.")) }
        let worker = Process()
        worker.executableURL = program
        worker.arguments = [Worker.argument]
        let input = Pipe(), output = Pipe()
        worker.standardInput = input
        worker.standardOutput = output
        worker.standardError = FileHandle.nullDevice
        do { try worker.run() } catch { return .failure(.other("Internal error: the helper could not be started.")) }
        input.fileHandleForWriting.write(Data(source.utf8))
        try? input.fileHandleForWriting.close()
        let answer = output.fileHandleForReading.readDataToEndOfFile()
        worker.waitUntilExit()
        return Worker.decode(answer)
    }

    fileprivate static func execute(_ source: String) -> Result<NSAppleEventDescriptor, MailAccessProblem> {
        guard isMailRunning else { return .failure(.mailNotRunning) }
        guard let script = NSAppleScript(source: source) else {
            return .failure(.other("Internal error: script could not be created."))
        }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let number = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
            let message = (errorInfo[NSAppleScript.errorMessage] as? String) ?? ""
            return .failure(.from(errorNumber: number, message: message))
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

    /// Opens Mail and brings it to the front (two-finger menu, "Open Apple Mail").
    static func openMailInFront() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: mailBundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Opens System Settings at Privacy & Security → Automation.
    static func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// The helper copy of the app: started with `--worker`, it reads one script from its input, runs it on its
/// main thread, writes the answer to its output and ends. It never shows anything.
enum Worker {
    static let argument = "--worker"

    private struct Answer: Codable {
        var ok: Bool
        var reply: Data?        // Mail's answer, packed
        var number: Int?
        var message: String?
    }

    static func runIfAsked() {
        guard CommandLine.arguments.contains(argument) else { return }
        let source = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""
        var answer: Answer
        guard MailReader.isMailRunning, let script = NSAppleScript(source: source) else {
            answer = Answer(ok: false, number: -600, message: "")
            FileHandle.standardOutput.write((try? JSONEncoder().encode(answer)) ?? Data())
            exit(0)
        }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            answer = Answer(ok: false, number: (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0,
                            message: (errorInfo[NSAppleScript.errorMessage] as? String) ?? "")
        } else if let packed = pack(result) {
            answer = Answer(ok: true, reply: packed)
        } else {
            answer = Answer(ok: false, number: 0, message: "Internal error: Mail's answer could not be passed on.")
        }
        FileHandle.standardOutput.write((try? JSONEncoder().encode(answer)) ?? Data())
        exit(0)
    }

    static func decode(_ data: Data) -> Result<NSAppleEventDescriptor, MailAccessProblem> {
        guard let answer = try? JSONDecoder().decode(Answer.self, from: data) else {
            return .failure(.other("Internal error: the helper gave no answer."))
        }
        if answer.ok, let reply = answer.reply, let descriptor = unpack(reply) { return .success(descriptor) }
        if answer.ok { return .failure(.other("Internal error: Mail's answer could not be read back.")) }
        return .failure(.from(errorNumber: answer.number ?? 0, message: answer.message ?? ""))
    }

    /// Mail's answer as plain bytes (Apple's own packing for such answers).
    private static func pack(_ descriptor: NSAppleEventDescriptor) -> Data? {
        guard let desc = descriptor.aeDesc else { return nil }
        let size = AESizeOfFlattenedDesc(desc)
        guard size > 0 else { return nil }
        var data = Data(count: size)
        var actual = 0
        let status = data.withUnsafeMutableBytes { buffer in
            AEFlattenDesc(desc, buffer.baseAddress!.assumingMemoryBound(to: CChar.self), size, &actual)
        }
        return status == noErr ? data.prefix(actual) : nil
    }

    private static func unpack(_ data: Data) -> NSAppleEventDescriptor? {
        var desc = AEDesc()
        let status = data.withUnsafeBytes { buffer in
            AEUnflattenDescFromBytes(buffer.baseAddress!, data.count, &desc)
        }
        guard status == noErr else { return nil }
        return NSAppleEventDescriptor(aeDescNoCopy: &desc)
    }
}
