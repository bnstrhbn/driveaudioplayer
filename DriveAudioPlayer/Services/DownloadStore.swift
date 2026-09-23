import Foundation
import Observation

@Observable @MainActor
final class DownloadStore {
    private(set) var records: [DownloadRecord] = []
    private let directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "DriveAudio/Downloads")
    private var indexURL: URL { directory.appending(path: "index.json") }
    func load() async { try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true); guard let data = try? Data(contentsOf: indexURL) else { return }; records = (try? JSONDecoder().decode([DownloadRecord].self, from: data)) ?? [] }
    func localURL(for file: DriveFile) -> URL? { records.first(where: { $0.fileID == file.id }).map { directory.appending(path: $0.relativePath) } }
    func download(_ file: DriveFile, from drive: GoogleDriveService, progress: @escaping @MainActor (Double?) -> Void) async throws {
        let request = try await drive.authorizedRequest(for: file)
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw DownloadError.failed }
        let filename = "\(file.id)-\(file.name.replacingOccurrences(of: "/", with: "-"))"
        let destination = directory.appending(path: filename)
        try? FileManager.default.removeItem(at: destination); try FileManager.default.moveItem(at: temporaryURL, to: destination)
        records.removeAll { $0.fileID == file.id }; records.append(DownloadRecord(fileID: file.id, fileName: file.name, relativePath: filename, completedAt: .now)); try save(); progress(nil)
    }
    func delete(_ file: DriveFile) { guard let url = localURL(for: file) else { return }; try? FileManager.default.removeItem(at: url); records.removeAll { $0.fileID == file.id }; try? save() }
    private func save() throws { try JSONEncoder().encode(records).write(to: indexURL, options: .atomic) }
    enum DownloadError: LocalizedError { case failed; var errorDescription: String? { "Download failed. Check your connection and try again." } }
}
