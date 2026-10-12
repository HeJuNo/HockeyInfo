import Foundation
import LocalAuthentication
import os.log

@Observable
class AuthViewModel {
    var email = ""
    var password = ""
    var stayLoggedIn = true
    var isLoading = false
    var isAuthenticated = false
    var errorMessage: String?
    var hasSavedCredentials = false
    var playerName = ""
    var teamName = ""

    private let logger = Logger(subsystem: "com.abacusai.hockeyinfo", category: "Auth")

    init() {
        hasSavedCredentials = KeychainHelper.email != nil && KeychainHelper.password != nil
        playerName = KeychainHelper.playerName ?? ""
        teamName = KeychainHelper.teamName ?? ""
        Task {
            let loaded = await MyIceAPIClient.shared.loadCookiesFromKeychain()
            if loaded {
                await MainActor.run { self.isAuthenticated = true }
            }
        }
    }

    @MainActor
    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Bitte E-Mail und Passwort eingeben."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await MyIceAPIClient.shared.login(email: email, password: password)
            if stayLoggedIn {
                KeychainHelper.email = email
                KeychainHelper.password = password
            }
            playerName = KeychainHelper.playerName ?? ""
            teamName = KeychainHelper.teamName ?? ""
            isAuthenticated = true
            logger.info("Login erfolgreich")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Login Fehler: \(error.localizedDescription)")
        }
        isLoading = false
    }

    @MainActor
    func loginWithBiometrics() async {
        let context = LAContext()
        var nsError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &nsError) else {
            errorMessage = "Biometrische Authentifizierung nicht verfügbar."
            return
        }
        guard let savedEmail = KeychainHelper.email,
              let savedPassword = KeychainHelper.password else {
            errorMessage = "Keine gespeicherten Anmeldedaten vorhanden."
            return
        }
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Melde dich schnell und sicher mit Face ID an."
            )
            if success {
                email = savedEmail
                password = savedPassword
                await login()
            }
        } catch let authError as LAError {
            if authError.code != .userCancel {
                errorMessage = "Authentifizierung fehlgeschlagen."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func logout() {
        KeychainHelper.deleteAll()
        isAuthenticated = false
        email = ""
        password = ""
        playerName = ""
        teamName = ""
        hasSavedCredentials = false
        UserDefaults.standard.removeObject(forKey: "cachedPractices")
        UserDefaults.standard.removeObject(forKey: "cachedGames")
        UserDefaults.standard.removeObject(forKey: "lastSyncDate")
    }
}
