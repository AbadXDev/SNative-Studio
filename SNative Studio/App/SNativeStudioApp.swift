import SwiftUI

@main
struct SNativeStudioApp: App {
    @State private var studio = StudioViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(studio: studio)
                .preferredColorScheme(studio.settings.appearance.colorScheme)
                .frame(minWidth: 920, minHeight: 620)
        }
        .defaultSize(width: 1120, height: 740)
        .commands {
            SidebarCommands()
        }
    }
}
