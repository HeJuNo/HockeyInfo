import Foundation

struct Practice: Codable, Identifiable, Hashable {
    var id: String { id_practice }
    let id_practice: String
    let id_group: String
    let name: String
    let type: String
    let place: String
    let date: String
    let weekday: String
    let time_start: String
    let time_end: String
    let start: String
    let end: String
    let duration: String
    let health_status: String
    let health_status_label: String
    let health_notes: String
    let notes: String
    let color: String
    let editable: String

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
}
