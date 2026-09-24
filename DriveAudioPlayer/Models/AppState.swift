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
    let cache = PlaybackCache()
    let favorites = FavoritesStore()
    let player = AudioPlayerService()

    init() {
        player.trackSelectionHandler = { [weak self] file in
            Task { await self?.play(file) }
        }
        player.assetProvider = { [weak self] file in
            guard let self else { throw CancellationError() }
            if let local = localURL(for: file) { return AVURLAsset(url: local) }
            let request = try await drive.authorizedRequest(for: file)
            return AVURLAsset(url: request.url!, options: ["AVURLAssetHTTPHeaderFieldsKey": request.allHTTPHeaderFields ?? [:]])
        }
    }

    /// Explicit downloads win over the transparent cache; either avoids the
    /// network. An outdated download is skipped so the newer version plays
    /// (`warmCache` refreshes the download itself when on Wi-Fi).
    func localURL(for file: DriveFile) -> URL? {
        if !downloads.isOutdated(file), let url = downloads.localURL(for: file) { return url }
        return cache.localURL(for: file)
    }

    func restore() async {
        await downloads.load()
        cache.load()
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
            // The view that initiated playback already surfaces its own failures.
            // Remote controls cannot present an alert, so leave current playback intact.
            try await play(file, playlist: player.playlist)
        } catch { }
    }

    func play(_ file: DriveFile, playlist: [DriveFile]) async throws {
        let local = localURL(for: file)
        let request = local == nil ? try await drive.authorizedRequest(for: file) : nil
        player.play(file: file, playlist: playlist, request: request, localURL: local)
        warmCache(around: file, in: playlist)
    }

    /// Streaming can't be captured, so caching means a second fetch of the
    /// current track plus a prefetch of the next one. That's only worth the
    /// radio time on unmetered networks outside Low Power Mode; on cellular the
    /// app streams only and relies on what was cached earlier.
    private func warmCache(around file: DriveFile, in playlist: [DriveFile]) {
        guard !player.isOnExpensiveNetwork, !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
        var candidates = [file]
        if let index = playlist.firstIndex(of: file), playlist.count > 1 { candidates.append(playlist[(index + 1) % playlist.count]) }
        for track in candidates where localURL(for: track) == nil {
            if downloads.isOutdated(track) {
                // The user asked to keep this track offline; quietly bring it up to date.
                Task { try? await downloads.download(track, from: drive, promotingFrom: cache) }
            } else {
                Task { await cache.cache(track, from: drive, unless: { [downloads] in downloads.contains(track) && !downloads.isOutdated(track) }) }
            }
        }
    }

    func download(_ file: DriveFile) async throws { try await downloads.download(file, from: drive, promotingFrom: cache) }
    func downloadAll(_ files: [DriveFile], batchID: String) { downloads.downloadAll(files, batchID: batchID, from: drive, promotingFrom: cache) }
}
