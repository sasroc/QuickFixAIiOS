import SwiftUI
import FirebaseCore
import GoogleSignIn

// MARK: - App Delegate (configures Firebase before any Firebase SDK usage)

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

    @State private var authVM        = AuthViewModel()
    @State private var userVM        = UserViewModel()
    @State private var repairVM      = RepairViewModel()
    @State private var historyVM     = HistoryViewModel()
    @State private var communityVM   = CommunityViewModel()
    @State private var storeKitService = StoreKitService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authVM)
                .environment(userVM)
                .environment(repairVM)
                .environment(historyVM)
                .environment(communityVM)
                .environment(storeKitService)
                // Start the Firebase Auth listener only after Firebase is configured.
                // .task runs after applicationDidFinishLaunchingWithOptions, so it's safe.
                .task {
                    authVM.startListening()
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onChange(of: authVM.firebaseUser) { _, user in
                    if let user {
                        userVM.startListening(uid: user.uid)
                        historyVM.startListening()
                        communityVM.startListening()
                    } else {
                        userVM.stopListening()
                        historyVM.stopListening()
                        communityVM.stopListening()
                    }
                }
        }
    }
}
