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
                Text("No emails in your inboxes.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
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
                .frame(maxHeight: 560)
            }
            footer
        }
        .frame(width: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Mail").font(.system(size: 15, weight: .bold))
            AccountKey(kind: .iCloud, name: "iCloud")
            AccountKey(kind: .gmail, name: "Gmail")
            Spacer()
            Text("Newest \(emailCount)").font(.caption).foregroundStyle(.secondary)
            Button {
                openWindow(id: "triage")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Triage", systemImage: "tray.and.arrow.down")
            }
            .buttonStyle(.borderless)
            .help("Go through the emails one by one: delete, archive, file, or send to PARAGON")
        }
        .padding(.horizontal, 4)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if let error = store.actionError {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text(error).font(.callout).fixedSize(horizontal: false, vertical: true)
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
                        .fontWeight(.semibold)
                }
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.11)))
                .padding(.horizontal, 4)
            }
            footerBar
        }
    }

    private var footerBar: some View {
        HStack(spacing: 12) {
            if store.isLoading {
                Text("Reading Mail…")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("readingMail")
            } else if let last = store.lastRefresh {
                Text("Checked \(last.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
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
        case .iCloud: return Color(red: 0.04, green: 0.36, blue: 0.77)   // #0A5BC4
        case .gmail: return Color(red: 0.76, green: 0.25, blue: 0.05)    // #C2410C
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
            Text(name).font(.caption).foregroundStyle(.secondary)
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
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                        Text(group.sender.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(group.sender.displayName), \(group.messages.count) emails, \(isOpen ? "open" : "closed")")

                if group.unreadCount > 0 {
                    if isOpen {
                        Button("Mark all read") { store.markRead(group.messages) }
                            .font(.system(size: 12, weight: .semibold))
                            .buttonStyle(.borderless)
                    }
                    Text("\(group.unreadCount) new")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 3)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.15)))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text("\(group.messages.count) read")
                        .font(.caption)
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
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08)))
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
                    .font(.system(size: 13, weight: message.isRead ? .regular : .semibold))
                    .lineLimit(1)
                Spacer()
                if hovering {
                    actionButtons
                } else {
                    Text(timeText).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            if showPreview, let preview = message.preview, !preview.isEmpty {
                Text(preview)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 4)
        .background(hovering ? Color.accentColor.opacity(0.10) : Color.clear)
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
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
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
            Text(problem.title).font(.headline)
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
