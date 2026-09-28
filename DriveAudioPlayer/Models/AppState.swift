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
    let notes = NotesStore()
    let player = AudioPlayerService()
    /// Name of the folder/location the current playlist was started from.
    private(set) var playlistTitle: String?

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

    /// The signed-in Google account (from the Drive API). Shown in the account
    /// menu and used to keep favorites and notes separate per account.
    private(set) var account: DriveUser?
    private static let accountKey = "currentAccountID"

    func restore() async {
        await downloads.load()
        cache.load()
        if await auth.restoreSession() { await connectDrive(restored: true) } else { phase = .signedOut }
    }

    func signIn() async {
        phase = .loading
        do {
            try await auth.signIn()
            await connectDrive(restored: false)
        } catch { phase = .failure(error.localizedDescription) }
    }

    func signOut() async {
        await auth.signOut()
        await drive.setTokenProvider(nil)
        player.stop()
        setAccount(nil)
        phase = .signedOut
    }

    /// Drive fetches a fresh token for every request so playback can outlive
    /// Google's one-hour access tokens. Only a dead refresh token (not a
    /// network hiccup) sends the user back to sign in.
    private func connectDrive(restored: Bool) async {
        let auth = auth
        await drive.setTokenProvider { [weak self] in
            do { return try await auth.validAccessToken() } catch GoogleAuthService.AuthError.sessionExpired {
                await self?.sessionDidExpire()
                throw GoogleAuthService.AuthError.sessionExpired
            }
        }
        // Offline launches fall back to the last known account so favorites and
        // notes are available immediately; the network answer replaces it.
        if restored, let saved = UserDefaults.standard.string(forKey: Self.accountKey) {
            setAccount(DriveUser(displayName: nil, emailAddress: nil, permissionId: saved))
        }
        phase = .signedIn
        guard let user = try? await drive.currentUser() else { return }
        if user.permissionId != account?.permissionId || account?.emailAddress == nil { setAccount(user) }
        // Data saved before per-account scoping is claimed by whichever account
        // can actually open the folder/track, so nothing lands in the wrong account.
        let drive = drive
        await favorites.adoptLegacy { file in (try? await drive.file(id: file.id)) != nil }
        await notes.adoptLegacy { id in (try? await drive.file(id: id)) != nil }
    }

    private func setAccount(_ user: DriveUser?) {
        account = user
        UserDefaults.standard.set(user?.permissionId, forKey: Self.accountKey)
        favorites.setAccount(user?.permissionId)
        notes.setAccount(user?.permissionId)
    }

    private func sessionDidExpire() async {
        guard phase == .signedIn else { return }
        await drive.setTokenProvider(nil)
        player.stop()
        phase = .sessionExpired
    }

    /// Track changes driven by the player itself (end of track, lock screen
    /// next/previous). No view is in the loop, so failures go to the player,
    /// which shows a paused state and keeps the message for the next time the
    /// app is on screen.
    func play(_ file: DriveFile) async {
        do { try await play(file, playlist: player.playlist) }
        catch { player.fail("Couldn't play “\(file.name)”. \(error.localizedDescription)") }
    }

    func play(_ file: DriveFile, playlist: [DriveFile], from title: String? = nil) async throws {
        if let title { playlistTitle = title }
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
