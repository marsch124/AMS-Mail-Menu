import MailMenuCore
import SwiftUI

/// The small window inside the app that shows one email (Martin's drawing 5).
/// Opening marks the email as read; Escape closes; "Keep on top" keeps it above other windows.
struct MessageWindowView: View {
    @EnvironmentObject private var store: MailStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("keepWindowOnTop") private var keepOnTop = true
    @State private var window: NSWindow?

    var body: some View {
        Group {
            if let message = store.selectedMessage {
                content(for: message)
            } else {
                Text("No email selected.").padding(.horizontal, 4)
            }
        }
        .frame(minWidth: 420, minHeight: 360)
        .background(WindowFinder(window: $window))
        .onChange(of: keepOnTop) { applyLevel() }
        .onChange(of: window) { applyLevel() }
        // Escape closes the window.
        .background(
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .hidden()
        )
    }

    private func content(for message: MailMessage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Toggle("Keep on top", isOn: $keepOnTop)
                    .toggleStyle(.checkbox)
                    .font(.caption)
            }
            .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(message.subject.isEmpty ? "(no subject)" : message.subject)
                    .font(.system(size: 19))
                    .textSelection(.enabled)
                HStack(spacing: 10) {
                    Text(initials(message.sender.displayName))
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color(red: 0.71, green: 0.33, blue: 0.16)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(senderLine(message)).font(.system(size: 13.5)).textSelection(.enabled)
                        Text("\(message.accountName) · \(message.dateReceived.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)

            Divider()
            ScrollView {
                Text(store.selectedContent)
                    .font(.system(size: 14))
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.horizontal, 4)
            }
            Divider()

            HStack(spacing: 8) {
                Button { store.reply(message) } label: {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                }
                .buttonStyle(.borderedProminent)
                Button("Archive") {
                    store.archive(message)
                    dismiss()
                }
                Button("Delete", role: .destructive) {
                    store.delete(message)
                    dismiss()
                }
                .tint(.red)     // red always means delete
                Spacer()
                Button("Open in Apple Mail") { store.openInAppleMail(message) }
                Button("Spark") { MailStore.bringSparkForward() }
                    .help("Brings Spark to the front. Spark cannot be told which email to show.")
            }
            .padding(.horizontal, 4)
        }
    }

    private func senderLine(_ message: MailMessage) -> String {
        let s = message.sender
        if s.name.isEmpty || s.address.isEmpty { return s.displayName }
        return "\(s.name) <\(s.address)>"
    }

    private func initials(_ name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    private func applyLevel() {
        window?.level = keepOnTop ? .floating : .normal
    }
}

/// Gives SwiftUI access to the NSWindow that holds a view (needed for "Keep on top").
struct WindowFinder: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { self.window = view.window }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if nsView.window !== window {
            DispatchQueue.main.async { self.window = nsView.window }
        }
    }
}
