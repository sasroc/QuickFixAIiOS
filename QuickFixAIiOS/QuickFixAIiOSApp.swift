import SwiftUI
import FirebaseCore
import GoogleSignIn
import RevenueCat

// MARK: - App Delegate (configures Firebase and RevenueCat before any SDK usage)

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        // Explicitly configure Google Sign-In with the client ID from the
        // Firebase app (which already read GoogleService-Info.plist).
        // GoogleSignIn v8 requires this when GIDClientID is not in Info.plist.
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }

        // Configure RevenueCat. Must be called after FirebaseApp.configure()
        // so the app is fully initialised before any purchase calls are made.
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
        #if DEBUG
        Purchases.logLevel = .debug
        #endif

        return true
    }

    // Handle Google Sign-In URL when app is opened from background
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

// MARK: - App

@main
struct QuickFixAIiOSApp: App {
    // UIApplicationDelegateAdaptor registers AppDelegate early enough that
    // applicationDidFinishLaunchingWithOptions (which calls FirebaseApp.configure())
    // is guaranteed to run before any .task {} modifiers in the view body.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @State private var authVM             = AuthViewModel()
    @State private var userVM             = UserViewModel()
    @State private var repairVM           = RepairViewModel()
    @State private var historyVM          = HistoryViewModel()
    @State private var revenueCatService  = RevenueCatService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authVM)
                .environment(userVM)
                .environment(repairVM)
                .environment(historyVM)
                .environment(revenueCatService)
                // Start the Firebase Auth listener only after Firebase is configured.
                // .task runs after applicationDidFinishLaunchingWithOptions, so it's safe.
                .task {
                    authVM.startListening()
                    await revenueCatService.fetchOfferings()
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onChange(of: authVM.firebaseUser) { _, user in
                    if let user {
                        // Log this Firebase UID into RevenueCat so purchase history
                        // is tied to the account across devices/reinstalls.
                        Task {
                            try? await Purchases.shared.logIn(user.uid)
                            // Re-fetch offerings after login — RC may assign a
                            // different experiment variant to the identified user.
                            await revenueCatService.fetchOfferings()
                        }
                        userVM.startListening(uid: user.uid)
                        historyVM.startListening()
                    } else {
                        // Switch RC back to an anonymous user on sign-out.
                        Task { try? await Purchases.shared.logOut() }
                        userVM.stopListening()
                        historyVM.stopListening()
                    }
                }
        }
    }
}
