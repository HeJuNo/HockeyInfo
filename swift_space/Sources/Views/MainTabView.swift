import SwiftUI

struct MainTabView: View {
    @Bindable var authVM: AuthViewModel
    @State private var dataVM = DataViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                NavigationStack {
                    HomeView(authVM: authVM, dataVM: dataVM)
                }
            }
            Tab("Trainings", systemImage: "figure.hockey", value: 1) {
                NavigationStack {
                    TrainingsListView(dataVM: dataVM)
                }
            }
            Tab("Spiele", systemImage: "sportscourt.fill", value: 2) {
                NavigationStack {
                    GamesListView(dataVM: dataVM)
                }
            }
            Tab("Kalender", systemImage: "calendar", value: 3) {
                NavigationStack {
                    CalendarTabView(dataVM: dataVM)
                }
            }
            Tab("Einstellungen", systemImage: "gearshape.fill", value: 4) {
                NavigationStack {
                    SettingsView(authVM: authVM, dataVM: dataVM)
                }
            }
        }
        .tint(AppTheme.accent)
        .preferredColorScheme(.dark)
        .task {
            await dataVM.refresh()
        }
    }
}
