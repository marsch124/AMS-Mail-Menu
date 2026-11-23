import MailMenuCore
import SwiftUI

/// The Settings window: three tabs and Done (Escape closes too).
/// The tabs are the app's own row of three, not the Mac's tab bar: that one writes the chosen tab in the
/// Mac's highlight colour (yellow on white on the owner's Mac) and leaves an empty band above.
struct SettingsView: View {
    @State private var tab = "settings"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Page", selection: $tab) {
                Text("Settings").tag("settings")
                Text("How it works").tag("guide")
                Text("What's new").tag("news")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("settingsTabs")
            Group {
                switch tab {
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
            Toggle("Show the account as a coloured dot (iCloud blue, Gmail orange)", isOn: $showAccount)
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
        Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}
