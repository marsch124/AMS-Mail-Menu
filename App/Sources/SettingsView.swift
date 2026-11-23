import MailMenuCore
import SwiftUI

/// The Settings window: three tabs.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Text("Settings") }
            ScrollView { GuideView().padding(16) }
                .tabItem { Text("How it works") }
            ScrollView { WhatsNewView().padding(16) }
                .tabItem { Text("What's new") }
        }
        .frame(width: 480, height: 560)
    }
}

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
        Form {
            Section("List") {
                Stepper("Show the newest \(emailCount) emails", value: $emailCount, in: 5...100, step: 5)
                Toggle("Show the first line of text", isOn: $showPreview)
                Toggle("Show the account (coloured dot: iCloud blue, Gmail orange)", isOn: $showAccount)
            }
            Section("Menu bar icon") {
                Picker("While new mail waits, the icon", selection: $menuBarStyle) {
                    ForEach(MenuBarStyle.allCases) { style in
                        Text(style.label).tag(style.rawValue)
                    }
                }
                Toggle("Show the time of the newest new email next to the icon", isOn: $menuBarShowTime)
            }
            Section("Clicking an email opens it in") {
                Picker("Open in", selection: $openTarget) {
                    ForEach(OpenTarget.allCases) { target in
                        Text(target.label).tag(target.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                if openTarget == OpenTarget.spark.rawValue {
                    Text("Spark cannot be told by another app which email to show. This choice only brings Spark to the front.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Checking for new mail") {
                Picker("Check every", selection: $refreshSeconds) {
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("2 minutes").tag(120)
                    Text("5 minutes").tag(300)
                }
            }
            OpenAtLoginSection()
            Section {
                VersionLine()
            }
        }
        .formStyle(.grouped)
        .onChange(of: emailCount) { store.refresh() }
        .onChange(of: showPreview) { store.refresh() }
        .onChange(of: refreshSeconds) { store.restartTimer() }
    }
}
