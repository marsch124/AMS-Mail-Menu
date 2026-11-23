import MailMenuCore
import SwiftUI

/// Triage: one email at a time, one key per decision.
/// D delete · A archive · F file in a Mail folder · P to PARAGON (task, then archive)
/// M mark as read · R reply · Space or → next · ← previous · Z undo · Esc close
struct TriageView: View {
    @EnvironmentObject private var store: MailStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("triageUnreadOnly") private var unreadOnly = false

    @State private var queue: [MailMessage] = []
    @State private var index = 0
    @State private var body_ = ""
    @State private var showFile = false
    @State private var showParagon = false
    @State private var done: Set<String> = []

    private var current: MailMessage? { queue.indices.contains(index) ? queue[index] : nil }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            if let message = current {
                emailView(message)
            } else {
                finished
            }
            Divider()
            keyBar
        }
        .frame(minWidth: 560, minHeight: 520)
        .onAppear(perform: start)
        .onChange(of: index) { loadBody() }
        // Opened before the first reading was done: start as soon as the emails are there.
        .onChange(of: store.lastRefresh) { if queue.isEmpty { start() } }
        .sheet(isPresented: $showFile) {
            if let message = current {
                FilePicker(message: message) { path in
                    showFile = false
                    if let path { act { store.file(message, toMailboxPath: path) } }
                }
                .environmentObject(store)
            }
        }
        .sheet(isPresented: $showParagon) {
            if let message = current {
                ParagonSheet(message: message) { sent in
                    showParagon = false
                    if sent { markDoneAndNext() }
                }
                .environmentObject(store)
            }
        }
    }

    // MARK: - Parts

    private var topBar: some View {
        HStack {
            Text("Triage").font(Look.f(14))
            if !queue.isEmpty {
                Text("\(min(index + 1, queue.count)) of \(queue.count)")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Unread only", isOn: $unreadOnly)
                .toggleStyle(.checkbox)
                .onChange(of: unreadOnly) { start() }
            Button("Start over") { start() }
        }
        .padding(.horizontal, 4)
    }

    private func emailView(_ message: MailMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle().fill(AccountKind.from(accountName: message.accountName).color).frame(width: 8, height: 8)
                Text(message.sender.displayName).font(Look.f(14))
                if !message.sender.address.isEmpty, !message.sender.name.isEmpty {
                    Text(message.sender.address).font(Look.f(11)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(message.dateReceived.formatted(date: .abbreviated, time: .shortened))
                    .font(Look.f(11)).foregroundStyle(.secondary)
            }
            Text(message.subject.isEmpty ? "(no subject)" : message.subject)
                .font(Look.f(16))
            if done.contains(message.id) {
                Label("Already handled", systemImage: "checkmark.circle").foregroundStyle(.secondary)
            }
            ScrollView {
                Text(body_)
                    .font(Look.f(14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 4)
    }

    private var finished: some View {
        VStack(spacing: 4) {
            if store.lastRefresh == nil {
                Text("Reading Mail…").font(Look.f(15)).foregroundStyle(.secondary)
            } else {
                Image(systemName: "checkmark.circle").font(Look.f(32)).foregroundStyle(Color.mailBlue)
                Text(queue.isEmpty ? "No emails to go through." : "All done.").font(Look.f(15))
            }
            Button("Close") { dismiss() }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The buttons double as the keyboard keys (no modifier key needed).
    private var keyBar: some View {
        HStack(spacing: 6) {
            KeyButton(key: "d", title: "Delete", tint: .red) { if let m = current { act { store.delete(m) } } }
            KeyButton(key: "a", title: "Archive") { if let m = current { act { store.archive(m) } } }
            KeyButton(key: "f", title: "File…") { if current != nil { showFile = true } }
            KeyButton(key: "p", title: "PARAGON…") { if current != nil { showParagon = true } }
            KeyButton(key: "m", title: "Read") { if let m = current { store.markRead([m]); next() } }
            KeyButton(key: "r", title: "Reply") { if let m = current { store.reply(m) } }
            Spacer()
            KeyButton(key: "z", title: "Undo") { store.undoLast() }
                .disabled(store.undoInfo == nil)
            KeyButton(key: .leftArrow, label: "←", title: "Back") { if index > 0 { index -= 1 } }
            KeyButton(key: .space, label: "Space", title: "Next") { next() }
            Button("") { next() }.keyboardShortcut(.rightArrow, modifiers: []).hidden().frame(width: 0)
            Button("") { dismiss() }.keyboardShortcut(.cancelAction).hidden().frame(width: 0)
        }
        .disabled(showFile || showParagon)
        .controlSize(.small)
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    // MARK: - Logic

    private func start() {
        let all = store.allMessagesNewestFirst
        queue = unreadOnly ? all.filter { !$0.isRead } : all
        index = 0
        done = []
        loadBody()
    }

    private func loadBody() {
        guard let message = current else { body_ = ""; return }
        body_ = "Loading…"
        store.loadContent(of: message) { text in
            if current?.id == message.id { body_ = text }
        }
    }

    private func act(_ action: () -> Void) {
        action()
        markDoneAndNext()
    }

    private func markDoneAndNext() {
        if let m = current { done.insert(m.id) }
        next()
    }

    private func next() {
        if index < queue.count { index += 1 }
    }
}

/// A button with its key shown, e.g. "D  Delete". Pressing the key alone presses the button.
struct KeyButton: View {
    let key: KeyEquivalent
    var label: String? = nil
    let title: String
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(label ?? String(key.character).uppercased())
                    .font(.system(size: max(9, 11 + Look.delta), design: .monospaced))
                    .padding(.horizontal, 3)
                    .background(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.secondary.opacity(0.6)))
                Text(title).fixedSize()
            }
            .foregroundStyle(tint ?? .primary)
        }
        .keyboardShortcut(key, modifiers: [])
        .help("\(title) (key \(label ?? String(key.character).uppercased()))")
    }
}

/// Choose a Mail folder of the email's account. Recently used folders come first.
struct FilePicker: View {
    let message: MailMessage
    let finish: (String?) -> Void
    @EnvironmentObject private var store: MailStore
    @State private var search = ""
    @State private var folders: [String] = []
    @State private var loading = false

    private var shown: [String] {
        let recent = store.recentFolders.filter(folders.contains)
        let rest = folders.filter { !recent.contains($0) }
        let all = recent + rest
        guard !search.isEmpty else { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("File in a folder of “\(message.accountName)”").font(Look.f(14))
            TextField("Type to find a folder", text: $search)
                .textFieldStyle(.roundedBorder)
                .onSubmit { if let first = shown.first { finish(first) } }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(shown, id: \.self) { path in
                        Button { finish(path) } label: {
                            Text(path).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
            .frame(minHeight: 240)
            if folders.isEmpty {
                Text(loading ? "Reading the folders…" : "No folders found in this account.").font(Look.f(11)).foregroundStyle(.secondary)
            }
            HStack {
                Text("Enter files in the first folder shown.").font(Look.f(11)).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { finish(nil) }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(8)     // a sheet has round corners too
        .frame(width: 380, height: 420)
        .onAppear {
            loading = true
            store.loadMailboxes(for: message.accountName) { names in
                folders = names
                loading = false
            }
        }
    }
}

/// Make a PARAGON task from the email (with #tags and a link back), then archive the email.
struct ParagonSheet: View {
    let message: MailMessage
    let finish: (Bool) -> Void
    @EnvironmentObject private var store: MailStore
    @AppStorage("paragonLastTags") private var lastTags = ""
    @State private var words = ""
    @State private var tags = ""
    @State private var choice = "inbox"
    @State private var notePath = ""

    private var target: ParagonTarget {
        switch choice {
        case "inbox": return .inbox
        case "today": return .today
        default: return notePath.isEmpty ? .inbox : .note(notePath)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("To PARAGON").font(Look.f(14))
            TextField("Task", text: $words).textFieldStyle(.roundedBorder)
            TextField("Tags, e.g. family bills", text: $tags).textFieldStyle(.roundedBorder)
            Picker("Put it in", selection: $choice) {
                Text("Inbox").tag("inbox")
                Text("Today").tag("today")
                Text("A project or note…").tag("note")
            }
            .pickerStyle(.segmented)
            if choice == "note" {
                TextField("Note path, e.g. Projects/Shed.md", text: $notePath).textFieldStyle(.roundedBorder)
                if !store.recentParagonNotes.isEmpty {
                    HStack {
                        ForEach(store.recentParagonNotes.prefix(4), id: \.self) { path in
                            Button(ParagonTarget.note(path).label) { notePath = path }
                        }
                    }
                }
            }
            Text("The task gets a link back to this email. Afterwards the email is archived.")
                .font(Look.f(11)).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { finish(false) }.keyboardShortcut(.cancelAction)
                Button("Send to PARAGON") {
                    lastTags = tags
                    finish(store.sendToParagon(message, words: words, tags: tags, target: target))
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(words.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(8)
        .frame(width: 440)
        .onAppear {
            words = ParagonLink.suggestedWords(for: message)
            tags = lastTags
        }
    }
}
