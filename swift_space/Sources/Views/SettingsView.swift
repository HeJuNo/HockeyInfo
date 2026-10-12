import SwiftUI

struct SettingsView: View {
    @Bindable var authVM: AuthViewModel
    @Bindable var dataVM: DataViewModel
    @State private var showLogoutAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileSection
                accountSection
                appInfoSection
            }
            .padding()
        }
        .background(AppTheme.background)
        .overlay { HexagonPatternView().ignoresSafeArea() }
        .navigationTitle("Einstellungen")
        .alert("Abmelden?", isPresented: $showLogoutAlert) {
            Button("Abmelden", role: .destructive) {
                authVM.logout()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle lokalen Daten werden gel\u{00F6}scht.")
        }
    }

    // MARK: - Profile
    private var profileSection: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.2))
                    .frame(width: 72, height: 72)
                Text(initials)
                    .font(.title.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
            }

            Text(authVM.playerName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if !authVM.teamName.isEmpty {
                Text(authVM.teamName)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subtitleColor)
            }

            HStack(spacing: 6) {
                Circle().fill(.green).frame(width: 8, height: 8)
                Text("Verbunden")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.1))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassCard()
    }

    // MARK: - Account
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Konto")
                .font(.headline)
                .foregroundStyle(.white)

            if let email = KeychainHelper.email {
                settingsRow(icon: "envelope.fill", title: "E-Mail", value: email)
            }

            settingsRow(icon: "eye.fill", title: "Zugriff", value: "Nur lesend")

            if let sync = dataVM.lastSyncDate {
                settingsRow(icon: "arrow.clockwise", title: "Letzte Synchronisation", value: formatDate(sync))
            }

            settingsRow(icon: "number", title: "Trainings geladen", value: "\(dataVM.practices.count)")
            settingsRow(icon: "number", title: "Spiele geladen", value: "\(dataVM.games.count)")

            Button {
                showLogoutAlert = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Abmelden")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.15))
                .foregroundStyle(.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - App Info
    private var appInfoSection: some View {
        VStack(spacing: 8) {
            Text("HockeyInfo v1.0")
                .font(.caption)
                .foregroundStyle(AppTheme.dimText)
            Text("Nur lesender Zugriff auf myice.hockey")
                .font(.caption2)
                .foregroundStyle(AppTheme.dimText)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Helpers
    private func settingsRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtitleColor)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.white)
        }
    }

    private var initials: String {
        let parts = authVM.playerName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }

    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
}
