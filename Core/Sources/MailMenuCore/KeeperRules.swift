import Foundation

// Rules for "only one copy" and the keeper. Same design as AMS Mic Check.

/// Only one copy of the app may sit in the menu bar.
public enum OneCopy {
    public struct Copy: Equatable {
        public let started: Double
        public let pid: Int32
        public init(started: Double, pid: Int32) { self.started = started; self.pid = pid }
    }

    /// The copies that started before `me`. Same start time: the smaller process number counts as earlier.
    public static func earlier(than me: Copy, among others: [Copy]) -> [Copy] {
        others.filter { $0.started < me.started || ($0.started == me.started && $0.pid < me.pid) }
    }
}

/// The keeper: a second start order with the Mac, apart from the Mac's own login list. It opens the app at
/// every login and opens it again when it stops unexpectedly.
public enum Keeper {
    public static let label = "com.schabbauer.AMSMailMenu.keeper"
    /// How a copy knows the keeper opened it.
    public static let argument = "--keeper"
    /// For checks: a copy opened with this never hands itself over to the keeper.
    public static let plainArgument = "--plain"

    /// The start order as the Mac wants it written down.
    public static func plist(executable: String, bundleID: String) -> [String: Any] {
        [
            "Label": label,
            "ProgramArguments": [executable, argument],
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false],
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua",
            "AssociatedBundleIdentifiers": [bundleID],
        ]
    }

    /// A copy opened by hand (or by the Mac's login list) gives way to the keeper, but only while
    /// "Open at login" is on and the app sits in an Applications folder.
    public static func handsOver(wanted: Bool, openedByKeeper: Bool, plain: Bool, inApplications: Bool) -> Bool {
        wanted && !openedByKeeper && !plain && inApplications
    }
}
