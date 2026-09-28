import Foundation
import Observation

/// On-device timestamped notes, keyed by Drive file ID (which is stable across
/// uploaded versions of a file) and scoped to the signed-in Google account.
/// Nothing is written to Drive.
@Observable @MainActor
final class NotesStore {
    private(set) var notes: [TrackNote] = []
    private let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "DriveAudio")
    private var legacyURL: URL { directory.appending(path: "notes.json") }
    private var fileURL: URL?

    /// Switches to the given account's notes.
    func setAccount(_ id: String?) {
        notes = []
        fileURL = id.map { directory.appending(path: "notes.\($0).json") }
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        notes = (try? JSONDecoder().decode([TrackNote].self, from: data)) ?? []
    }

    /// Notes saved before per-account scoping are adopted, per track, by the
    /// first signed-in account that can open that track (see FavoritesStore).
    func adoptLegacy(accessible: (String) async -> Bool) async {
        guard fileURL != nil, let data = try? Data(contentsOf: legacyURL),
              let legacy = try? JSONDecoder().decode([TrackNote].self, from: data), !legacy.isEmpty else { return }
        var adoptedFiles = Set<String>()
        for fileID in Set(legacy.map(\.fileID)) where await accessible(fileID) { adoptedFiles.insert(fileID) }
        notes += legacy.filter { adoptedFiles.contains($0.fileID) && !notes.contains($0) }
        let remaining = legacy.filter { !adoptedFiles.contains($0.fileID) }
        if remaining.isEmpty { try? FileManager.default.removeItem(at: legacyURL) }
        else { try? JSONEncoder().encode(remaining).write(to: legacyURL, options: .atomic) }
        save()
    }

    func notes(for file: DriveFile) -> [TrackNote] {
        notes.filter { $0.fileID == file.id }.sorted { $0.timestamp < $1.timestamp }
    }
    func count(for file: DriveFile) -> Int { notes.reduce(0) { $0 + ($1.fileID == file.id ? 1 : 0) } }

    func add(_ text: String, at timestamp: Double, to file: DriveFile, folderName: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        notes.append(TrackNote(fileID: file.id, fileName: file.name, folderName: folderName, timestamp: timestamp, text: trimmed))
        save()
    }

    func update(_ note: TrackNote, text: String, timestamp: Double) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        notes[index].text = trimmed
        notes[index].timestamp = timestamp
        notes[index].modifiedAt = .now
        save()
    }

    func delete(_ note: TrackNote) { notes.removeAll { $0.id == note.id }; save() }

    // MARK: Export

    /// Plain text that pastes cleanly into a doc or chat. Tracks appear in the
    /// order given; notes within a track are in timestamp order.
    func export(tracks: [DriveFile], title: String) -> String {
        let dated = Date.now.formatted(date: .abbreviated, time: .omitted)
        var lines = ["Notes — \(title)", "Exported \(dated)", ""]
        var total = 0
        for track in tracks {
            let trackNotes = notes(for: track)
            guard !trackNotes.isEmpty else { continue }
            total += trackNotes.count
            lines.append("## \(track.name)")
            lines += trackNotes.map { "- [\($0.timestampLabel)] \($0.text)" }
            lines.append("")
        }
        guard total > 0 else { return "" }
        return lines.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n"
    }

    func export(track: DriveFile) -> String {
        let trackNotes = notes(for: track)
        guard !trackNotes.isEmpty else { return "" }
        let folder = trackNotes.compactMap(\.folderName).first
        var lines = ["Notes — \(track.name)"]
        if let folder { lines.append("Folder: \(folder)") }
        lines.append("Exported \(Date.now.formatted(date: .abbreviated, time: .omitted))")
        lines.append("")
        lines += trackNotes.map { "- [\($0.timestampLabel)] \($0.text)" }
        return lines.joined(separator: "\n") + "\n"
    }

    private func save() {
        guard let fileURL else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(notes).write(to: fileURL, options: .atomic)
    }
}
