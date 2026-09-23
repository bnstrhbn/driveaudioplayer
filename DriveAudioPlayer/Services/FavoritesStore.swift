import Foundation
import Observation

struct FavoriteFolder: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let driveID: String?

    var file: DriveFile {
        DriveFile(
            id: id,
            name: name,
            mimeType: "application/vnd.google-apps.folder",
            modifiedTime: nil,
            size: nil,
            driveId: driveID,
            starred: nil
        )
    }
}

@Observable @MainActor
final class FavoritesStore {
    private let storageKey = "favoriteFolders"
    private(set) var folders: [FavoriteFolder] = []

    var launchFolder: FavoriteFolder? { folders.first }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        folders = (try? JSONDecoder().decode([FavoriteFolder].self, from: data)) ?? []
    }

    func contains(_ folder: DriveFile, driveID: String?) -> Bool {
        folders.contains { $0.id == folder.id && $0.driveID == driveID }
    }

    /// Saving a folder promotes it to the first launch destination.
    func toggle(_ folder: DriveFile, driveID: String?) {
        if let index = folders.firstIndex(where: { $0.id == folder.id && $0.driveID == driveID }) {
            folders.remove(at: index)
        } else {
            folders.removeAll { $0.id == folder.id && $0.driveID == driveID }
            folders.insert(FavoriteFolder(id: folder.id, name: folder.name, driveID: driveID), at: 0)
        }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
