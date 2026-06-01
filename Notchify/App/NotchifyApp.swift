import SwiftUI

@main
struct NotchifyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The real UI (island overlay + preferences window) is managed by the
        // AppDelegate via AppKit. This placeholder satisfies SwiftUI's
        // requirement for at least one scene and is never presented.
        Settings { EmptyView() }
    }
}

