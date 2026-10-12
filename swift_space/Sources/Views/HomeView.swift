import SwiftUI

struct HomeView: View {
    @Bindable var authVM: AuthViewModel
    @Bindable var dataVM: DataViewModel

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Guten Morgen"
        case 12..<18: return "Guten Tag"
        default: return "Guten Abend"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                syncPill
                if let practice = dataVM.nextPractice {
                    nextTrainingCard(practice)
                }
                if let game = dataVM.nextGame {
                    nextGameCard(game)
                }
                weekOverview
            }
            .padding()
        }
        .background(AppTheme.background)
        .overlay { HexagonPatternView().ignoresSafeArea() }
        .refreshable { await dataVM.refresh() }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                if !authVM.playerName.isEmpty {
                    Text(authVM.playerName)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtitleColor)
                }
            }
            Spacer()
            Image(systemName: "bell.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.subtitleColor)
        }
    }

    // MARK: - Sync Pill
    private var syncPill: some View {
        HStack(spacing: 8) {
            if dataVM.isLoading {
                ProgressView().tint(AppTheme.accent)
                    .scaleEffect(0.7)
                Text("Synchronisiere...")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtitleColor)
            } else {
                Circle().fill(.green).frame(width: 8, height: 8)
                Text(syncTimeText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtitleColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var syncTimeText: String {
        guard let date = dataVM.lastSyncDate else { return "Noch nicht synchronisiert" }
        let fmt = RelativeDateTimeFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        return "Zuletzt: \(fmt.localizedString(for: date, relativeTo: Date()))"
    }

    // MARK: - Next Training Card
    private func nextTrainingCard(_ p: Practice) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("N\u{00E4}chstes Training")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
                AttendanceBadge(status: p.health_status, label: p.health_status_label)
            }

            HStack(spacing: 16) {
                // Date block
                VStack(spacing: 2) {
                    Text(monthAbbrev(p.date))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .textCase(.uppercase)
                    Text(dayNumber(p.date))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                    Text(p.weekday)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.subtitleColor)
                }
                .frame(width: 60)

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(p.time_start) \u{2013} \(p.time_end)")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("\(p.duration) Min. \u{00B7} \(p.type)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtitleColor)
                    if !p.place.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                            Text(p.place)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.subtitleColor)
                        }
                    }
                }
            }

            if !p.notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bemerkungen")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                    Text(p.notes)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtitleColor)
                        .italic()
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [AppTheme.accent.opacity(0.15), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .glassCard()
    }

    // MARK: - Next Game Card
    private func nextGameCard(_ g: Game) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("N\u{00E4}chstes Spiel")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
                AttendanceBadge(status: g.health_status, label: g.health_status_label)
            }

            HStack(spacing: 10) {
                Text(g.isHome ? "H" : "A")
                    .font(.caption.weight(.bold))
                    .padding(6)
                    .background(g.isHome ? AppTheme.accent.opacity(0.3) : Color.orange.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(g.isHome ? AppTheme.accent : .orange)

                Text(g.title.isEmpty ? g.name : g.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 20) {
                Label(formatDisplayDate(g.date), systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subtitleColor)
                Label(g.time_start, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subtitleColor)
            }

            if !g.place.isEmpty {
                Label(g.place, systemImage: "mappin.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subtitleColor)
            }

            if !g.notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bemerkungen")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(g.notes)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtitleColor)
                        .italic()
                }
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Week Overview
    private var weekOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diese Woche")
                .font(.headline)
                .foregroundStyle(.white)
            HStack(spacing: 12) {
                weekCard(value: "\(dataVM.weekEvents.trainings)", label: "Trainings", icon: "figure.hockey")
                weekCard(value: "\(dataVM.weekEvents.games)", label: "Spiele", icon: "sportscourt.fill")
                weekCard(value: "\(dataVM.weekEvents.trainings + dataVM.weekEvents.games)", label: "Gesamt", icon: "calendar")
            }
        }
    }

    private func weekCard(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppTheme.accent)
            Text(value)
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.subtitleColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassCard()
    }

    // MARK: - Helpers
    private func monthAbbrev(_ dateStr: String) -> String {
        let months = ["JAN","FEB","M\u{00C4}R","APR","MAI","JUN","JUL","AUG","SEP","OKT","NOV","DEZ"]
        let parts = dateStr.split(separator: "-")
        guard parts.count >= 2, let m = Int(parts[1]), m >= 1, m <= 12 else { return "" }
        return months[m - 1]
    }

    private func dayNumber(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        guard parts.count >= 3 else { return "" }
        return String(Int(parts[2]) ?? 0)
    }

    private func formatDisplayDate(_ dateStr: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        guard let date = df.date(from: dateStr) else { return dateStr }
        df.dateFormat = "dd.MM.yyyy"
        return df.string(from: date)
    }
}
