import AuthenticationServices
import Observation

@Observable
final class AuthStore {
    private(set) var userID: String?
    private(set) var displayName: String

    private let defaults = UserDefaults.standard

    init() {
        userID = defaults.string(forKey: "auth.userID")
        displayName = defaults.string(forKey: "auth.displayName") ?? "사장님"
    }

    var isSignedIn: Bool { userID != nil }

    func handle(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        let name = [credential.fullName?.familyName, credential.fullName?.givenName]
            .compactMap { $0 }
            .joined()
        if !name.isEmpty {
            rename(name)
        }
        userID = credential.user
        defaults.set(credential.user, forKey: "auth.userID")
    }

    func verify() async {
        guard let userID else { return }
        let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
        if state == .revoked || state == .notFound {
            signOut()
        }
    }

    func rename(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        displayName = trimmed
        defaults.set(trimmed, forKey: "auth.displayName")
    }

    func signOut() {
        userID = nil
        defaults.removeObject(forKey: "auth.userID")
    }
}
