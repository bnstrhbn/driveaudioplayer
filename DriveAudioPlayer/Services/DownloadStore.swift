import Foundation
import Observation

@Observable @MainActor
final class DownloadStore {
    struct BatchProgress: Equatable { var completed = 0; var failed = 0; let total: Int }

    private(set) var records: [DownloadRecord] = []
    /// In-flight folder downloads keyed by the caller's batch ID (a folder ID).
    private(set) var batches: [String: BatchProgress] = [:]
    private var batchTasks: [String: Task<Void, Never>] = [:]
    private let directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "DriveAudio/Downloads")
    private var indexURL: URL { directory.appending(path: "index.json") }
    func load() async { try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true); guard let data = try? Data(contentsOf: indexURL) else { return }; records = (try? JSONDecoder().decode([DownloadRecord].self, from: data)) ?? [] }
    func localURL(for file: DriveFile) -> URL? { records.first(where: { $0.fileID == file.id }).map { directory.appending(path: $0.relativePath) } }
    func contains(_ file: DriveFile) -> Bool { records.contains { $0.fileID == file.id } }
    /// True when Drive has a newer version of a downloaded file than the copy on
    /// disk. Records without a version (pre-upgrade) are assumed current.
    func isOutdated(_ file: DriveFile) -> Bool {
        guard let record = records.first(where: { $0.fileID == file.id }), let saved = record.modifiedTime, let latest = file.modifiedTime else { return false }
        return saved != latest
    }

    /// Downloads a track (or replaces an outdated copy). A matching copy already
    /// in the playback cache is promoted instead of fetched again, so the two
    /// stores never hold the same bytes.
    func download(_ file: DriveFile, from drive: GoogleDriveService, promotingFrom cache: PlaybackCache? = nil) async throws {
        guard !contains(file) || isOutdated(file) else { return }
        let filename = "\(file.id)-\(file.name.replacingOccurrences(of: "/", with: "-"))"
        let destination = directory.appending(path: filename)
        try? FileManager.default.removeItem(at: destination)
        if let cached = cache?.take(file) {
            try FileManager.default.moveItem(at: cached, to: destination)
        } else {
            let request = try await drive.authorizedRequest(for: file)
            let (temporaryURL, response) = try await URLSession.shared.download(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw DownloadError.failed }
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
        }
        records.removeAll { $0.fileID == file.id }
        records.append(DownloadRecord(fileID: file.id, fileName: file.name, relativePath: filename, completedAt: .now, modifiedTime: file.modifiedTime))
        try save()
    }

    /// Downloads every track sequentially, continuing past individual failures.
    /// Runs independently of the view that started it.
    func downloadAll(_ files: [DriveFile], batchID: String, from drive: GoogleDriveService, promotingFrom cache: PlaybackCache) {
        guard batchTasks[batchID] == nil else { return }
        let pending = files.filter { !contains($0) || isOutdated($0) }
        guard !pending.isEmpty else { return }
        batches[batchID] = BatchProgress(total: pending.count)
        batchTasks[batchID] = Task { [weak self] in
            for file in pending {
                guard !Task.isCancelled, let self else { break }
                do { try await download(file, from: drive, promotingFrom: cache); batches[batchID]?.completed += 1 }
                catch { batches[batchID]?.failed += 1 }
            }
            self?.batches[batchID] = nil
            self?.batchTasks[batchID] = nil
        }
    }

    func cancelBatch(_ batchID: String) { batchTasks[batchID]?.cancel(); batchTasks[batchID] = nil; batches[batchID] = nil }

    func delete(_ file: DriveFile) { guard let url = localURL(for: file) else { return }; try? FileManager.default.removeItem(at: url); records.removeAll { $0.fileID == file.id }; try? save() }
    func deleteAll(_ files: [DriveFile]) { for file in files { delete(file) } }
    private func save() throws { try JSONEncoder().encode(records).write(to: indexURL, options: .atomic) }
    enum DownloadError: LocalizedError { case failed; var errorDescription: String? { "Download failed. Check your connection and try again." } }
}
