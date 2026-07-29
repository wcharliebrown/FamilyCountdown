import SwiftUI

/// Locks the app to landscape (station-board display). Info.plist orientation
/// keys aren't reliably enforced on their own, so we answer authoritatively here.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .landscape
    }
}

@main
struct FamilyCountdownApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = EventStore()
    @StateObject private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(settings)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                .onAppear {
                    // Kiosk / station-board: never dim or sleep.
                    UIApplication.shared.isIdleTimerDisabled = true
                    forceLandscape()
                }
        }
    }

    private func forceLandscape() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
    }
}
