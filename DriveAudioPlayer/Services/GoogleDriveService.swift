import Foundation

actor GoogleDriveService {
    typealias TokenProvider = @Sendable () async throws -> String
    private var tokenProvider: TokenProvider?
    private let baseURL = URL(string: "https://www.googleapis.com/drive/v3")!
    func setTokenProvider(_ provider: TokenProvider?) { tokenProvider = provider; invalidateAudioIndex() }
    private func accessToken() async throws -> String {
        guard let tokenProvider else { throw DriveError.notAuthenticated }
        return try await tokenProvider()
    }

    private let fileFields = "id,name,mimeType,modifiedTime,size,driveId,starred,parents,ownedByMe,sharedWithMeTime,sharingUser(displayName,emailAddress),owners(displayName,emailAddress),shortcutDetails(targetId,targetMimeType)"
    private var myDriveRootID: String?

    func file(id: String) async throws -> DriveFile {
        try await request(path: "files/\(id)", query: ["fields": fileFields, "supportsAllDrives": "true"])
    }

    /// The `root` alias never appears in a file's `parents`, so resolve the
    /// real My Drive folder ID once to recognise top-level folders.
    func rootFolderID() async throws -> String {
        if let myDriveRootID { return myDriveRootID }
        let id = try await file(id: "root").id
        myDriveRootID = id
        return id
    }

    /// Walks the folder's parent chain as far as it is readable and works out
    /// which location it lives under: a shared drive (with the drive root as the
    /// top-most ancestor), My Drive (chain reaches the root), or Shared with me
    /// (chain ends at a folder someone else owns, or one whose parent we can't read).
    func hierarchy(of folder: DriveFile, driveID: String?) async throws -> DriveHierarchy {
        // Favorites and shared-drive roots arrive without parent metadata.
        var current = folder.parents == nil ? try await file(id: folder.id) : folder
        var chain: [DriveFile] = []
        if let driveID {
            while let id = current.parents?.first, id != driveID, !chain.contains(where: { $0.id == id }) {
                current = try await file(id: id)
                chain.insert(current, at: 0)
            }
            if folder.id != driveID, let root = try? await file(id: driveID) { chain.insert(root, at: 0) }
            return DriveHierarchy(location: .sharedDrives, ancestors: chain)
        }
        let rootID = try await rootFolderID()
        while let id = current.parents?.first, id != rootID, !chain.contains(where: { $0.id == id }) {
            guard let parent = try? await file(id: id) else { break }
            current = parent
            chain.insert(current, at: 0)
        }
        let reachedRoot = current.parents?.first == rootID
        return DriveHierarchy(location: reachedRoot || current.ownedByMe == true ? .myDrive : .sharedWithMe, ancestors: chain)
    }

    func roots() async throws -> [DriveRoot] {
        var result = [DriveRoot(id: "root", name: "My Drive", driveId: nil)]
        let response: DriveRootsResponse = try await request(path: "drives", query: ["pageSize": "100"])
        result += (response.drives ?? []).map { DriveRoot(id: $0.id, name: $0.name, driveId: $0.id) }
        return result
    }

    func folderContents(folderID: String, driveID: String?) async throws -> [DriveFile] {
        let query = "'\(folderID)' in parents and trashed = false"
        let response: DriveListResponse = try await request(path: "files", query: ["q": query, "fields": "files(\(fileFields)),nextPageToken", "orderBy": "folder,modifiedTime desc,name", "pageSize": "1000"].merging(corpus(driveID)) { a, _ in a })
        let folders = try await foldersContainingAudio(response.files.filter(\.isFolder), driveID: driveID)
        return response.files.filter { folders.contains($0.id) || $0.isPlayableAudio }
    }

    func sharedFolders() async throws -> [DriveFile] {
        try await folders(matching: "sharedWithMe = true and trashed = false", orderBy: "folder,sharedWithMeTime desc")
    }

    func sharedDriveFolders() async throws -> [DriveFile] {
        let roots = try await roots().filter { $0.driveId != nil }
        return try await withThrowingTaskGroup(of: (Int, DriveFile?).self) { group in
            for (offset, root) in roots.enumerated() {
                group.addTask {
                    let index = try await self.audioIndex(driveID: root.driveId)
                    guard !index.withAudio.isEmpty else { return (offset, nil) }
                    return (offset, DriveFile(id: root.id, name: root.name, mimeType: "application/vnd.google-apps.folder", modifiedTime: nil, size: nil, driveId: root.driveId, starred: nil))
                }
            }
            var results: [(Int, DriveFile?)] = []
            for try await result in group { results.append(result) }
            return results.sorted { $0.0 < $1.0 }.compactMap(\.1)
        }
    }

    func starredFolders() async throws -> [DriveFile] {
        try await folders(matching: "starred = true and trashed = false")
    }

    /// Folders (that contain audio) and loose audio files matching the query.
    /// Shared and starred audio tracks often aren't inside any shared folder,
    /// so they're listed alongside the folders.
    private func folders(matching query: String, orderBy: String = "folder,modifiedTime desc,name") async throws -> [DriveFile] {
        let response: DriveListResponse = try await request(
            path: "files",
            query: [
                "q": query,
                "fields": "files(\(fileFields)),nextPageToken",
                "orderBy": orderBy,
                "pageSize": "1000",
                "supportsAllDrives": "true",
                "includeItemsFromAllDrives": "true",
                "corpora": "user"
            ]
        )
        let folders = try await foldersContainingAudio(response.files.filter(\.isFolder), driveID: nil)
        return response.files.filter { folders.contains($0.id) || $0.isPlayableAudio }
    }

    // MARK: Audio index

    /// Which folders in a corpus contain playable audio anywhere beneath them.
    /// Built from two listings (all folders, all audio files) rather than
    /// walking the tree, so it costs a few requests instead of one per folder.
    private struct AudioIndex {
        var folders: [String: DriveIndexEntry] = [:]
        var withAudio: Set<String> = []

        /// The index is authoritative only for subtrees it can fully see:
        /// everything in a shared drive, or folders the user owns in My Drive.
        /// Folders shared by others may have descendants that never appear in
        /// the user's corpus, so the answer for those is `nil` (unknown).
        func containsAudio(_ folder: DriveFile, inSharedDrive: Bool) -> Bool? {
            if withAudio.contains(folder.contentID) { return true }
            guard let entry = folders[folder.contentID], inSharedDrive || entry.ownedByMe == true else { return nil }
            return false
        }
    }
    private var audioIndexes: [String: Task<AudioIndex, Error>] = [:]
    private var probedFolders: [String: Bool] = [:]
    /// Upper bound on folders visited per probe; beyond this the folder is shown
    /// rather than spending more requests on it.
    private let probeLimit = 40

    func invalidateAudioIndex() { audioIndexes = [:]; probedFolders = [:] }

    /// IDs of the given folders that (transitively) contain audio. Uses the
    /// index where it is authoritative and probes the remaining folders' subtrees
    /// concurrently.
    private func foldersContainingAudio(_ folders: [DriveFile], driveID: String?) async throws -> Set<String> {
        let index = try await audioIndex(driveID: driveID)
        var result = Set<String>()
        var unknown: [DriveFile] = []
        for folder in folders {
            switch index.containsAudio(folder, inSharedDrive: driveID != nil) {
            case true?: result.insert(folder.id)
            case false?: break
            case nil: unknown.append(folder)
            }
        }
        guard !unknown.isEmpty else { return result }
        return try await withThrowingTaskGroup(of: (String, Bool).self) { group in
            for folder in unknown {
                group.addTask { (folder.id, try await self.probeForAudio(folderID: folder.contentID, driveID: driveID)) }
            }
            for try await (id, hasAudio) in group where hasAudio { result.insert(id) }
            return result
        }
    }

    /// Breadth-first walk of a folder we cannot index, stopping at the first
    /// audio file. One request per folder visited; results are cached.
    private func probeForAudio(folderID: String, driveID: String?) async throws -> Bool {
        if let cached = probedFolders[folderID] { return cached }
        var queue = [folderID]
        var visited = Set<String>()
        while let id = queue.first {
            queue.removeFirst()
            guard visited.insert(id).inserted else { continue }
            guard visited.count <= probeLimit else { return true }
            if let cached = probedFolders[id] {
                if cached { probedFolders[folderID] = true; return true } else { continue }
            }
            let children = try await listAll(query: "'\(id)' in parents and trashed = false and (mimeType = '\(DriveMIME.folder)' or \(audioQuery))", fields: "files(\(indexFields)),nextPageToken", driveID: driveID)
            if children.contains(where: \.isPlayableAudio) { probedFolders[folderID] = true; return true }
            queue += children.filter(\.isFolder).map(\.contentID)
        }
        probedFolders[folderID] = false
        return false
    }

    /// Shortcuts can't be filtered by target type server-side, so they are
    /// fetched wholesale and classified client-side via `shortcutDetails`.
    private var audioQuery: String {
        let extensions = DriveFile.audioExtensions.map { "fileExtension = '\($0)'" }.joined(separator: " or ")
        return "(mimeType contains 'audio/' or \(extensions) or mimeType = '\(DriveMIME.shortcut)')"
    }
    private let indexFields = "id,name,mimeType,parents,ownedByMe,shortcutDetails(targetId,targetMimeType)"

    private func audioIndex(driveID: String?) async throws -> AudioIndex {
        let key = driveID ?? "user"
        if let task = audioIndexes[key] { return try await task.value }
        let task = Task { try await buildAudioIndex(driveID: driveID) }
        audioIndexes[key] = task
        do { return try await task.value } catch { audioIndexes[key] = nil; throw error }
    }

    private func buildAudioIndex(driveID: String?) async throws -> AudioIndex {
        let folderQuery = "mimeType = '\(DriveMIME.folder)' and trashed = false"
        async let folders = listAll(query: folderQuery, fields: "files(\(indexFields)),nextPageToken", driveID: driveID)
        async let audio = listAll(query: "\(audioQuery) and trashed = false", fields: "files(\(indexFields)),nextPageToken", driveID: driveID)

        var index = AudioIndex()
        for folder in try await folders { index.folders[folder.id] = folder }
        // Shortcuts pointing at audio count for the folder that holds the
        // shortcut; folder shortcuts are handled by the per-folder probe.
        var frontier = try await audio.filter(\.isPlayableAudio).flatMap { $0.parents ?? [] }
        while let id = frontier.popLast() {
            guard index.withAudio.insert(id).inserted else { continue }
            frontier += index.folders[id]?.parents ?? []
        }
        return index
    }

    private func listAll(query: String, fields: String, driveID: String?) async throws -> [DriveIndexEntry] {
        var entries: [DriveIndexEntry] = []
        var pageToken: String?
        repeat {
            let response: DriveIndexResponse = try await request(path: "files", query: ["q": query, "fields": fields, "pageSize": "1000", "pageToken": pageToken ?? ""].merging(corpus(driveID)) { a, _ in a })
            entries += response.files
            pageToken = response.nextPageToken
        } while pageToken != nil
        return entries
    }

    private func corpus(_ driveID: String?) -> [String: String] {
        ["supportsAllDrives": "true", "includeItemsFromAllDrives": "true", "corpora": driveID == nil ? "user" : "drive", "driveId": driveID ?? ""]
    }

    func mediaURL(for file: DriveFile) -> URL { baseURL.appending(path: "files/\(file.contentID)").appending(queryItems: [URLQueryItem(name: "alt", value: "media"), URLQueryItem(name: "supportsAllDrives", value: "true")]) }
    func authorizedRequest(for file: DriveFile) async throws -> URLRequest {
        var request = URLRequest(url: mediaURL(for: file)); request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization"); return request
    }

    private func request<T: Decodable>(path: String, query: [String: String]) async throws -> T {
        let accessToken = try await accessToken()
        var url = baseURL.appending(path: path)
        url.append(queryItems: query.compactMap { $0.value.isEmpty ? nil : URLQueryItem(name: $0.key, value: $0.value) })
        var request = URLRequest(url: url); request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode
            throw DriveError.requestFailed(status: status, details: apiError(from: data))
        }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return try decoder.decode(T.self, from: data)
    }
    private func apiError(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = object["error"] as? [String: Any] else { return nil }
        return error["message"] as? String
    }

    enum DriveError: LocalizedError {
        case notAuthenticated
        case requestFailed(status: Int?, details: String?)
        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "Sign in to Google Drive first."
            case .requestFailed(let status, let details):
                let prefix = status.map { "Google Drive request failed (HTTP \($0))." } ?? "Unable to load Google Drive."
                return details.map { "\(prefix) \($0)" } ?? prefix
            }
        }
    }
}
