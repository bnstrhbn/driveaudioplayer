import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Group {
            switch app.phase {
            case .loading:
                ProgressView("Preparing Drive Audio")
                    .controlSize(.large)
            case .signedOut:
                SignInView(sessionExpired: false)
            case .sessionExpired:
                SignInView(sessionExpired: true)
            case .signedIn:
                DriveBrowserView()
                    .alert("Playback Stopped", isPresented: Binding(get: { app.player.lastError != nil }, set: { if !$0 { app.player.clearError() } })) {
                        if let current = app.player.current {
                            Button("Retry") { Task { await app.play(current) } }
                        }
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(app.player.lastError ?? "")
                    }
            case .failure(let message):
                ContentUnavailableView {
                    Label("Unable to Sign In", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") { Task { await app.signIn() } }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
        }
    }
}

private struct SignInView: View {
    @Environment(AppState.self) private var app
    let sessionExpired: Bool
    /// Why the previous session ended, if it ended on its own.
    private var reason: String? { GoogleAuthService.lastSessionEndReason }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 96, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)

            Text("Drive Audio")
                .font(.largeTitle.bold())

            Text("Play audio from Google Drive, online or offline.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            if sessionExpired || reason != nil {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Signed out of Google").font(.subheadline.weight(.semibold))
                        Text("Sign in again to keep listening — your downloads are still here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if let reason {
                            Text(reason)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                                .textSelection(.enabled)
                        }
                    }
                } icon: {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .foregroundStyle(.orange)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await app.signIn() }
            } label: {
                Label(sessionExpired ? "Sign in again" : "Continue with Google", systemImage: "g.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint("Opens Google sign-in")
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }
}
