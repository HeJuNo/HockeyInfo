import Foundation
import os.log

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
            cookies.append(newCookie)
        }
    }

    private func extractPlayerData() {
        for c in cookies {
            switch c.name {
            case "mih_v3_cookid": playerId = c.value
            case "mih_v3_cooksea": seasonId = c.value
            case "mih_v3_cookclub": clubId = c.value
            case "mih_v3_cookname":
                KeychainHelper.playerName = c.value.removingPercentEncoding ?? c.value
            case "mih_v3_cookage":
                KeychainHelper.teamName = c.value.removingPercentEncoding ?? c.value
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
        return !playerId.isEmpty
    }

    // MARK: - Login

    func login(email: String, password: String) async throws {
        guard let url = URL(string: "\(baseURL)/classes/process.php") else {
            throw MyIceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(baseURL, forHTTPHeaderField: "Origin")
        request.setValue("\(baseURL)/", forHTTPHeaderField: "Referer")

        let body = "login_email=\(urlEncode(email))&login_password=\(urlEncode(password))&sublogin=1&login_submit=1"
        request.httpBody = body.data(using: .utf8)

        // Follow redirects manually to capture cookies
        var currentRequest = request
        var redirectCount = 0
        while redirectCount < 5 {
            let (data, response) = try await session.data(for: currentRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MyIceError.invalidResponse
            }
            extractCookies(from: httpResponse, url: currentRequest.url!)

            if (300...399).contains(httpResponse.statusCode),
               let location = httpResponse.value(forHTTPHeaderField: "Location") {
                let redirectURL: URL
                if location.hasPrefix("http") {
                    guard let u = URL(string: location) else { throw MyIceError.invalidURL }
                    redirectURL = u
                } else {
                    guard let u = URL(string: "\(baseURL)\(location)") else { throw MyIceError.invalidURL }
                    redirectURL = u
                }
                var newReq = URLRequest(url: redirectURL)
                newReq.httpMethod = "GET"
                newReq.setValue(cookieHeader(), forHTTPHeaderField: "Cookie")
                currentRequest = newReq
                redirectCount += 1
                continue
            }

            // Check if login was successful by looking for player cookies
            extractPlayerData()
            if playerId.isEmpty {
                // Check response body for error
                let bodyStr = String(data: data, encoding: .utf8) ?? ""
                logger.error("Login fehlgeschlagen: \(bodyStr.prefix(200))")
                throw MyIceError.loginFailed
            }
            saveCookiesToKeychain()
            logger.info("Login erfolgreich fuer Spieler \(self.playerId)")
            return
        }
        throw MyIceError.tooManyRedirects
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
        request.httpBody = bodyParts.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        if let httpResp = response as? HTTPURLResponse {
            extractCookies(from: httpResp, url: url)
            if httpResp.statusCode == 302 || httpResp.statusCode == 401 {
                throw MyIceError.notAuthenticated
            }
        }

        let decoder = JSONDecoder()
        do {
            let items = try decoder.decode([T].self, from: data)
            return items
        } catch {
            logger.error("JSON Decode Fehler: \(error.localizedDescription)")
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            logger.error("Response: \(raw.prefix(500))")
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

    private func urlEncode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
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
        case .invalidURL: return "Ungültige URL"
        case .invalidResponse: return "Ungültige Antwort vom Server"
        case .loginFailed: return "Anmeldung fehlgeschlagen. Prüfe E-Mail und Passwort."
        case .tooManyRedirects: return "Zu viele Weiterleitungen"
        case .notAuthenticated: return "Nicht angemeldet"
        case .decodingFailed: return "Daten konnten nicht gelesen werden"
        }
    }
}
