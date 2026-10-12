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
    let meeting: String
    let departure: String
    let game_files: Int
    let health_status: String
    let health_status_label: String
    let notes: String
    let health_notes: String
    let available: String
    let color: String

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
        type.lowercased().contains("heim") || type.uppercased() == "H"
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
        guard !meeting.isEmpty, meeting != "00:00" else { return "" }
        return meeting
    }

    var departureTime: String {
        guard !departure.isEmpty, departure != "00:00" else { return "" }
        return departure
    }
}
