import Foundation

/// The time of the newest new email in the menu bar, as two small lines (the owner's pick A, 26 Nov 2026):
/// the hour with the colon on top, the minutes below, always two digits — "08:" over "09".
public enum MenuBarTime {
    public static func lines(_ date: Date, calendar: Calendar = .current) -> (top: String, bottom: String) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (String(format: "%02d:", parts.hour ?? 0), String(format: "%02d", parts.minute ?? 0))
    }
}
