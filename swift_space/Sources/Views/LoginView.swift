import SwiftUI

struct LoginView: View {
    @Bindable var authVM: AuthViewModel
    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool

    var body: some View {
        ZStack {
            // Ice background
            Image("ice-bg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            LinearGradient(
                colors: [AppTheme.background.opacity(0.7), AppTheme.background.opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)

                    // Puck icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .frame(width: 72, height: 72)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                            )
                        Image(systemName: "hockey.puck.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(AppTheme.accent)
                    }

                    // Title
                    HStack(spacing: 0) {
                        Text("my")
                            .font(.system(size: 56, weight: .light))
                            .foregroundStyle(.white.opacity(0.8))
                        Text("Ice")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                            .shadow(color: AppTheme.accent.opacity(0.5), radius: 10)
                    }

                    Text("Team \u{00B7} Termine \u{00B7} Kalender")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtitleColor)
                        .tracking(2)

                    // Login card
                    VStack(spacing: 20) {
                        Text("Willkommen zur\u{00FC}ck")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Melde dich mit deinem myIce-Konto an")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.subtitleColor)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Email field
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(AppTheme.dimText)
                                .frame(width: 20)
                            TextField("", text: $authVM.email, prompt: Text("E-Mail Adresse").foregroundStyle(AppTheme.dimText))
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .foregroundStyle(.white)
                                .focused($emailFocused)
                        }
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder))
                        .contentShape(Rectangle())
                        .onTapGesture { emailFocused = true }

                        // Password field
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(AppTheme.dimText)
                                .frame(width: 20)
                            SecureField("", text: $authVM.password, prompt: Text("Passwort").foregroundStyle(AppTheme.dimText))
                                .textContentType(.password)
                                .foregroundStyle(.white)
                                .focused($passwordFocused)
                        }
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder))
                        .contentShape(Rectangle())
                        .onTapGesture { passwordFocused = true }

                        // Stay logged in
                        Toggle(isOn: $authVM.stayLoggedIn) {
                            Text("Angemeldet bleiben")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.subtitleColor)
                        }
                        .tint(AppTheme.accent)

                        if let error = authVM.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Login button
                        Button {
                            Task { await authVM.login() }
                        } label: {
                            HStack {
                                if authVM.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                    Text("Anmelden")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.accent, AppTheme.accent.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(authVM.isLoading)

                        // Face ID button
                        if authVM.hasSavedCredentials {
                            Button {
                                Task { await authVM.loginWithBiometrics() }
                            } label: {
                                HStack {
                                    Image(systemName: "faceid")
                                    Text("Mit Face ID anmelden")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder))
                            }
                        }
                    }
                    .padding(24)
                    .glassCard()
                    .padding(.horizontal)

                    // Trust row
                    HStack(spacing: 0) {
                        trustItem(icon: "eye.fill", text: "Nur lesend")
                        trustItem(icon: "calendar", text: "Termine im\nKalender")
                        trustItem(icon: "bell.fill", text: "Hinweis bei\n\u{00C4}nderung")
                    }
                    .padding(.horizontal)

                    Text("HockeyInfo v1.0")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.dimText)

                    Spacer().frame(height: 20)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func trustItem(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppTheme.accent)
            Text(text)
                .font(.caption2)
                .foregroundStyle(AppTheme.subtitleColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
