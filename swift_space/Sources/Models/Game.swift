import Foundation

struct Game: Codable, Identifiable, Hashable {
    var id: String { id_game }
    let id_game: String
    let id_group: String
    let name: String
    let title: String
    let agegroup: String
    let type: String
    let result: String
    let place: String
    let date: String
    let weekday: String
    let time_start: String
    let time_end: String
    let meeting: String?
    let departure: String?
    let game_files: Int
    let health_status: String
    let health_status_label: String
    let notes: String?
    let health_notes: String?
    let available: String
    let color: String

    /// Display-friendly notes, never nil
    var displayNotes: String {
        (notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var parsedDate: Date? {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "de_DE")
        return df.date(from: date)
    }

    var isUpcoming: Bool {
        guard let d = parsedDate else { return false }
        return d >= Calendar.current.startOfDay(for: Date())
    }

    var isHome: Bool {
        // Check multiple patterns the API might use
        let lower = type.lowercased()
        let nameLower = name.lowercased()
        if nameLower.contains("(ausw\u{00E4}rts)") { return false }
        if lower.contains("heim") || lower.uppercased() == "H" { return true }
        // If not explicitly away, assume home
        return !nameLower.contains("ausw")
    }

    /// Display title: prefer the name field (opponent name without group prefix)
    var displayTitle: String {
        if !name.isEmpty { return name }
        if !title.isEmpty { return title.replacingOccurrences(of: "\n", with: " \u{00B7} ") }
        return "Spiel"
    }

    var resultComponents: (home: Int, away: Int)? {
        let parts = result.split(separator: "-")
        guard parts.count == 2,
              let h = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let a = Int(parts[1].trimmingCharacters(in: .whitespaces)),
              !(h == 0 && a == 0 && isUpcoming) else { return nil }
        return (h, a)
    }

    var resultType: ResultType {
        guard let r = resultComponents else { return .none }
        if r.home == r.away { return .draw }
        if isHome { return r.home > r.away ? .win : .loss }
        return r.away > r.home ? .win : .loss
    }

    enum ResultType {
        case win, loss, draw, none
    }

    var healthIcon: String {
        switch health_status {
        case "1": return "checkmark.circle.fill"
        case "6": return "xmark.circle.fill"
        case "9": return "cross.circle.fill"
        default: return "questionmark.circle"
        }
    }

    var healthColorName: String {
        switch health_status {
        case "1": return "green"
        case "6": return "orange"
        case "9": return "red"
        default: return "gray"
        }
    }

    var meetingTime: String {
        guard let m = meeting, !m.isEmpty, m != "00:00", m != "00:00:00" else { return "" }
        return formatTime(m)
    }

    var departureTime: String {
        guard let d = departure, !d.isEmpty, d != "00:00", d != "00:00:00" else { return "" }
        return formatTime(d)
    }

    /// Formatted time strings (strip seconds)
    var displayTimeStart: String { formatTime(time_start) }
    var displayTimeEnd: String { formatTime(time_end) }

    private func formatTime(_ t: String) -> String {
        let parts = t.split(separator: ":")
        guard parts.count >= 2 else { return t }
        return "\(parts[0]):\(parts[1])"
    }
}
