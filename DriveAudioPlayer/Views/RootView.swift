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

            if sessionExpired {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Signed out of Google").font(.subheadline.weight(.semibold))
                        Text("Your session expired. Sign in again to keep listening — your downloads are still here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
