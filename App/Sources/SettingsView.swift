import MailMenuCore
import SwiftUI

/// The Settings window: four tabs and Done (Escape closes too).
/// The tabs are the app's own row of four, not the Mac's tab bar: that one writes the chosen tab in the
/// Mac's highlight colour (yellow on white on the owner's Mac) and leaves an empty band above.
struct SettingsView: View {
    @State private var tab: String

    /// `tab`: the page to open on ("settings", "gmail", "guide", "news"); the test pictures use it.
    init(tab: String = "settings") {
        _tab = State(initialValue: tab)
    }

    /// Asks the open Settings window to show a page (the object is the page's word, e.g. "gmail").
    static let showTab = Notification.Name("com.schabbauer.AMSMailMenu.settingsTab")

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Page", selection: $tab) {
                Text("Settings").tag("settings")
                Text("Gmail").tag("gmail")
                Text("How it works").tag("guide")
                Text("What's new").tag("news")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("settingsTabs")
            Group {
                switch tab {
                case "gmail": GmailSettingsView()
                case "guide": ScrollView { GuideView().padding(.horizontal, 4) }
                case "news": ScrollView { WhatsNewView().padding(.horizontal, 4) }
                default: GeneralSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            HStack {
                VersionLine()
                Spacer()
                Button("Done") { NSApp.keyWindow?.close() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("settingsDone")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Self.showTab)) { notice in
            if let wanted = notice.object as? String { tab = wanted }
        }
        .padding(6)     // the window's round corners would cut into the words otherwise
        .frame(width: 480, height: 440)
    }
}

/// The Settings tab: plain rows, no boxes, no empty space (the owner: "take away all padding").
/// Every change counts at once.
struct GeneralSettingsView: View {
    @EnvironmentObject private var store: MailStore
    @AppStorage(SettingsKey.emailCount) private var emailCount = SettingsDefault.emailCount
    @AppStorage(SettingsKey.showPreview) private var showPreview = SettingsDefault.showPreview
    @AppStorage(SettingsKey.showAccount) private var showAccount = SettingsDefault.showAccount
    @AppStorage(SettingsKey.menuBarStyle) private var menuBarStyle = SettingsDefault.menuBarStyle
    @AppStorage(SettingsKey.menuBarShowTime) private var menuBarShowTime = SettingsDefault.menuBarShowTime
    @AppStorage(SettingsKey.openTarget) private var openTarget = SettingsDefault.openTarget
    @AppStorage(SettingsKey.refreshSeconds) private var refreshSeconds = SettingsDefault.refreshSeconds

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            heading("List")
            Stepper("Show the newest \(emailCount) emails", value: $emailCount, in: 5...100, step: 5)
            Toggle("Show the first line of text", isOn: $showPreview)
            note("The first lines appear a moment after the list, one by one: Mail has to open each email for them.")
            Toggle("Show the account as a coloured dot (iCloud violet, Gmail green)", isOn: $showAccount)
            Divider()

            heading("Menu bar icon")
            Picker("While new mail waits, the icon", selection: $menuBarStyle) {
                ForEach(MenuBarStyle.allCases) { style in
                    Text(style.label).tag(style.rawValue)
                }
            }
            .fixedSize()
            Toggle("Show the time of the newest new email next to the icon", isOn: $menuBarShowTime)
            Divider()

            heading("Clicking an email opens it in")
            Picker("Open in", selection: $openTarget) {
                ForEach(OpenTarget.allCases) { target in
                    Text(target.label).tag(target.rawValue)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            if openTarget == OpenTarget.spark.rawValue {
                note("Spark cannot be told by another app which email to show. This choice only brings Spark to the front.")
            }
            Divider()

            heading("Checking for new mail")
            Picker("Check every", selection: $refreshSeconds) {
                Text("30 seconds").tag(30)
                Text("1 minute").tag(60)
                Text("2 minutes").tag(120)
                Text("5 minutes").tag(300)
            }
            .fixedSize()
            Divider()

            OpenAtLoginSection()
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: emailCount) { store.refresh() }
        .onChange(of: showPreview) { store.refresh() }
        .onChange(of: refreshSeconds) { store.restartTimer() }
    }

    private func heading(_ text: String) -> some View {
        Text(text).foregroundStyle(Color.mailBlue)
    }

    private func note(_ text: String) -> some View {
        Text(text).font(Look.f(11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

/// The Gmail tab (0.9): the direct connection that archives a Gmail email at Gmail itself.
/// The status is told in words; the app password is never shown and goes only into the Mac's Keychain.
struct GmailSettingsView: View {
    @EnvironmentObject private var store: MailStore
    @AppStorage(SettingsKey.gmailAddress) private var savedAddress = ""
    @AppStorage(SettingsKey.gmailMailAccount) private var savedAccount = ""
    @AppStorage(SettingsKey.gmailConnected) private var connected = false
    @State private var address = ""
    @State private var password = ""
    @State private var account = ""
    @State private var asking = false
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Gmail connection").foregroundStyle(Color.mailBlue)
            note("Apple Mail does not pass an Archive from this app on to Gmail. With this connection the app archives a Gmail email straight at Gmail: it leaves the inbox and stays in “All Mail”, as with Archive in Gmail itself.")
            Divider()
            if connected {
                Text("Connected to Gmail as \(savedAddress).")
                    .accessibilityIdentifier("gmailStatus")
                Text("Archive on an email of the Mail account “\(savedAccount)” goes straight to Gmail.")
                    .fixedSize(horizontal: false, vertical: true)
                Button("Disconnect") {
                    GmailConnection.disconnect()
                    password = ""
                    problem = nil
                }
                .accessibilityIdentifier("gmailDisconnect")
                note("Disconnect removes the app password from this Mac's Keychain. Archiving a Gmail email then stops working until you connect again.")
            } else {
                Text("Not connected.")
                    .accessibilityIdentifier("gmailStatus")
                Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 4) {
                    GridRow {
                        Text("Gmail address")
                        TextField("name@gmail.com", text: $address)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("gmailAddress")
                    }
                    GridRow {
                        Text("App password")
                        SecureField("the 16 letters from Google", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("gmailPassword")
                    }
                    GridRow {
                        Text("Account in Mail")
                        accountChoice
                    }
                }
                note("The app password is not your Google password. Google makes it for you: open the page below, give it the name “AMS Mail Menu”, and paste the 16 letters here. For this, 2-Step Verification must be on in your Google account.")
                Button("Open Google's app password page") {
                    if let page = URL(string: "https://myaccount.google.com/apppasswords") { NSWorkspace.shared.open(page) }
                }
                .buttonStyle(.link)
                .accessibilityIdentifier("gmailOpenGoogle")
                note("The app password is kept in this Mac's Keychain and is sent only to Google, on an encrypted line.")
                HStack {
                    Button("Connect") { connect() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("gmailConnect")
                    if asking { Text("Asking Gmail…").foregroundStyle(.secondary) }
                }
            }
            if let problem {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text(problem).fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("gmailProblem")
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if address.isEmpty { address = savedAddress }
            if account.isEmpty { account = savedAccount.isEmpty ? proposedAccount : savedAccount }
        }
    }

    /// The accounts the inboxes belong to; typed by hand while Mail has not been read yet.
    @ViewBuilder private var accountChoice: some View {
        let names = store.accountNames
        if names.isEmpty {
            TextField("the account's name in Apple Mail", text: $account).textFieldStyle(.roundedBorder)
        } else {
            Picker("Account in Mail", selection: $account) {
                ForEach(names, id: \.self) { Text($0).tag($0) }
                if !names.contains(account) { Text(account.isEmpty ? "Choose" : account).tag(account) }
            }
            .labelsHidden()
            .fixedSize()
            .accessibilityIdentifier("gmailAccount")
        }
    }

    /// The Mail account that looks like Gmail by its name.
    private var proposedAccount: String {
        let names = store.accountNames
        return names.first { AccountKind.from(accountName: $0) == .gmail }
            ?? names.first { AccountKind.from(accountName: $0) != .iCloud }
            ?? "Gmail"
    }

    private func connect() {
        let who = address.trimmingCharacters(in: .whitespaces)
        guard !who.isEmpty, !password.isEmpty, !account.isEmpty else {
            problem = "Fill in the Gmail address and the app password first."
            return
        }
        guard !asking else { return }
        asking = true
        problem = nil
        Task {
            do {
                try await GmailConnection.connect(address: who, password: password, mailAccount: account)
                password = ""
            } catch {
                problem = GmailConnection.words(for: error)
            }
            asking = false
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(Look.f(11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}
