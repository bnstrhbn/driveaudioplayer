import AVFoundation
import MediaPlayer
import Observation

@Observable @MainActor
final class AudioPlayerService {
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private(set) var current: DriveFile?
    private(set) var playlist: [DriveFile] = []
    private(set) var isPlaying = false
    private(set) var currentTime = 0.0
    private(set) var duration = 0.0
    /// The app owns authorization and playback creation. Keeping this callback here
    /// makes the transport controls work even when the originating folder view is
    /// no longer on screen.
    var trackSelectionHandler: ((DriveFile) -> Void)?
    /// Builds a playable asset for any track so playlist durations can be
    /// loaded without the originating view.
    var assetProvider: ((DriveFile) async throws -> AVURLAsset)?
    private(set) var trackDurations: [String: Double] = [:]
    private var durationLoader: Task<Void, Never>?

    /// Sum of known track durations in the current playlist. `isComplete` is
    /// false while some tracks are still being measured.
    var playlistDuration: (total: Double, isComplete: Bool) {
        let known = playlist.compactMap { trackDurations[$0.id] }
        return (known.reduce(0, +), known.count == playlist.count)
    }

    private var interruptionObserver: NSObjectProtocol?
    private var wasPlayingBeforeInterruption = false

    init() { configureAudioSession(); configureRemoteCommands(); observeInterruptions() }
    func play(file: DriveFile, playlist: [DriveFile], request: URLRequest? = nil, localURL: URL? = nil) {
        configureAudioSession()
        stop(keepCurrent: true)
        if self.playlist != playlist { self.playlist = playlist; loadPlaylistDurations() }
        current = file
        let item = localURL.map(AVPlayerItem.init(url:)) ?? AVPlayerItem(asset: AVURLAsset(url: request!.url!, options: ["AVURLAssetHTTPHeaderFieldsKey": request!.allHTTPHeaderFields ?? [:]]))
        player = AVPlayer(playerItem: item)
        installObservers(item)
        // A tap always starts the selected track from the beginning. This also
        // applies when moving to the next/previous item in a folder playlist.
        player?.seek(to: .zero)
        currentTime = 0
        player?.play()
        isPlaying = true
        updateNowPlaying()
    }
    func toggle() { guard let player else { return }; if isPlaying { player.pause() } else { player.play() }; isPlaying.toggle(); updateNowPlaying() }
    func seek(to time: Double) {
        let clampedTime = min(max(time, 0), duration > 0 ? duration : time)
        player?.seek(to: CMTime(seconds: clampedTime, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard finished else { return }
            Task { @MainActor in
                self?.currentTime = clampedTime
                self?.updateNowPlaying()
            }
        }
    }
    func seek(by seconds: Double) {
        let limit = duration.isFinite && duration > 0 ? duration : .greatestFiniteMagnitude
        seek(to: min(max(currentTime + seconds, 0), limit))
    }
    func restart() { seek(to: 0) }
    /// Standard "previous" behaviour: restart the current track unless it has
    /// only just begun, in which case go to the previous track.
    @discardableResult
    func previous() -> Bool {
        if currentTime > 2 { restart(); return true }
        return skip(forward: false)
    }
    /// The playlist repeats: skipping past the last track wraps to the first and
    /// vice versa, so reaching the end of a folder starts it over.
    @discardableResult
    func skip(forward: Bool) -> Bool {
        guard let current, let index = playlist.firstIndex(of: current) else { return false }
        let next = (index + (forward ? 1 : -1) + playlist.count) % playlist.count
        trackSelectionHandler?(playlist[next])
        return true
    }
    func stop(keepCurrent: Bool = false) { if let timeObserver { player?.removeTimeObserver(timeObserver) }; if let endObserver { NotificationCenter.default.removeObserver(endObserver) }; player?.pause(); player = nil; isPlaying = false; if !keepCurrent { current = nil }; MPNowPlayingInfoCenter.default().nowPlayingInfo = nil }
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { }
    }
    /// Another app (music, a call, Siri) taking the audio session pauses us. When
    /// that app releases the session, pick up where we left off. Apple only sets
    /// `shouldResume` for interruptions it deems temporary, but for this app any
    /// interruption that ends while we were mid-track should resume playback.
    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(), queue: .main) { [weak self] notification in
            guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            Task { @MainActor in self?.handleInterruption(type) }
        }
    }
    private func handleInterruption(_ type: AVAudioSession.InterruptionType) {
        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            isPlaying = false
            updateNowPlaying()
        case .ended:
            guard wasPlayingBeforeInterruption, let player else { return }
            wasPlayingBeforeInterruption = false
            configureAudioSession()
            player.play()
            isPlaying = true
            updateNowPlaying()
        @unknown default: break
        }
    }
    private func installObservers(_ item: AVPlayerItem) {
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] time in
            Task { @MainActor in self?.didUpdateProgress(time.seconds) }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.skip(forward: true) }
        }
    }
    private func configureRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.isEnabled = true
        commands.pauseCommand.isEnabled = true
        commands.nextTrackCommand.isEnabled = true
        commands.previousTrackCommand.isEnabled = true
        commands.skipForwardCommand.isEnabled = true
        commands.skipBackwardCommand.isEnabled = true
        commands.skipForwardCommand.preferredIntervals = [15]
        commands.skipBackwardCommand.preferredIntervals = [15]
        commands.togglePlayPauseCommand.isEnabled = true
        commands.changePlaybackPositionCommand.isEnabled = true
        commands.seekForwardCommand.isEnabled = true
        commands.seekBackwardCommand.isEnabled = true

        commands.playCommand.addTarget { [weak self] _ in self?.toggleIfNeeded(play: true); return .success }
        commands.pauseCommand.addTarget { [weak self] _ in self?.toggleIfNeeded(play: false); return .success }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in self?.toggle(); return .success }
        commands.nextTrackCommand.addTarget { [weak self] _ in self?.skip(forward: true) == true ? .success : .noSuchContent }
        commands.previousTrackCommand.addTarget { [weak self] _ in self?.previous() == true ? .success : .noSuchContent }
        commands.skipForwardCommand.addTarget { [weak self] _ in self?.seek(by: 15); return .success }
        commands.skipBackwardCommand.addTarget { [weak self] _ in self?.seek(by: -15); return .success }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: event.positionTime); return .success
        }
        commands.seekForwardCommand.addTarget { [weak self] event in self?.scan(event, forward: true) ?? .commandFailed }
        commands.seekBackwardCommand.addTarget { [weak self] event in self?.scan(event, forward: false) ?? .commandFailed }
    }
    /// Press-and-hold on the lock screen's track buttons scans through the
    /// current track instead of skipping to the next one.
    private func scan(_ event: MPRemoteCommandEvent, forward: Bool) -> MPRemoteCommandHandlerStatus {
        guard let event = event as? MPSeekCommandEvent, let player else { return .commandFailed }
        switch event.type {
        case .beginSeeking: player.rate = forward ? 4 : -4
        case .endSeeking: player.rate = isPlaying ? 1 : 0
        @unknown default: return .commandFailed
        }
        return .success
    }
    private func loadPlaylistDurations() {
        durationLoader?.cancel()
        guard let assetProvider else { return }
        let pending = playlist.filter { trackDurations[$0.id] == nil }
        durationLoader = Task { [weak self] in
            for file in pending {
                guard !Task.isCancelled else { return }
                guard let seconds = try? await assetProvider(file).load(.duration).seconds, seconds.isFinite else { continue }
                self?.trackDurations[file.id] = seconds
            }
        }
    }
    private func didUpdateProgress(_ seconds: Double) {
        currentTime = seconds.isFinite ? seconds : 0
        let seconds = player?.currentItem?.duration.seconds ?? 0
        duration = seconds.isFinite ? seconds : 0
        if duration > 0, let current { trackDurations[current.id] = duration }
        updateNowPlaying()
    }
    private func toggleIfNeeded(play: Bool) { if isPlaying != play { toggle() } }
    private func updateNowPlaying() {
        guard let current else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: current.name,
            MPMediaItemPropertyArtist: "Google Drive",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1 : 0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]
    }
}
