import SwiftUI
import AppKit

@main
struct WorkManagerApp: App {
    private let environment = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            MainSplitView(environment: environment)
                .frame(minWidth: 850, minHeight: 550)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .appInfo) {
                Button("WorkManager 정보") {
                    NSApp.orderFrontStandardAboutPanel()
                }
            }
        }
    }
}
