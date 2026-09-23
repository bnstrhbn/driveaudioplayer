import AVFoundation
import Foundation
import Observation

@Observable @MainActor
final class AppState {
    enum Phase: Equatable { case loading, signedOut, sessionExpired, signedIn, failure(String) }
    var phase: Phase = .loading
    let auth = GoogleAuthService()
    let drive = GoogleDriveService()
    let downloads = DownloadStore()
    let favorites = FavoritesStore()
    let player = AudioPlayerService()

    init() {
        player.trackSelectionHandler = { [weak self] file in
            Task { await self?.play(file) }
        }
        player.assetProvider = { [weak self] file in
            guard let self else { throw CancellationError() }
            if let local = downloads.localURL(for: file) { return AVURLAsset(url: local) }
            let request = try await drive.authorizedRequest(for: file)
            return AVURLAsset(url: request.url!, options: ["AVURLAssetHTTPHeaderFieldsKey": request.allHTTPHeaderFields ?? [:]])
        }
    }

    func restore() async {
        await downloads.load()
        favorites.load()
        if await auth.restoreSession() { await connectDrive() } else { phase = .signedOut }
    }

    func signIn() async {
        phase = .loading
        do {
            try await auth.signIn()
            await connectDrive()
        } catch { phase = .failure(error.localizedDescription) }
    }

    func signOut() async {
        await auth.signOut()
        await drive.setTokenProvider(nil)
        player.stop()
        phase = .signedOut
    }

    /// Drive fetches a fresh token for every request so playback can outlive
    /// Google's one-hour access tokens. Only a dead refresh token (not a
    /// network hiccup) sends the user back to sign in.
    private func connectDrive() async {
        let auth = auth
        await drive.setTokenProvider { [weak self] in
            do { return try await auth.validAccessToken() } catch GoogleAuthService.AuthError.sessionExpired {
                await self?.sessionDidExpire()
                throw GoogleAuthService.AuthError.sessionExpired
            }
        }
        phase = .signedIn
    }

    private func sessionDidExpire() async {
        guard phase == .signedIn else { return }
        await drive.setTokenProvider(nil)
        player.stop()
        phase = .sessionExpired
    }

    func play(_ file: DriveFile) async {
        do {
            let local = downloads.localURL(for: file)
            let request = local == nil ? try await drive.authorizedRequest(for: file) : nil
            player.play(file: file, playlist: player.playlist, request: request, localURL: local)
        } catch {
            // The view that initiated playback already surfaces its own failures.
            // Remote controls cannot present an alert, so leave current playback intact.
        }
    }
}
