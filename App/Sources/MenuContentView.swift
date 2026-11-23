import MailMenuCore
import SwiftUI

/// The panel that drops down from the menu bar icon (layout: Martin's drawing 3).
struct MenuContentView: View {
    @EnvironmentObject private var store: MailStore
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.emailCount) private var emailCount = SettingsDefault.emailCount
    @AppStorage(SettingsKey.showPreview) private var showPreview = SettingsDefault.showPreview
    @AppStorage(SettingsKey.showAccount) private var showAccount = SettingsDefault.showAccount

    /// Senders the user folded open or closed by hand. Others: open if they have new mail.
    @State private var manuallyOpen: Set<String> = []
    @State private var manuallyClosed: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let problem = store.problem {
                ProblemView(problem: problem)
            } else if store.groups.isEmpty {
                Text(store.lastRefresh == nil ? "Reading Mail…" : "No emails in your inboxes.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(store.groups) { group in
                            SenderCard(group: group,
                                       isOpen: isOpen(group),
                                       showPreview: showPreview,
                                       showAccount: showAccount,
                                       toggle: { toggle(group) })
                        }
                    }
                    .padding(.horizontal, 4)
                }
                // No scroll bar: on a Mac set to always show them it took 15 of the 260 points.
                .scrollIndicators(.never)
                // As tall as its emails, up to 560; without this the list area collapses to nothing.
                .frame(maxHeight: 560)
                .fixedSize(horizontal: false, vertical: true)
            }
            footer
        }
        // The only empty space in the panel: its round corners would cut into the words otherwise.
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .frame(width: Look.panelWidth)
        .tint(.mailBlue)
        .font(Look.f(13))
        .background(Color(nsColor: .windowBackgroundColor))
    }

    /// The heading row. In a narrow list the words "Newest 20" give way, so nothing ever wraps.
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            headerRow(showCount: true)
            headerRow(showCount: false)
        }
        .padding(.horizontal, 4)
    }

    private func headerRow(showCount: Bool) -> some View {
        HStack(spacing: 8) {
            Text("Mail").font(Look.f(15, .bold)).fixedSize()
            AccountKey(kind: .iCloud, name: "iCloud")
            AccountKey(kind: .gmail, name: "Gmail")
            Spacer(minLength: 4)
            if showCount {
                Text("Newest \(emailCount)").font(Look.f(10)).foregroundStyle(.secondary).fixedSize()
            }
            Button {
                SelfCheck.closePanel()
                openWindow(id: "triage")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                // A small filled button (the owner, 23 Nov 2026: "Make Triage into a small button").
                // Drawn by hand, so it is full colour even when the panel is not the front window.
                Text("Triage")
                    .font(Look.f(12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.mailButtonBlue))
                    .contentShape(Capsule())
                    .fixedSize()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("triageButton")
            .help("Go through the emails one by one: delete, archive, file, or send to PARAGON")
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if let error = store.actionError {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text(error).font(Look.f(12)).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button { store.actionError = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Close message")
                }
                .padding(.horizontal, 4)
            }
            if let undo = store.undoInfo {
                HStack(spacing: 10) {
                    Text(undo.text).lineLimit(1)
                    Spacer()
                    Button("Undo") { store.undoLast() }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color(red: 0.56, green: 0.76, blue: 1.0))
                }
                .font(Look.f(13))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color(white: 0.11)))
                .padding(.horizontal, 4)
            }
            footerBar
        }
    }

    private var footerBar: some View {
        HStack(spacing: 12) {
            if let note = store.workNote {
                Text(note)
                    .font(Look.f(10)).foregroundStyle(.secondary)
                    .accessibilityIdentifier("workNote")
            } else if store.isLoading {
                Text("Reading Mail…")
                    .font(Look.f(10)).foregroundStyle(.secondary)
                    .accessibilityIdentifier("readingMail")
            } else if let last = store.lastRefresh {
                Text("Checked \(last.formatted(date: .omitted, time: .shortened))")
                    .font(Look.f(10)).foregroundStyle(.secondary)
            }
            Spacer()
            Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }
                .help("Check now")
            SettingsLink { Image(systemName: "gearshape") }
                .help("Settings")
            Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                .help("Quit AMS Mail Menu")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 4)
        .overlay(alignment: .top) { Divider() }
    }

    private func isOpen(_ group: SenderGroup) -> Bool {
        if manuallyOpen.contains(group.key) { return true }
        if manuallyClosed.contains(group.key) { return false }
        return group.unreadCount > 0
    }

    private func toggle(_ group: SenderGroup) {
        if isOpen(group) {
            manuallyOpen.remove(group.key)
            manuallyClosed.insert(group.key)
        } else {
            manuallyClosed.remove(group.key)
            manuallyOpen.insert(group.key)
        }
    }
}

extension AccountKind {
    var color: Color {
        switch self {
        // Never blue, never orange: blue is the app's own colour (what you can press, headings, new mail)
        // and orange is the warning. Before 0.8 iCloud was blue and Gmail orange; a blue dot on every
        // line also read as "unread", as in Apple Mail.
        case .iCloud: return .accountViolet
        case .gmail: return .accountGreen
        case .other: return Color.secondary
        }
    }
}

struct AccountKey: View {
    let kind: AccountKind
    let name: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(kind.color).frame(width: 8, height: 8)
            Text(name).font(Look.f(10)).foregroundStyle(.secondary).fixedSize()
        }
    }
}

/// One sender as a rounded card with a fold chevron and an "N new" tag.
struct SenderCard: View {
    let group: SenderGroup
    let isOpen: Bool
    let showPreview: Bool
    let showAccount: Bool
    let toggle: () -> Void
    @EnvironmentObject private var store: MailStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button(action: toggle) {
                    HStack(spacing: 8) {
                        Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                            .font(Look.f(10, .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                        Text(group.sender.displayName)
                            .font(Look.f(14))
                            .lineLimit(1)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(group.sender.displayName), \(group.messages.count) emails, \(isOpen ? "open" : "closed")")

                if group.unreadCount > 0 {
                    if isOpen {
                        // "Mark read", not "Mark all read": in the 260-point list the longer words left
                        // the sender's name only eight letters ("Martin S…").
                        Button("Mark read") { store.markRead(group.messages) }
                            .help("Mark all emails of this sender as read")
                            .font(Look.f(12))
                            .buttonStyle(.borderless)
                    }
                    Text("\(group.unreadCount) new")
                        .font(Look.f(11))
                        .padding(.horizontal, 3)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.mailBlue.opacity(0.15)))
                        .foregroundStyle(Color.mailBlue)
                } else {
                    Text("\(group.messages.count) read")
                        .font(Look.f(10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)

            if isOpen {
                ForEach(group.messages) { message in
                    Divider()
                    MessageRow(message: message, showPreview: showPreview, showAccount: showAccount)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.primary.opacity(0.08)))
    }
}

/// One email line. Hovering shows action buttons; right-click shows a menu with the same actions.
struct MessageRow: View {
    let message: MailMessage
    let showPreview: Bool
    let showAccount: Bool
    @EnvironmentObject private var store: MailStore
    @Environment(\.openWindow) private var openWindow
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 7) {
                if showAccount {
                    Circle()
                        .fill(AccountKind.from(accountName: message.accountName).color)
                        .frame(width: 8, height: 8)
                        .help(message.accountName)
                }
                Text(message.subject.isEmpty ? "(no subject)" : message.subject)
                    // No bold (the owner: "Not bold - it looks terrible"). New mail: full-strength letters; read: grey.
                    .font(Look.f(13))
                    .foregroundStyle(message.isRead ? Color.secondary : Color.primary)
                    .lineLimit(1)
                Spacer()
                if hovering {
                    actionButtons
                } else {
                    Text(timeText).font(Look.f(12)).foregroundStyle(.secondary)
                }
            }
            if showPreview, let preview = message.preview, !preview.isEmpty {
                Text(preview)
                    .font(Look.f(12.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    // Starts under the subject, not under the account dot (dot 8 + gap 7).
                    .padding(.leading, showAccount ? 15 : 0)
            }
        }
        .padding(.horizontal, 4)
        .background(hovering ? Color.mailBlue.opacity(0.10) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { store.open(message) { openWindow(id: $0) } }
        .contextMenu {
            Button("Open") { store.openInWindow(message) { openWindow(id: $0) } }
            Button("Open in Apple Mail") { store.openInAppleMail(message) }
            Button("Open in Spark (brings Spark forward)") { MailStore.bringSparkForward() }
            Divider()
            Button("Reply") { store.reply(message) }
            if !message.isRead {
                Button("Mark as read") { store.markRead([message]) }
            }
            Button("Archive") { store.archive(message) }
            Button("Delete") { store.delete(message) }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 4) {
            if !message.isRead {
                RowButton(symbol: "checkmark", label: "Mark as read") { store.markRead([message]) }
            }
            RowButton(symbol: "arrowshape.turn.up.left", label: "Reply") { store.reply(message) }
            RowButton(symbol: "archivebox", label: "Archive") { store.archive(message) }
            RowButton(symbol: "trash", label: "Delete", tint: .red) { store.delete(message) }
        }
    }

    private var timeText: String {
        if Calendar.current.isDateInToday(message.dateReceived) {
            return message.dateReceived.formatted(date: .omitted, time: .shortened)
        }
        return message.dateReceived.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}

/// Small square icon button used on a hovered email line.
struct RowButton: View {
    let symbol: String
    let label: String
    var tint: Color = .mailBlue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(Look.f(12, .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.15)))
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

struct ProblemView: View {
    let problem: MailAccessProblem
    @EnvironmentObject private var store: MailStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(problem.title).font(Look.f(14))
            Text(problem.explanation).fixedSize(horizontal: false, vertical: true)
            HStack {
                switch problem {
                case .mailNotRunning:
                    Button("Open Mail (hidden)") {
                        MailReader.launchMailHidden()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { store.refresh() }
                    }
                case .permissionDenied:
                    Button("Open System Settings") { MailReader.openAutomationSettings() }
                default:
                    EmptyView()
                }
                Button("Try again") { store.refresh() }
            }
        }
        .padding(.horizontal, 4)
    }
}
