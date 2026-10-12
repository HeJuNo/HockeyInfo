import SwiftUI

struct GamesListView: View {
    @Bindable var dataVM: DataViewModel
    @State private var filter: GameFilter = .all

    enum GameFilter: String, CaseIterable {
        case all = "Alle"
        case upcoming = "Kommend"
        case past = "Vergangen"
    }

    var filteredGames: [Game] {
        switch filter {
        case .all: return dataVM.games
        case .upcoming: return dataVM.upcomingGames
        case .past: return Array(dataVM.pastGames)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                seasonRecordHeader
                filterChips
                if filteredGames.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredGames) { game in
                            NavigationLink(value: game) {
                                gameCard(game)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.background)
        .overlay { HexagonPatternView().ignoresSafeArea() }
        .navigationTitle("Spiele")
        .navigationDestination(for: Game.self) { game in
            GameDetailView(game: game)
        }
        .refreshable { await dataVM.refresh() }
    }

    // MARK: - Season Record
    private var seasonRecordHeader: some View {
        HStack(spacing: 0) {
            recordStat(value: "\(dataVM.seasonRecord.wins)", label: "Siege", color: .green)
            recordStat(value: "\(dataVM.seasonRecord.draws)", label: "Remis", color: .yellow)
            recordStat(value: "\(dataVM.seasonRecord.losses)", label: "Niederlagen", color: .red)
        }
        .padding(16)
        .glassCard()
    }

    private func recordStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.subtitleColor)
        }
        .frame(maxWidth: .infinity)
    }

    private var filterChips: some View {
        HStack(spacing: 10) {
            ForEach(GameFilter.allCases, id: \.self) { f in
                Button {
                    withAnimation { filter = f }
                } label: {
                    Text(f.rawValue)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(filter == f ? AppTheme.accent : Color.white.opacity(0.08))
                        .foregroundStyle(filter == f ? .black : .white)
                        .clipShape(Capsule())
                }
            }
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sportscourt")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.dimText)
            Text("Keine Spiele")
                .font(.headline)
                .foregroundStyle(AppTheme.subtitleColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func gameCard(_ g: Game) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // H/A badge
                Text(g.isHome ? "H" : "A")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(g.isHome ? AppTheme.accent.opacity(0.3) : Color.orange.opacity(0.3))
                    .foregroundStyle(g.isHome ? AppTheme.accent : .orange)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(g.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                // Score
                if let r = g.resultComponents {
                    Text("\(r.home):\(r.away)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(scoreColor(g.resultType))
                }
            }

            HStack(spacing: 20) {
                Label("\(g.weekday), \(formatDate(g.date))", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtitleColor)
                Label(g.displayTimeStart, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtitleColor)
            }

            if !g.place.isEmpty {
                Label(g.place, systemImage: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtitleColor)
            }

            if !g.displayNotes.isEmpty {
                Text(g.displayNotes)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtitleColor)
                    .italic()
            }

            HStack {
                AttendanceBadge(status: g.health_status, label: g.health_status_label)
                Spacer()
                if g.isUpcoming, let daysUntil = daysUntil(g.date) {
                    Text(daysUntil == 0 ? "Heute" : daysUntil == 1 ? "Morgen" : "in \(daysUntil) Tagen")
                        .font(.caption)
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    private func scoreColor(_ type: Game.ResultType) -> Color {
        switch type {
        case .win: return .green
        case .loss: return .red
        case .draw: return .yellow
        case .none: return .white
        }
    }

    private func formatDate(_ dateStr: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        guard let date = df.date(from: dateStr) else { return dateStr }
        df.dateFormat = "dd.MM."
        return df.string(from: date)
    }

    private func daysUntil(_ dateStr: String) -> Int? {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        guard let date = df.date(from: dateStr) else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day
    }
}
