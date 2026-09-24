import Foundation
import Observation

/// Transparent, size-capped cache of recently played tracks, distinct from the
/// user's explicit offline downloads. Lives in Caches so the system may purge
/// it under storage pressure; entries are evicted least-recently-played first.
@Observable @MainActor
final class PlaybackCache {
    struct Entry: Codable, Sendable {
        let fileID: String
        let relativePath: String
        let bytes: Int64
        var lastPlayed: Date
        /// Drive keeps a file's ID across versions; a changed `modifiedTime`
        /// means the cached bytes are stale.
        var modifiedTime: String? = nil
    }

    static let defaultLimit: Int64 = 1_000_000_000

    private(set) var entries: [Entry] = []
    private var inFlight = Set<String>()
    private let directory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: "DriveAudio/PlaybackCache")
    private var indexURL: URL { directory.appending(path: "index.json") }
    var limit: Int64 = defaultLimit

    var totalBytes: Int64 { entries.reduce(0) { $0 + $1.bytes } }

    func load() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? Data(contentsOf: indexURL) else { return }
        entries = ((try? JSONDecoder().decode([Entry].self, from: data)) ?? [])
            .filter { FileManager.default.fileExists(atPath: directory.appending(path: $0.relativePath).path) }
        save()
    }

    /// The cached file for a track, if present and current. Marks it as recently
    /// played. A stale version is discarded so the new one streams and re-caches.
    func localURL(for file: DriveFile) -> URL? {
        guard let index = entries.firstIndex(where: { $0.fileID == file.id }) else { return nil }
        let url = directory.appending(path: entries[index].relativePath)
        guard FileManager.default.fileExists(atPath: url.path), !isOutdated(entries[index], for: file) else {
            try? FileManager.default.removeItem(at: url); entries.remove(at: index); save(); return nil
        }
        entries[index].lastPlayed = .now
        save()
        return url
    }

    func contains(_ file: DriveFile) -> Bool { entries.contains { $0.fileID == file.id && !isOutdated($0, for: file) } }
    private func isOutdated(_ entry: Entry, for file: DriveFile) -> Bool {
        guard let saved = entry.modifiedTime, let latest = file.modifiedTime else { return false }
        return saved != latest
    }

    /// Removes the track from the cache index and hands its file to the caller
    /// (used to promote a cached track to a permanent download without refetching).
    func take(_ file: DriveFile) -> URL? {
        guard let index = entries.firstIndex(where: { $0.fileID == file.id }) else { return nil }
        let entry = entries.remove(at: index)
        save()
        let url = directory.appending(path: entry.relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard !isOutdated(entry, for: file) else { try? FileManager.default.removeItem(at: url); return nil }
        return url
    }

    /// Fetches the track into the cache. Concurrent requests for the same track
    /// collapse into one; failures are silent because caching is best-effort.
    /// `unless` lets the caller skip tracks that already exist elsewhere.
    func cache(_ file: DriveFile, from drive: GoogleDriveService, unless alreadyStored: @MainActor () -> Bool = { false }) async {
        guard !contains(file), !inFlight.contains(file.id), !alreadyStored() else { return }
        inFlight.insert(file.id)
        defer { inFlight.remove(file.id) }
        guard let request = try? await drive.authorizedRequest(for: file),
              let (temporaryURL, response) = try? await URLSession.shared.download(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return }
        // The track may have become a permanent download while this was in flight.
        guard !alreadyStored() else { try? FileManager.default.removeItem(at: temporaryURL); return }
        let filename = "\(file.id)-\(file.name.replacingOccurrences(of: "/", with: "-"))"
        let destination = directory.appending(path: filename)
        try? FileManager.default.removeItem(at: destination)
        guard (try? FileManager.default.moveItem(at: temporaryURL, to: destination)) != nil else { return }
        let bytes = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int64) ?? Int64(file.size ?? "") ?? 0
        entries.removeAll { $0.fileID == file.id }
        entries.append(Entry(fileID: file.id, relativePath: filename, bytes: bytes, lastPlayed: .now, modifiedTime: file.modifiedTime))
        evictIfNeeded()
        save()
    }

    func clear() {
        for entry in entries { try? FileManager.default.removeItem(at: directory.appending(path: entry.relativePath)) }
        entries = []
        save()
    }

    private func evictIfNeeded() {
        var total = totalBytes
        guard total > limit else { return }
        for entry in entries.sorted(by: { $0.lastPlayed < $1.lastPlayed }) {
            guard total > limit else { break }
            try? FileManager.default.removeItem(at: directory.appending(path: entry.relativePath))
            entries.removeAll { $0.fileID == entry.fileID }
            total -= entry.bytes
        }
    }

    private func save() { try? JSONEncoder().encode(entries).write(to: indexURL, options: .atomic) }
}
