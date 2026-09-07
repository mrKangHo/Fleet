import SwiftUI
import AppKit

@main
struct WorkManagerApp: App {
    private let environment = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            MainSplitView(environment: environment)
                .frame(minWidth: 850, minHeight: 550)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .appInfo) {
                Button("WorkManager 정보") {
                    NSApp.orderFrontStandardAboutPanel()
                }
            }
        }

        MenuBarExtra("WorkManager", systemImage: "sparkles.rectangle.stack") {
            MenuBarExtraView(environment: environment)
                .preferredColorScheme(.dark)
        }
        .menuBarExtraStyle(.window)
    }
}
