import Foundation
import os.log

// MARK: - DataTables Response Wrapper
/// The myice.hockey API wraps all list responses in a DataTables envelope.
/// The actual items live in the `data` array.
struct DataTablesResponse<T: Decodable>: Decodable {
    let draw: Int
    let recordsTotal: Int
    let recordsFiltered: Int
    let data: [T]
}

actor MyIceAPIClient {
    static let shared = MyIceAPIClient()
    private let logger = Logger(subsystem: "com.abacusai.hockeyinfo", category: "API")
    private let baseURL = "https://app.myice.hockey"
    private let session: URLSession
    private var cookies: [HTTPCookie] = []
    private var playerId = ""
    private var seasonId = ""
    private var clubId = ""

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        ]
        session = URLSession(configuration: config)
    }

    // MARK: - Cookie Management

    private func cookieHeader() -> String {
        cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    private func extractCookies(from response: HTTPURLResponse, url: URL) {
        guard let headerFields = response.allHeaderFields as? [String: String] else { return }
        let newCookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
        for newCookie in newCookies {
            cookies.removeAll { $0.name == newCookie.name }
            // Skip cookies with "deleted" values (server uses these for session cleanup)
            if newCookie.value.lowercased() == "deleted" { continue }
            cookies.append(newCookie)
        }
    }

    private func extractPlayerData() {
        for c in cookies {
            let val = c.value.removingPercentEncoding ?? c.value
            // Skip "deleted" cookie values (server sets these when session expires)
            let isValid = !val.isEmpty && val.lowercased() != "deleted" && val != "0"
            switch c.name {
            case "mih_v3_cookid":
                if isValid { playerId = val }
            case "mih_v3_cooksea":
                if isValid { seasonId = val }
            case "mih_v3_cookclub":
                if isValid { clubId = val }
            case "mih_v3_cookname":
                if isValid { KeychainHelper.playerName = val }
            case "mih_v3_cookage":
                if isValid { KeychainHelper.teamName = val }
            default: break
            }
        }
    }

    func saveCookiesToKeychain() {
        let cookieData = cookies.compactMap { cookie -> [String: String]? in
            guard let props = cookie.properties else { return nil }
            var dict: [String: String] = [:]
            for (key, value) in props {
                dict[key.rawValue] = "\(value)"
            }
            return dict
        }
        if let data = try? JSONSerialization.data(withJSONObject: cookieData),
           let str = String(data: data, encoding: .utf8) {
            KeychainHelper.save(str, forKey: "cookies")
        }
        KeychainHelper.save(playerId, forKey: "playerId")
        KeychainHelper.save(seasonId, forKey: "seasonId")
        KeychainHelper.save(clubId, forKey: "clubId")
    }

    func loadCookiesFromKeychain() -> Bool {
        guard let str = KeychainHelper.load("cookies"),
              let data = str.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            return false
        }
        cookies = arr.compactMap { dict in
            var props: [HTTPCookiePropertyKey: Any] = [:]
            for (key, value) in dict {
                props[HTTPCookiePropertyKey(key)] = value
            }
            return HTTPCookie(properties: props)
        }
        playerId = KeychainHelper.load("playerId") ?? ""
        seasonId = KeychainHelper.load("seasonId") ?? ""
        clubId = KeychainHelper.load("clubId") ?? ""
        // Invalidate if any essential value is "deleted" (stale session artifact)
        if playerId.lowercased() == "deleted" { playerId = "" }
        if seasonId.lowercased() == "deleted" { seasonId = "" }
        if clubId.lowercased() == "deleted" { clubId = "" }
        return !playerId.isEmpty && !seasonId.isEmpty && !clubId.isEmpty
    }

    /// Validates the current session by making a lightweight request.
    /// Returns true if the session is still valid and returns data.
    func validateSession() async -> Bool {
        guard !playerId.isEmpty, !seasonId.isEmpty, !clubId.isEmpty else {
            logger.warning("Session ungueltig: playerId/seasonId/clubId leer")
            return false
        }
        do {
            let result: [Practice] = try await fetchEvents(eventType: "p", minDate: nil, maxDate: nil)
            if result.isEmpty {
                logger.warning("Session-Validierung: 0 Datensaetze zurueck - Session vermutlich ungueltig")
                return false
            }
            logger.info("Session validiert, \(result.count) Trainings-Datensaetze")
            return true
        } catch MyIceError.notAuthenticated {
            logger.warning("Session abgelaufen")
            return false
        } catch {
            logger.info("Session-Validierung fehlgeschlagen: \(error.localizedDescription)")
            return false
        }
    }

    /// Attempts to re-login using saved credentials from Keychain.
    func reloginIfNeeded() async -> Bool {
        guard let email = KeychainHelper.email,
              let password = KeychainHelper.password else {
            return false
        }
        do {
            try await login(email: email, password: password)
            return true
        } catch {
            logger.error("Re-Login fehlgeschlagen: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Login

    func login(email: String, password: String) async throws {
        // Clear any stale cookies from previous sessions
        cookies.removeAll()
        playerId = ""
        seasonId = ""
        clubId = ""

        // Step 1: GET the login page first to establish a fresh PHPSESSID
        guard let loginPageURL = URL(string: "\(baseURL)/") else {
            throw MyIceError.invalidURL
        }
        do {
            var pageReq = URLRequest(url: loginPageURL)
            pageReq.httpMethod = "GET"
            pageReq.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            let (_, pageResp) = try await session.data(for: pageReq)
            if let httpResp = pageResp as? HTTPURLResponse {
                extractCookies(from: httpResp, url: httpResp.url ?? loginPageURL)
            }
            let cookieNames = cookies.map { "\($0.name)=\($0.value.prefix(8))..." }.joined(separator: ", ")
            logger.info("Initiale Cookies: \(cookieNames)")
        } catch {
            logger.warning("Konnte Login-Seite nicht laden: \(error.localizedDescription) - fahre fort")
        }

        // Step 2: POST login credentials
        guard let url = URL(string: "\(baseURL)/classes/process.php") else {
            throw MyIceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(baseURL, forHTTPHeaderField: "Origin")
        request.setValue("\(baseURL)/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        // Only send PHPSESSID cookie on login POST (not stale mih_v3_* cookies)
        let phpSessionCookie = cookies.first { $0.name == "PHPSESSID" }
        if let sessId = phpSessionCookie {
            request.setValue("PHPSESSID=\(sessId.value)", forHTTPHeaderField: "Cookie")
        }

        let body = "login_email=\(formEncode(email))&login_password=\(formEncode(password))&sublogin=1&login_submit=1"
        request.httpBody = body.data(using: .utf8)

        logger.info("Login-Versuch fuer \(email)")

        // URLSession follows redirects automatically, so we get the final response.
        // Each hop's Set-Cookie headers are captured by the URL loading system,
        // but since we have httpShouldSetCookies=false we must capture them ourselves.
        // We use a delegate-less session, so data(for:) returns the FINAL response.
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MyIceError.invalidResponse
        }
        extractCookies(from: httpResponse, url: httpResponse.url ?? url)

        logger.info("Login Response: Status \(httpResponse.statusCode), URL: \(httpResponse.url?.absoluteString ?? "nil")")
        let cookieNames = cookies.map { $0.name }.joined(separator: ", ")
        logger.info("Cookies nach Login: \(cookieNames)")

        // After auto-redirect, we may need to follow the dashboard page to get mih_v3_* cookies
        // The server often sets them on the redirect target, not the login response
        if cookies.first(where: { $0.name == "mih_v3_cookid" }) == nil {
            // Try loading the dashboard to get the player cookies
            logger.info("Keine mih_v3 Cookies - lade Dashboard...")
            if let dashURL = URL(string: "\(baseURL)/players/dashboard/") {
                var dashReq = URLRequest(url: dashURL)
                dashReq.httpMethod = "GET"
                dashReq.setValue(cookieHeader(), forHTTPHeaderField: "Cookie")
                dashReq.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
                if let (_, dashResp) = try? await session.data(for: dashReq),
                   let dashHttp = dashResp as? HTTPURLResponse {
                    extractCookies(from: dashHttp, url: dashHttp.url ?? dashURL)
                    logger.info("Dashboard geladen: Status \(dashHttp.statusCode), Cookies: \(self.cookies.count)")
                }
            }
        }

        // Extract player/season/club IDs from cookies
        extractPlayerData()
        
        let playerCookies = cookies.filter { $0.name.hasPrefix("mih_v3_") }.map { "\($0.name)=\($0.value.prefix(8))..." }.joined(separator: ", ")
        logger.info("mih_v3 Cookies: \(playerCookies)")
        logger.info("PlayerId=\(self.playerId), SeasonId=\(self.seasonId), ClubId=\(self.clubId)")

        if playerId.isEmpty || seasonId.isEmpty || clubId.isEmpty {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            if bodyStr.contains("error") || bodyStr.contains("falsch") || bodyStr.contains("incorrect") {
                logger.error("Login fehlgeschlagen: Server meldet Fehler")
                throw MyIceError.loginFailed
            }
            // Maybe login worked but cookies not captured from auto-redirect
            logger.error("Login unvollstaendig: playerId=\(self.playerId), seasonId=\(self.seasonId), clubId=\(self.clubId)")
            logger.error("Response body: \(bodyStr.prefix(500))")
            if playerId.isEmpty {
                throw MyIceError.loginFailed
            }
        }
        
        saveCookiesToKeychain()
        logger.info("Login erfolgreich fuer Spieler \(self.playerId)")
    }

    // MARK: - Fetch Data

    func fetchPractices(minDate: String? = nil, maxDate: String? = nil) async throws -> [Practice] {
        return try await fetchEvents(eventType: "p", minDate: minDate, maxDate: maxDate)
    }

    func fetchGames(minDate: String? = nil, maxDate: String? = nil) async throws -> [Game] {
        return try await fetchEvents(eventType: "g", minDate: minDate, maxDate: maxDate)
    }

    private func fetchEvents<T: Decodable>(eventType: String, minDate: String?, maxDate: String?) async throws -> [T] {
        guard !playerId.isEmpty else { throw MyIceError.notAuthenticated }
        guard let url = URL(string: "\(baseURL)/api/players/playersfilter") else {
            throw MyIceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(baseURL, forHTTPHeaderField: "Origin")
        request.setValue("\(baseURL)/players/dashboard/", forHTTPHeaderField: "Referer")
        request.setValue(cookieHeader(), forHTTPHeaderField: "Cookie")

        var bodyParts = [
            "type=filter",
            "player_id=\(playerId)",
            "event_type=\(eventType)",
            "season=\(seasonId)",
            "club=\(clubId)"
        ]
        if let min = minDate { bodyParts.append("minDate=\(min)") }
        if let max = maxDate { bodyParts.append("maxDate=\(max)") }
        let bodyStr = bodyParts.joined(separator: "&")
        request.httpBody = bodyStr.data(using: .utf8)

        logger.info("Lade \(eventType == "p" ? "Trainings" : "Spiele"): POST playersfilter")
        logger.info("Body: type=filter&player_id=***&event_type=\(eventType)&season=\(self.seasonId)&club=\(self.clubId)")

        let (data, response) = try await session.data(for: request)
        if let httpResp = response as? HTTPURLResponse {
            extractCookies(from: httpResp, url: url)
            logger.info("Response Status: \(httpResp.statusCode)")
            if httpResp.statusCode == 302 || httpResp.statusCode == 401 {
                throw MyIceError.notAuthenticated
            }
        }

        // Decode the DataTables wrapper and extract the data array
        let decoder = JSONDecoder()
        do {
            let wrapper = try decoder.decode(DataTablesResponse<T>.self, from: data)
            logger.info("Erfolgreich decodiert: \(wrapper.recordsTotal) Datensaetze (\(wrapper.data.count) geladen)")
            return wrapper.data
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            logger.error("JSON Decode Fehler: \(error)")
            logger.error("Response (first 500 chars): \(raw.prefix(500))")
            
            // Check if response is HTML (session expired → redirected to login page)
            if raw.contains("<html") || raw.contains("<form") || raw.contains("login") {
                logger.warning("Server hat HTML statt JSON zurueckgegeben - Session vermutlich abgelaufen")
                throw MyIceError.notAuthenticated
            }
            throw MyIceError.decodingFailed
        }
    }

    var isAuthenticated: Bool {
        !playerId.isEmpty
    }

    var currentPlayerId: String { playerId }
    var currentSeasonId: String { seasonId }
    var currentClubId: String { clubId }

    // MARK: - Helpers

    private func formEncode(_ string: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }
}

enum MyIceError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case loginFailed
    case tooManyRedirects
    case notAuthenticated
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Ung\u{00FC}ltige URL"
        case .invalidResponse: return "Ung\u{00FC}ltige Antwort vom Server"
        case .loginFailed: return "Anmeldung fehlgeschlagen. Pr\u{00FC}fe E-Mail und Passwort."
        case .tooManyRedirects: return "Zu viele Weiterleitungen"
        case .notAuthenticated: return "Nicht angemeldet"
        case .decodingFailed: return "Daten konnten nicht gelesen werden"
        }
    }
}
