import Foundation

/// Player profile data extracted from the myice.hockey dashboard HTML.
struct PlayerProfile: Codable, Equatable {
    var firstName: String = ""
    var lastName: String = ""
    var dateOfBirth: String = ""  // dd.MM.yyyy
    var nationality: String = ""
    var clubName: String = ""
    var clubLogoURL: String = ""
    var shootsHand: String = ""   // "L" / "R"
    var position: String = ""     // "G", "D", "F", or "Keine"
    var address: String = ""
    var zip: String = ""
    var town: String = ""

    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var age: Int? {
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy"
        guard let dob = df.date(from: dateOfBirth) else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }

    var positionLabel: String {
        switch position {
        case "G": return "Torwart"
        case "D": return "Verteidiger"
        case "F": return "St\u{00FC}rmer"
        default: return ""
        }
    }

    var shootsLabel: String {
        switch shootsHand {
        case "L": return "Links"
        case "R": return "Rechts"
        default: return ""
        }
    }

    /// Persist to UserDefaults for quick access
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "playerProfile")
        }
    }

    static func load() -> PlayerProfile? {
        guard let data = UserDefaults.standard.data(forKey: "playerProfile"),
              let profile = try? JSONDecoder().decode(PlayerProfile.self, from: data) else {
            return nil
        }
        return profile
    }
}
