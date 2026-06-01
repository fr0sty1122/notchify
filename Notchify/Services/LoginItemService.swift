import Foundation
import ServiceManagement

@MainActor
final class LoginItemService {
    private let fallbackKey = "launchAtLoginFallback"

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: fallbackKey)
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: fallbackKey)
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Login item update failed: \(error.localizedDescription)")
        }
    }
}

