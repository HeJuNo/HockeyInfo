import SwiftUI

struct TrainingsListView: View {
    @Bindable var dataVM: DataViewModel
    @State private var filter: EventFilter = .all

    enum EventFilter: String, CaseIterable {
        case all = "Alle"
        case upcoming = "Kommend"
        case past = "Vergangen"
    }

    var filteredPractices: [Practice] {
        switch filter {
        case .all: return dataVM.practices
        case .upcoming: return dataVM.upcomingPractices
        case .past: return Array(dataVM.pastPractices)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                filterChips
                if filteredPractices.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredPractices) { practice in
                            NavigationLink(value: practice) {
                                trainingCard(practice)
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
        .navigationTitle("Trainings")
        .navigationDestination(for: Practice.self) { practice in
            TrainingDetailView(practice: practice)
        }
        .refreshable { await dataVM.refresh() }
    }

    private var filterChips: some View {
        HStack(spacing: 10) {
            ForEach(EventFilter.allCases, id: \.self) { f in
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
            Image(systemName: "figure.hockey")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.dimText)
            Text("Keine Trainings")
                .font(.headline)
                .foregroundStyle(AppTheme.subtitleColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func trainingCard(_ p: Practice) -> some View {
        HStack(spacing: 0) {
            // Left accent line
            RoundedRectangle(cornerRadius: 2)
                .fill(p.isUpcoming ? AppTheme.accent : Color.gray.opacity(0.4))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(p.weekday), \(formatDate(p.date))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("\(p.displayTimeStart) \u{2013} \(p.displayTimeEnd)")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.accent)
                    }
                    Spacer()
                    AttendanceBadge(status: p.health_status, label: p.health_status_label)
                }

                if !p.place.isEmpty {
                    Label(p.place, systemImage: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtitleColor)
                }

                if !p.displayNotes.isEmpty {
                    Text(p.displayNotes)
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtitleColor)
                        .italic()
                }
            }
            .padding(16)
        }
        .glassCard()
    }

    private func formatDate(_ dateStr: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        guard let date = df.date(from: dateStr) else { return dateStr }
        df.dateFormat = "dd.MM.yyyy"
        return df.string(from: date)
    }
}
