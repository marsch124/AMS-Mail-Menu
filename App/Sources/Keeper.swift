import AppKit
import Darwin
import MailMenuCore
import ServiceManagement
import SwiftUI

// Open at login + the keeper. Same design as AMS Mic Check (Keeper.swift, rules in its Core).
// The rules (`OneCopy`, `Keeper`) are in Core (KeeperRules.swift), with their tests.

/// "Open at login" looks after itself: what you asked for is remembered, and put right at every start.
enum LoginItem {
    static let wantedKey = "wantsOpenAtLogin"

    /// Returns one line about the state, for the log.
    static func checkAtStart() -> String {
        let store = UserDefaults.standard
        let status = SMAppService.mainApp.status
        if store.object(forKey: wantedKey) == nil { store.set(status == .enabled, forKey: wantedKey) }
        guard store.bool(forKey: wantedKey) else { return "open at login: off" }
        switch status {
        case .enabled: return "open at login: on"
        case .requiresApproval: return "open at login: waits for your yes in System Settings, Login Items"
        default:
            try? SMAppService.mainApp.register()
            return SMAppService.mainApp.status == .enabled
                ? "open at login: the Mac had dropped it; switched on again"
                : "open at login: the Mac had dropped it and switching it on again did not work"
        }
    }
}

/// The keeper at work: writes the start order down for the Mac, looks whether the Mac knows it, and lets a
/// copy opened by hand give way to the copy the keeper opens.
enum KeeperJob {
    static var file: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(Keeper.label).plist")
    }
    private static var domain: String { "gui/\(getuid())" }
    private static var service: String { "\(domain)/\(Keeper.label)" }

    static var openedByKeeper: Bool { CommandLine.arguments.contains(Keeper.argument) }
    static var plain: Bool { CommandLine.arguments.contains(Keeper.plainArgument) }
    /// A copy in a build folder never becomes the one the Mac opens at login.
    static var inApplications: Bool { Bundle.main.bundlePath.contains("/Applications/") }

    /// What "Open at login" was last set to; never set = what the Mac's login list says.
    static var wanted: Bool {
        UserDefaults.standard.object(forKey: LoginItem.wantedKey) as? Bool ?? (SMAppService.mainApp.status == .enabled)
    }

    @discardableResult
    private static func launchctl(_ arguments: [String]) -> (code: Int32, text: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return (-1, "") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return (task.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }

    /// The Mac knows the start order (for this login).
    static var loaded: Bool { launchctl(["print", service]).code == 0 }
    /// The keeper's own copy of the app is running.
    private static var running: Bool {
        let answer = launchctl(["print", service])
        return answer.code == 0 && answer.text.contains("state = running")
    }

    /// Writes the start order if it is missing or out of date. Returns: is it right now, and was it rewritten.
    @discardableResult
    static func writeFile() -> (right: Bool, changed: Bool) {
        guard inApplications, let executable = Bundle.main.executablePath, let id = Bundle.main.bundleIdentifier else {
            return (false, false)
        }
        let order = Keeper.plist(executable: executable, bundleID: id) as NSDictionary
        if let now = NSDictionary(contentsOf: file), now.isEqual(order) { return (true, false) }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? PropertyListSerialization.data(fromPropertyList: order, format: .xml, options: 0),
              (try? data.write(to: file, options: .atomic)) != nil else { return (false, false) }
        return (true, true)
    }

    /// "Open at login" was switched off: the start order goes too.
    static func remove() {
        // Telling the Mac to forget it would stop the copy the keeper itself opened; that copy only removes
        // the file, and the Mac forgets the rest at the next login.
        if !openedByKeeper { launchctl(["bootout", service]) }
        try? FileManager.default.removeItem(at: file)
    }

    /// A copy opened by hand asks the keeper to open its own copy. True when that copy is running, so this one
    /// can quit; false when the keeper did not answer, so this one carries on by itself.
    static func handOver() -> Bool {
        let written = writeFile()
        guard written.right else { return false }
        if written.changed, loaded { launchctl(["bootout", service]) }
        if !loaded { launchctl(["bootstrap", domain, file.path]) }
        launchctl(["kickstart", service])
        for _ in 0..<15 {
            if running { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }

    /// One line about the keeper, for the log.
    static func stateLine() -> String {
        guard wanted else { return "keeper: off" }
        guard inApplications else { return "keeper: not used outside Applications" }
        let fileThere = FileManager.default.fileExists(atPath: file.path)
        return fileThere && loaded ? "keeper: in place" : "keeper: could not be set up"
    }

    // MARK: Only one copy

    /// When a program started, from the Mac itself.
    static func started(pid: pid_t) -> Double? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&name, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        let time = info.kp_proc.p_starttime
        return Double(time.tv_sec) + Double(time.tv_usec) / 1_000_000
    }

    /// The other copies of this app that started before this one.
    static func earlierCopies() -> [OneCopy.Copy] {
        let mine = getpid()
        guard let id = Bundle.main.bundleIdentifier, let myStart = started(pid: mine) else { return [] }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .map(\.processIdentifier).filter { $0 != mine && $0 > 0 }
            .compactMap { pid in started(pid: pid).map { OneCopy.Copy(started: $0, pid: pid) } }
        return OneCopy.earlier(than: OneCopy.Copy(started: myStart, pid: mine), among: others)
    }

    /// True when this copy has to quit because an earlier one stays.
    static func mustQuitForEarlierCopy() -> Bool {
        var earlier = earlierCopies()
        guard !earlier.isEmpty else { return false }
        guard openedByKeeper else { return true }
        for _ in 0..<15 {
            Thread.sleep(forTimeInterval: 0.2)
            earlier = earlier.filter { kill($0.pid, 0) == 0 }
            if earlier.isEmpty { return false }
        }
        return true
    }
}

/// What the app does once at its start. Call `KeeperStartup.begin()` first thing in the App's `init()`.
enum KeeperStartup {
    private static var stopSignal: DispatchSourceSignal?

    static func begin() {
        // Only one copy in the menu bar: the one that started first stays.
        if KeeperJob.mustQuitForEarlierCopy() { exit(0) }
        // "Open at login" is on: the app runs as the keeper's copy. A copy opened by hand gives way to it.
        if Keeper.handsOver(wanted: KeeperJob.wanted, openedByKeeper: KeeperJob.openedByKeeper,
                            plain: KeeperJob.plain, inApplications: KeeperJob.inApplications) {
            if KeeperJob.handOver() { exit(0) }
        } else if KeeperJob.openedByKeeper {
            KeeperJob.writeFile()
        }
        _ = LoginItem.checkAtStart()
        // A polite stop from outside (the Mac shutting down, an update) ends the app cleanly, like Quit,
        // so the keeper does not open it again.
        signal(SIGTERM, SIG_IGN)
        let stop = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        stop.setEventHandler { exit(0) }
        stop.resume()
        stopSignal = stop
    }
}

/// The "Open at login" switch for a settings screen.
struct OpenAtLoginSection: View {
    @State private var openAtLogin = KeeperJob.wanted

    var body: some View {
        Section("Start") {
            Toggle("Open at login", isOn: $openAtLogin)
                .onChange(of: openAtLogin) { _, wanted in
                    UserDefaults.standard.set(wanted, forKey: LoginItem.wantedKey)
                    if wanted { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
                    let real = SMAppService.mainApp.status == .enabled
                    if real != wanted { openAtLogin = real }
                    // The keeper follows the switch: its start order is written or removed with it.
                    if wanted { KeeperJob.writeFile() } else { KeeperJob.remove() }
                }
                .accessibilityIdentifier("openAtLoginToggle")
            Text("While this is on, the app also comes back by itself if it ever stops unexpectedly.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
