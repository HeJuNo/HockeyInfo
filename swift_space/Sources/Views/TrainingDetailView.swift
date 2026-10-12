import SwiftUI

struct TrainingDetailView: View {
    let practice: Practice

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroSection
                attendanceSection
                if !practice.displayNotes.isEmpty {
                    remarksSection
                }
                locationSection
            }
            .padding()
        }
        .background(AppTheme.background)
        .overlay { HexagonPatternView().ignoresSafeArea() }
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero
    private var heroSection: some View {
        VStack(spacing: 16) {
            // Type badge
            Text(practice.type.uppercased())
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.accent.opacity(0.2))
                .foregroundStyle(AppTheme.accent)
                .clipShape(Capsule())

            if let days = daysUntil(practice.date), practice.isUpcoming {
                Text(days == 0 ? "Heute" : days == 1 ? "Morgen" : "in \(days) Tagen")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subtitleColor)
            }

            Text(practice.weekday)
                .font(.title3)
                .foregroundStyle(AppTheme.subtitleColor)

            Text(dayNumber(practice.date))
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(.white)

            Text(monthYear(practice.date))
                .font(.headline)
                .foregroundStyle(AppTheme.subtitleColor)

            Text("\(practice.displayTimeStart) \u{2013} \(practice.displayTimeEnd)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.accent)

            Text("\(practice.duration) Minuten")
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtitleColor)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassCard()
    }

    // MARK: - Attendance
    private var attendanceSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Status")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                AttendanceBadge(status: practice.health_status, label: practice.health_status_label)
            }
            Text("Status im Webclient \u{00E4}ndern")
                .font(.caption)
                .foregroundStyle(AppTheme.dimText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Remarks
    private var remarksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bemerkungen")
                .font(.headline)
                .foregroundStyle(.white)

            // Parse structured remarks
            ForEach(parseRemarks(practice.displayNotes), id: \.self) { line in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: remarkIcon(for: line))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 20)
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtitleColor)
                }
            }

            Divider().background(AppTheme.cardBorder)

            Text("Original")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.dimText)
            Text(practice.displayNotes)
                .font(.caption)
                .foregroundStyle(AppTheme.subtitleColor)
                .italic()
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Location
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ort")
                .font(.headline)
                .foregroundStyle(.white)
            if !practice.place.isEmpty {
                Label(practice.place, systemImage: "mappin.circle.fill")
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

    // MARK: - Helpers
    private func parseRemarks(_ text: String) -> [String] {
        text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func remarkIcon(for line: String) -> String {
        let lower = line.lowercased()
        if lower.contains("treffpunkt") || lower.contains("treffen") { return "figure.walk" }
        if lower.contains("programm") || lower.contains("\u{00FC}bung") { return "list.bullet" }
        if lower.contains("abholen") || lower.contains("abholung") { return "car.fill" }
        if lower.contains("mitnehmen") || lower.contains("mitbringen") { return "bag.fill" }
        return "info.circle"
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
