import SwiftUI

struct CalendarTabView: View {
    @Bindable var dataVM: DataViewModel
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()

    private let calendar = Calendar.current
    private let weekDays = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                monthHeader
                weekDayHeader
                monthGrid
                selectedDayEvents
            }
            .padding()
        }
        .background(AppTheme.background)
        .overlay { HexagonPatternView().ignoresSafeArea() }
        .navigationTitle("Kalender")
    }

    // MARK: - Month Header
    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth)!
                }
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(AppTheme.accent)
            }
            Spacer()
            Text(monthYearString)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            Button {
                withAnimation {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth)!
                }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.accent)
            }
        }
    }

    private var monthYearString: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        df.dateFormat = "MMMM yyyy"
        return df.string(from: displayedMonth)
    }

    // MARK: - Week Day Header
    private var weekDayHeader: some View {
        HStack {
            ForEach(weekDays, id: \.self) { day in
                Text(day)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.dimText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Month Grid
    private var monthGrid: some View {
        let days = daysInMonth()
        let columns = Array(repeating: GridItem(.flexible()), count: 7)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(days, id: \.self) { date in
                if let date = date {
                    dayCell(date)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasPractice = practicesOn(date).count > 0
        let hasGame = gamesOn(date).count > 0

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? .black : isToday ? AppTheme.accent : .white)

                HStack(spacing: 3) {
                    if hasPractice {
                        Circle().fill(AppTheme.accent).frame(width: 5, height: 5)
                    }
                    if hasGame {
                        Circle().fill(.orange).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                isSelected
                ? AnyShapeStyle(AppTheme.accent)
                : isToday
                ? AnyShapeStyle(AppTheme.accent.opacity(0.15))
                : AnyShapeStyle(Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Selected Day Events
    private var selectedDayEvents: some View {
        let practices = practicesOn(selectedDate)
        let games = gamesOn(selectedDate)
        let hasEvents = !practices.isEmpty || !games.isEmpty

        return VStack(alignment: .leading, spacing: 12) {
            Text(formattedDate(selectedDate))
                .font(.headline)
                .foregroundStyle(.white)

            if !hasEvents {
                Text("Keine Termine")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.dimText)
                    .padding(.top, 8)
            }

            ForEach(practices) { p in
                HStack(spacing: 12) {
                    Circle().fill(AppTheme.accent).frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Training")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("\(p.time_start) \u{2013} \(p.time_end) \u{00B7} \(p.place)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtitleColor)
                    }
                    Spacer()
                }
                .padding(12)
                .glassCard()
            }

            ForEach(games) { g in
                HStack(spacing: 12) {
                    Circle().fill(.orange).frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(g.title.isEmpty ? g.name : g.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("\(g.time_start) \u{00B7} \(g.place)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtitleColor)
                    }
                    Spacer()
                }
                .padding(12)
                .glassCard()
            }
        }
    }

    // MARK: - Helpers
    private func daysInMonth() -> [Date?] {
        let range = calendar.range(of: .day, in: .month, for: displayedMonth)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))!
        var weekday = calendar.component(.weekday, from: firstDay)
        // Convert Sunday=1 to Monday-based: Mon=0, Tue=1 ...
        weekday = (weekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: weekday)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }

    private func practicesOn(_ date: Date) -> [Practice] {
        dataVM.practices.filter {
            guard let d = $0.parsedDate else { return false }
            return calendar.isDate(d, inSameDayAs: date)
        }
    }

    private func gamesOn(_ date: Date) -> [Game] {
        dataVM.games.filter {
            guard let d = $0.parsedDate else { return false }
            return calendar.isDate(d, inSameDayAs: date)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        df.dateStyle = .full
        return df.string(from: date)
    }
}
