import SwiftUI
import AppKit

@main
struct FleetApp: App {
    private let environment = AppEnvironment.shared
    @AppStorage("workmanager_app_language") private var appLanguageRaw: String = AppLanguage.system.rawValue

    private var appLocale: Locale {
        (AppLanguage(rawValue: appLanguageRaw) ?? .system).locale
    }

    var body: some Scene {
        WindowGroup {
            MainSplitView(environment: environment)
                .frame(minWidth: 850, minHeight: 550)
                .preferredColorScheme(.dark)
                .environment(\.locale, appLocale)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .appInfo) {
                Button("Fleet 정보") {
                    NSApp.orderFrontStandardAboutPanel()
                }
            }
        }

        MenuBarExtra("Fleet", systemImage: "sparkles.rectangle.stack") {
            MenuBarExtraView(environment: environment)
                .preferredColorScheme(.dark)
                .environment(\.locale, appLocale)
        }
        .menuBarExtraStyle(.window)
    }
}
