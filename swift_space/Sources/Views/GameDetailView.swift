import SwiftUI

struct GameDetailView: View {
    let game: Game

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroSection
                if let r = game.resultComponents {
                    scoreSection(r)
                }
                attendanceSection
                timesSection
                if !game.displayNotes.isEmpty {
                    remarksSection
                }
                locationSection
            }
            .padding()
        }
        .background(AppTheme.background)
        .overlay { HexagonPatternView().ignoresSafeArea() }
        .navigationTitle("Spiel")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroSection: some View {
        VStack(spacing: 16) {
            // H/A badge
            Text(game.isHome ? "HEIMSPIEL" : "AUSW\u{00C4}RTSSPIEL")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(game.isHome ? AppTheme.accent.opacity(0.2) : Color.orange.opacity(0.2))
                .foregroundStyle(game.isHome ? AppTheme.accent : .orange)
                .clipShape(Capsule())

            Text(game.displayTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if !game.agegroup.isEmpty {
                Text(game.agegroup)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subtitleColor)
            }

            Text(game.weekday)
                .font(.title3)
                .foregroundStyle(AppTheme.subtitleColor)

            Text(dayNumber(game.date))
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(.white)

            Text(monthYear(game.date))
                .font(.headline)
                .foregroundStyle(AppTheme.subtitleColor)

            Text(game.displayTimeStart)
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.accent)

            if game.isUpcoming, let days = daysUntil(game.date) {
                Text(days == 0 ? "Heute" : days == 1 ? "Morgen" : "in \(days) Tagen")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassCard()
    }

    private func scoreSection(_ r: (home: Int, away: Int)) -> some View {
        VStack(spacing: 8) {
            Text("Ergebnis")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.subtitleColor)
                .textCase(.uppercase)
            Text("\(r.home) : \(r.away)")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(scoreColor(game.resultType))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard()
    }

    private var attendanceSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Status")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                AttendanceBadge(status: game.health_status, label: game.health_status_label)
            }
            Text("Status im Webclient \u{00E4}ndern")
                .font(.caption)
                .foregroundStyle(AppTheme.dimText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .glassCard()
    }

    private var timesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zeiten")
                .font(.headline)
                .foregroundStyle(.white)
            HStack(spacing: 20) {
                if !game.meetingTime.isEmpty {
                    Label("Treffpunkt: \(game.meetingTime)", systemImage: "figure.walk")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtitleColor)
                }
                if !game.departureTime.isEmpty {
                    Label("Abfahrt: \(game.departureTime)", systemImage: "car.fill")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtitleColor)
                }
            }
            HStack(spacing: 20) {
                Label("Beginn: \(game.displayTimeStart)", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subtitleColor)
                if !game.time_end.isEmpty {
                    Label("Ende: \(game.displayTimeEnd)", systemImage: "clock.badge.checkmark")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtitleColor)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }

    private var remarksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bemerkungen")
                .font(.headline)
                .foregroundStyle(.white)
            Text(game.displayNotes)
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtitleColor)
                .italic()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ort")
                .font(.headline)
                .foregroundStyle(.white)
            if !game.place.isEmpty {
                Label(game.place, systemImage: "mappin.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subtitleColor)
            } else {
                Text("Kein Ort angegeben")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.dimText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func dayNumber(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        guard parts.count >= 3 else { return "" }
        return String(Int(parts[2]) ?? 0)
    }

    private func monthYear(_ dateStr: String) -> String {
        let months = ["Januar","Februar","M\u{00E4}rz","April","Mai","Juni","Juli","August","September","Oktober","November","Dezember"]
        let parts = dateStr.split(separator: "-")
        guard parts.count >= 2, let m = Int(parts[1]), m >= 1, m <= 12 else { return dateStr }
        return "\(months[m-1]) \(parts[0])"
    }

    private func daysUntil(_ dateStr: String) -> Int? {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        guard let date = df.date(from: dateStr) else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day
    }
}
