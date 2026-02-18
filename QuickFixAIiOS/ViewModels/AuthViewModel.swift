import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import GoogleSignInSwift

@MainActor
@Observable
final class AuthViewModel {

    // MARK: - State
    var firebaseUser: FirebaseAuth.User? = nil
    var isLoading = false
    var errorMessage: String? = nil
    var showDisplayNameModal = false

    private nonisolated(unsafe) var authListener: AuthStateDidChangeListenerHandle?

    // MARK: - Computed
    var isSignedIn: Bool { firebaseUser != nil }
    var currentUID: String? { firebaseUser?.uid }

    // MARK: - Lifecycle

    init() {
        // Do NOT call Auth.auth() here — FirebaseApp.configure() has not yet run
        // when @State property initializers execute. Call startListening() from
        // the App body's .task modifier instead (after Firebase is configured).
    }

    /// Called from QuickFixAIiOSApp after FirebaseApp.configure() has run.
    func startListening() {
        guard authListener == nil else { return }
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.firebaseUser = user
            }
        }
    }

    deinit {
        if let handle = authListener {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Email / Password

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = mapAuthError(error)
        }
    }

    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName.isEmpty ? nil : displayName
            try await changeRequest.commitChanges()

            // Create Firestore user doc
            await createFirestoreUserDoc(user: result.user, displayName: displayName)

            // Send welcome email
            await sendWelcomeEmail(to: email, name: displayName)
        } catch {
            errorMessage = mapAuthError(error)
        }
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController ?? scene.windows.first?.rootViewController else {
            errorMessage = "Cannot present Google Sign-In."
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: root)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google sign-in token missing."
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            let authResult = try await Auth.auth().signIn(with: credential)
            // Upsert Firestore doc (only creates if absent)
            await createFirestoreUserDoc(
                user: authResult.user,
                displayName: result.user.profile?.name ?? authResult.user.displayName ?? ""
            )
        } catch {
            if (error as NSError).code == GIDSignInError.canceled.rawValue { return }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Password Reset

    func sendPasswordReset(to email: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Update Display Name

    func updateDisplayName(_ name: String) async -> Bool {
        guard let user = Auth.auth().currentUser else { return false }
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = name
        do {
            try await changeRequest.commitChanges()
            try await Firestore.db.collection("users").document(user.uid).updateData([
                "displayName": name,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Delete Account

    func deleteAccount() async -> Bool {
        guard let user = Auth.auth().currentUser else { return false }
        isLoading = true
        defer { isLoading = false }
        do {
            // Delete Firestore doc first
            try await Firestore.db.collection("users").document(user.uid).delete()
            try await user.delete()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Helpers

    private func createFirestoreUserDoc(user: FirebaseAuth.User, displayName: String) async {
        let ref = Firestore.db.collection("users").document(user.uid)
        let snap = try? await ref.getDocument()
        guard snap?.exists != true else { return } // already created

        let data: [String: Any] = [
            "email":              user.email ?? "",
            "displayName":        displayName,
            "subscriptionStatus": "inactive",
            "credits":            0,
            "plan":               "none",
            "isAdmin":            false,
            "isOnTrial":          false,
            "wasOnTrial":         false,
            "hasLifetimeAccess":  false,
            "createdAt":          FieldValue.serverTimestamp()
        ]
        try? await ref.setData(data)
    }

    private func sendWelcomeEmail(to email: String, name: String) async {
        try? await APIService.shared.post(
            "/api/welcome",
            body: ["email": email, "name": name]
        )
    }

    private func mapAuthError(_ error: Error) -> String {
        let e = error as NSError
        switch AuthErrorCode(rawValue: e.code) {
        case .wrongPassword, .invalidCredential:
            return "Incorrect email or password."
        case .userNotFound:
            return "No account found with that email."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .tooManyRequests:
            return "Too many attempts. Please try again later."
        default:
            return error.localizedDescription
        }
    }
}
