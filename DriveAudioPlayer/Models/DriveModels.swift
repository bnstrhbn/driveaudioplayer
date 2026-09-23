import Foundation

struct DriveFile: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let mimeType: String
    // Drive represents 64-bit values as strings in JSON. These fields aren't
    // currently used for sorting, so keeping the wire representation avoids
    // lossy decoding and works for every valid Drive file response.
    let modifiedTime: String?
    let size: String?
    let driveId: String?
    let starred: Bool?
    var parents: [String]? = nil
    var ownedByMe: Bool? = nil
    var sharedWithMeTime: String? = nil
    var sharingUser: DriveUser? = nil
    var owners: [DriveUser]? = nil
    var shortcutDetails: DriveShortcutDetails? = nil
    var idForSwiftUI: String { id }
    /// Shortcuts are separate files that point at a target; everything that
    /// reads or lists content must use the target instead.
    var isShortcut: Bool { mimeType == DriveMIME.shortcut }
    var contentID: String { shortcutDetails?.targetId ?? id }
    var effectiveMimeType: String { shortcutDetails?.targetMimeType ?? mimeType }
    /// Drive only records `sharingUser` when a person shared the item directly;
    /// link shares and items inherited through a shared folder leave it empty,
    /// so the owner is the next best answer.
    var sharedByLabel: String? { sharingUser?.label ?? owners?.first?.label }
    var sharedWithMeDate: Date? { DriveFile.date(from: sharedWithMeTime) }
    var modifiedDate: Date? { DriveFile.date(from: modifiedTime) }
    private static func date(from string: String?) -> Date? {
        guard let string else { return nil }
        return (try? Date(string, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true)))
            ?? (try? Date(string, strategy: .iso8601))
    }
    var isFolder: Bool { effectiveMimeType == DriveMIME.folder }
    static let audioExtensions = ["mp3", "m4a", "aac", "wav"]
    var isPlayableAudio: Bool { !isFolder && DriveMIME.looksLikeAudio(name: name, mimeType: effectiveMimeType) }
    var displaySize: String? {
        guard let size, let byteCount = Int64(size) else { return nil }
        return ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}

struct DriveShortcutDetails: Codable, Hashable, Sendable {
    let targetId: String?
    let targetMimeType: String?
}

enum DriveMIME {
    static let folder = "application/vnd.google-apps.folder"
    static let shortcut = "application/vnd.google-apps.shortcut"
    static func looksLikeAudio(name: String, mimeType: String) -> Bool {
        let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
        return DriveFile.audioExtensions.contains(ext) || mimeType.hasPrefix("audio/")
    }
}

struct DriveUser: Codable, Hashable, Sendable {
    let displayName: String?
    let emailAddress: String?
    var label: String? { displayName ?? emailAddress }
}

enum DriveLocation: String, CaseIterable, Identifiable, Sendable {
    case myDrive
    case sharedWithMe
    case sharedDrives
    case googleStarred
    case appFavorites

    var id: Self { self }
}

/// A folder's position in Drive: the location it belongs to and the readable
/// folders above it (top-most first).
struct DriveHierarchy: Sendable {
    let location: DriveLocation
    let ancestors: [DriveFile]
}

struct DriveListResponse: Codable, Sendable {
    let files: [DriveFile]
    let nextPageToken: String?
}

struct DriveRootsResponse: Codable, Sendable { let drives: [SharedDrive]? }

/// Minimal metadata used to work out which folders (transitively) contain audio.
struct DriveIndexEntry: Codable, Sendable {
    let id: String
    let name: String?
    let parents: [String]?
    let ownedByMe: Bool?
    let mimeType: String?
    let shortcutDetails: DriveShortcutDetails?
    var contentID: String { shortcutDetails?.targetId ?? id }
    var effectiveMimeType: String { shortcutDetails?.targetMimeType ?? mimeType ?? "" }
    var isFolder: Bool { effectiveMimeType == DriveMIME.folder }
    var isPlayableAudio: Bool { !isFolder && DriveMIME.looksLikeAudio(name: name ?? "", mimeType: effectiveMimeType) }
}

struct DriveIndexResponse: Codable, Sendable {
    let files: [DriveIndexEntry]
    let nextPageToken: String?
}

/// The `/drives` endpoint doesn't return file metadata such as `mimeType`, so
/// it must not share the `DriveFile` decoder.
struct SharedDrive: Codable, Sendable {
    let id: String
    let name: String
}

struct DriveRoot: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let driveId: String?
}

struct DownloadRecord: Codable, Identifiable, Hashable, Sendable {
    let fileID: String
    let fileName: String
    let relativePath: String
    let completedAt: Date
    var id: String { fileID }
}
