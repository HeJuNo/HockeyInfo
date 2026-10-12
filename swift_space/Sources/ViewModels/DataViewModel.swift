import Foundation
import os.log

@Observable
class DataViewModel {
    var practices: [Practice] = []
    var games: [Game] = []
    var isLoading = false
    var errorMessage: String?
    var lastSyncDate: Date?

    private let logger = Logger(subsystem: "com.abacusai.hockeyinfo", category: "Data")

    init() {
        loadCachedData()
        if let ts = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
            lastSyncDate = ts
        }
    }

    @MainActor
    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
            let sixMonthsAhead = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
            let minDate = df.string(from: threeMonthsAgo)
            let maxDate = df.string(from: sixMonthsAhead)

            async let p = MyIceAPIClient.shared.fetchPractices(minDate: minDate, maxDate: maxDate)
            async let g = MyIceAPIClient.shared.fetchGames(minDate: minDate, maxDate: maxDate)

            let (fetchedPractices, fetchedGames) = try await (p, g)
            practices = fetchedPractices.sorted { ($0.date + $0.time_start) < ($1.date + $1.time_start) }
            games = fetchedGames.sorted { ($0.date + $0.time_start) < ($1.date + $1.time_start) }
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
            cacheData()
            logger.info("Daten aktualisiert: \(self.practices.count) Trainings, \(self.games.count) Spiele")
        } catch MyIceError.notAuthenticated {
            errorMessage = "Sitzung abgelaufen. Bitte erneut anmelden."
            logger.error("Session abgelaufen beim Laden der Daten")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Fehler beim Laden: \(error.localizedDescription)")
        }
        isLoading = false
    }

    var nextPractice: Practice? {
        practices.first { $0.isUpcoming }
    }

    var nextGame: Game? {
        games.first { $0.isUpcoming }
    }

    var upcomingPractices: [Practice] {
        practices.filter { $0.isUpcoming }
    }

    var pastPractices: [Practice] {
        practices.filter { !$0.isUpcoming }.reversed()
    }

    var upcomingGames: [Game] {
        games.filter { $0.isUpcoming }
    }

    var pastGames: [Game] {
        games.filter { !$0.isUpcoming }.reversed()
    }

    var seasonRecord: (wins: Int, draws: Int, losses: Int) {
        var w = 0, d = 0, l = 0
        for game in games {
            switch game.resultType {
            case .win: w += 1
            case .draw: d += 1
            case .loss: l += 1
            case .none: break
            }
        }
        return (w, d, l)
    }

    var weekEvents: (trainings: Int, games: Int) {
        let cal = Calendar.current
        let startOfWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let endOfWeek = cal.date(byAdding: .day, value: 7, to: startOfWeek)!
        let t = practices.filter {
            guard let d = $0.parsedDate else { return false }
            return d >= startOfWeek && d < endOfWeek
        }.count
        let g = games.filter {
            guard let d = $0.parsedDate else { return false }
            return d >= startOfWeek && d < endOfWeek
        }.count
        return (t, g)
    }

    // MARK: - Cache

    private func cacheData() {
        if let data = try? JSONEncoder().encode(practices) {
            UserDefaults.standard.set(data, forKey: "cachedPractices")
        }
        if let data = try? JSONEncoder().encode(games) {
            UserDefaults.standard.set(data, forKey: "cachedGames")
        }
    }

    private func loadCachedData() {
        if let data = UserDefaults.standard.data(forKey: "cachedPractices"),
           let cached = try? JSONDecoder().decode([Practice].self, from: data) {
            practices = cached
        }
        if let data = UserDefaults.standard.data(forKey: "cachedGames"),
           let cached = try? JSONDecoder().decode([Game].self, from: data) {
            games = cached
        }
    }
}
