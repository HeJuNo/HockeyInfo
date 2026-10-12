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
    var playerProfile: PlayerProfile?

    private let logger = Logger(subsystem: "com.abacusai.hockeyinfo", category: "Auth")

    init() {
        hasSavedCredentials = KeychainHelper.email != nil && KeychainHelper.password != nil
        loadPlayerInfo()
        playerProfile = PlayerProfile.load()
        Task {
            await tryRestoreSession()
        }
    }

    private func loadPlayerInfo() {
        let name = KeychainHelper.playerName ?? ""
        // Filter out "deleted" or empty cookie artifacts
        playerName = (name.lowercased() == "deleted" || name.isEmpty) ? "" : name
        // mih_v3_cookage is an age-group ID (e.g. 101), not a team name
        teamName = ""
    }

    @MainActor
    private func tryRestoreSession() async {
        let loaded = await MyIceAPIClient.shared.loadCookiesFromKeychain()
        guard loaded else {
            logger.info("Keine gespeicherten Cookies vorhanden")
            return
        }

        // Validate the session is still alive
        let valid = await MyIceAPIClient.shared.validateSession()
        if valid {
            loadPlayerInfo()
            playerProfile = PlayerProfile.load()
            // If no profile cached yet, fetch it from the dashboard
            if playerProfile == nil {
                if let freshProfile = await MyIceAPIClient.shared.fetchPlayerProfile() {
                    freshProfile.save()
                    playerProfile = freshProfile
                }
            }
            isAuthenticated = true
            logger.info("Session wiederhergestellt")
        } else {
            // Try re-login with saved credentials
            logger.info("Session abgelaufen, versuche Re-Login")
            let relogged = await MyIceAPIClient.shared.reloginIfNeeded()
            if relogged {
                loadPlayerInfo()
                playerProfile = PlayerProfile.load()
                isAuthenticated = true
                logger.info("Re-Login erfolgreich")
            } else {
                logger.warning("Re-Login fehlgeschlagen, Benutzer muss sich neu anmelden")
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
            loadPlayerInfo()
            playerProfile = PlayerProfile.load()
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
            errorMessage = "Biometrische Authentifizierung nicht verf\u{00FC}gbar."
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
        playerProfile = nil
        hasSavedCredentials = false
        UserDefaults.standard.removeObject(forKey: "cachedPractices")
        UserDefaults.standard.removeObject(forKey: "cachedGames")
        UserDefaults.standard.removeObject(forKey: "lastSyncDate")
        UserDefaults.standard.removeObject(forKey: "playerProfile")
    }

    /// Displayable greeting name: full profile name, player cookie name, or email prefix
    var displayName: String {
        if let p = playerProfile, !p.fullName.isEmpty { return p.fullName }
        if !playerName.isEmpty { return playerName }
        if let e = KeychainHelper.email {
            return e.components(separatedBy: "@").first ?? ""
        }
        return ""
    }
}
