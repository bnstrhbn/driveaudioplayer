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

/// Favorites are per Google account: two accounts on one phone must not see
/// each other's folders (they may not even have access to them).
@Observable @MainActor
final class FavoritesStore {
    private static let legacyKey = "favoriteFolders"
    private var accountID: String?
    private var storageKey: String? { accountID.map { "favoriteFolders.\($0)" } }
    private(set) var folders: [FavoriteFolder] = []

    var launchFolder: FavoriteFolder? { folders.first }

    /// Switches to the given account's favorites.
    func setAccount(_ id: String?) {
        accountID = id
        folders = []
        guard let storageKey, let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        folders = (try? JSONDecoder().decode([FavoriteFolder].self, from: data)) ?? []
    }

    /// Favorites saved before per-account scoping have no owner. Each one is
    /// adopted by the first signed-in account that can actually open it;
    /// the rest wait for another account.
    func adoptLegacy(accessible: (DriveFile) async -> Bool) async {
        let defaults = UserDefaults.standard
        guard accountID != nil, let data = defaults.data(forKey: Self.legacyKey),
              var legacy = try? JSONDecoder().decode([FavoriteFolder].self, from: data), !legacy.isEmpty else { return }
        var remaining: [FavoriteFolder] = []
        for favorite in legacy where !folders.contains(where: { $0.id == favorite.id }) {
            if await accessible(favorite.file) { folders.append(favorite) } else { remaining.append(favorite) }
        }
        legacy = remaining
        if legacy.isEmpty { defaults.removeObject(forKey: Self.legacyKey) }
        else if let encoded = try? JSONEncoder().encode(legacy) { defaults.set(encoded, forKey: Self.legacyKey) }
        save()
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
        guard let storageKey, let data = try? JSONEncoder().encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
