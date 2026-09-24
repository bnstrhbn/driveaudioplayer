import SwiftUI

/// Every screen in the browser is a navigation destination, including the
/// location listings, so Back always has somewhere to go and switching
/// locations from the title menu is itself an undoable step.
enum BrowserDestination: Hashable {
    case location(DriveLocation)
    case folder(DriveFile)
}

struct DriveBrowserView: View {
    @Environment(AppState.self) private var app
    @State private var path: [BrowserDestination] = [.location(.myDrive)]
    @State private var openedLaunchFolder = false

    var body: some View {
        NavigationStack(path: $path) {
            LocationsView(path: $path)
                .navigationDestination(for: BrowserDestination.self) { destination in
                    switch destination {
                    case .location(let location): LocationView(location: location, path: $path).id(location)
                    case .folder(let file): FolderView(folder: file, driveID: file.driveId, path: $path).id(file.id)
                    }
                }
        }
        .task {
            guard !openedLaunchFolder, let favorite = app.favorites.launchFolder else { return }
            openedLaunchFolder = true
            path.append(.folder(favorite.file))
        }
    }
}

/// The root of the browser: a plain list of places to browse.
private struct LocationsView: View {
    @Environment(AppState.self) private var app
    @Binding var path: [BrowserDestination]

    var body: some View {
        List(DriveLocation.allCases) { location in
            NavigationLink(value: BrowserDestination.location(location)) {
                Label(location.title, systemImage: location.symbolName)
            }
        }
        .navigationTitle("Drive Audio")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { AccountMenu() }
        }
        .safeAreaInset(edge: .bottom) { if app.player.current != nil { MiniPlayerView() } }
    }
}

private struct LocationView: View {
    @Environment(AppState.self) private var app
    let location: DriveLocation
    @Binding var path: [BrowserDestination]
    @State private var files: [DriveFile] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        FileListView(
            contents: files,
            isLoading: isLoading,
            empty: (location.emptyTitle, location.symbolName, location.emptyMessage),
            refresh: load,
            batchID: "location-\(location.rawValue)",
            showsSharingInfo: location == .sharedWithMe
        )
        .navigationTitle(location.title)
        .navigationBarTitleDisplayMode(.inline)
        .locationMenu(current: location, path: $path)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { AccountMenu() }
        }
        .safeAreaInset(edge: .bottom) { if app.player.current != nil { MiniPlayerView() } }
        .task(id: location) { await load() }
        .alert("Google Drive", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            switch location {
            case .myDrive: files = try await app.drive.folderContents(folderID: "root", driveID: nil)
            case .sharedWithMe: files = try await app.drive.sharedFolders()
            case .sharedDrives: files = try await app.drive.sharedDriveFolders()
            case .googleStarred: files = try await app.drive.starredFolders()
            case .appFavorites: files = app.favorites.folders.map(\.file)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private extension View {
    /// Tapping the navigation title lists the places to browse. Choosing one
    /// pushes it, so Back returns to the current screen. Available on every
    /// screen in the browser so switching drives never requires backing out.
    func locationMenu(current: DriveLocation?, path: Binding<[BrowserDestination]>) -> some View {
        toolbarTitleMenu {
            Section("Go to") {
                ForEach(DriveLocation.allCases) { option in
                    Button {
                        if option != current { path.wrappedValue.append(.location(option)) }
                    } label: {
                        Label(option.title, systemImage: option.symbolName)
                    }
                    .disabled(option == current)
                }
            }
        }
    }
}

private struct AccountMenu: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Menu {
            Section("Cached on Wi‑Fi while playing (up to 1 GB)") {
                Button("Clear Cache (\(ByteCountFormatter.string(fromByteCount: app.cache.totalBytes, countStyle: .file)))", systemImage: "internaldrive") { app.cache.clear() }
                    .disabled(app.cache.totalBytes == 0)
            }
            Button("Sign Out", role: .destructive) { Task { await app.signOut() } }
        } label: {
            Image(systemName: "person.crop.circle")
        }
        .accessibilityLabel("Account")
    }
}

extension DriveLocation {
    var title: String {
        switch self {
        case .myDrive: "My Drive"
        case .sharedWithMe: "Shared with me"
        case .sharedDrives: "Shared drives"
        case .googleStarred: "Starred"
        case .appFavorites: "App Favorites"
        }
    }
    var symbolName: String {
        switch self {
        case .myDrive: "externaldrive"
        case .sharedWithMe: "person.2.fill"
        case .sharedDrives: "person.3.fill"
        case .googleStarred: "star.fill"
        case .appFavorites: "folder.badge.star"
        }
    }
    var emptyTitle: String {
        switch self {
        case .myDrive: "Nothing in My Drive"
        case .sharedWithMe: "Nothing shared with you"
        case .sharedDrives: "No shared drives"
        case .googleStarred: "Nothing starred"
        case .appFavorites: "No favorites yet"
        }
    }
    var emptyMessage: String {
        switch self {
        case .appFavorites: "Save a folder with its star button to find it here."
        case .sharedWithMe: "Audio files and folders shared with you will appear here."
        case .sharedDrives: "Shared drives with audio will appear here."
        case .googleStarred: "Star audio files or folders in Google Drive to find them here."
        case .myDrive: "No audio files or folders found."
        }
    }
}

struct FolderView: View {
    @Environment(AppState.self) private var app
    let folder: DriveFile
    let driveID: String?
    @Binding var path: [BrowserDestination]
    @State private var contents: [DriveFile] = []
    @State private var isLoading = true
    @State private var error: String?
    /// Where this folder lives in Drive. Resolved from Drive because Back isn't
    /// always the parent (e.g. a favorite opened at launch, or a folder reached
    /// from Starred). nil until resolved.
    @State private var hierarchy: DriveHierarchy?

    var body: some View {
        FileListView(
            contents: contents,
            isLoading: isLoading,
            empty: ("Empty Folder", "folder", "No audio files or folders here."),
            refresh: load,
            batchID: folder.contentID
        )
        .navigationTitle(folder.name).navigationBarTitleDisplayMode(.inline)
        .locationMenu(current: nil, path: $path)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: goUp) {
                    Label("Up", systemImage: "arrow.turn.left.up")
                        .labelStyle(.titleAndIcon)
                }
                .disabled(hierarchy == nil)
                .accessibilityLabel(upAccessibilityLabel)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    app.favorites.toggle(folder, driveID: driveID)
                } label: {
                    Image(systemName: app.favorites.contains(folder, driveID: driveID) ? "star.fill" : "star")
                }
                .accessibilityLabel(app.favorites.contains(folder, driveID: driveID) ? "Remove folder from favorites" : "Save folder as favorite")
            }
        }
        .safeAreaInset(edge: .bottom) { if app.player.current != nil { MiniPlayerView() } }
        .task(id: folder.id) { await load() }
        .task(id: folder.id) { hierarchy = try? await app.drive.hierarchy(of: folder, driveID: driveID) }
        .alert("Drive Audio", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
    }
    private var upAccessibilityLabel: String {
        guard let hierarchy else { return "Up one level" }
        return "Up to \(hierarchy.ancestors.last?.name ?? hierarchy.location.title)"
    }
    private func load() async { isLoading = true; defer { isLoading = false }; do { contents = try await app.drive.folderContents(folderID: folder.contentID, driveID: driveID) } catch { self.error = error.localizedDescription } }

    /// Navigates to the parent: the folder above this one, or — at the top of a
    /// tree — the location it belongs to (My Drive, Shared with me, Shared drives).
    /// Up is a forward step in history so Back always returns to the previous
    /// screen; the one exception is when the parent *is* the previous screen,
    /// where popping is equivalent and avoids stacking duplicates.
    private func goUp() {
        guard let hierarchy else { return }
        let target: BrowserDestination = hierarchy.ancestors.last.map(BrowserDestination.folder) ?? .location(hierarchy.location)
        let previous = path.count >= 2 ? path[path.count - 2] : nil
        if previous?.matches(target) == true {
            path.removeLast()
        } else {
            path.append(target)
        }
    }
}

private extension BrowserDestination {
    /// Same screen, ignoring incidental metadata differences between two
    /// `DriveFile` values for the same folder (e.g. one loaded from favorites).
    func matches(_ other: BrowserDestination) -> Bool {
        switch (self, other) {
        case (.location(let a), .location(let b)): a == b
        case (.folder(let a), .folder(let b)): a.id == b.id
        default: false
        }
    }
}

/// Shared folder/track list. Folders navigate, audio files play (with the
/// listed tracks as the playlist) and support offline download.
struct FileListView: View {
    @Environment(AppState.self) private var app
    let contents: [DriveFile]
    let isLoading: Bool
    let empty: (title: String, symbol: String, message: String)
    let refresh: () async -> Void
    /// Identifies this listing's folder-download batch (folder or location ID).
    let batchID: String
    /// Show who shared each item and when (Shared with me).
    var showsSharingInfo = false
    @State private var error: String?
    @State private var downloadsInProgress = Set<String>()
    @State private var confirmCellularDownload = false
    var tracks: [DriveFile] { contents.filter(\.isPlayableAudio) }
    private var downloadedTracks: [DriveFile] { tracks.filter(app.downloads.contains) }
    private var pendingBytes: Int64 { tracks.filter { !app.downloads.contains($0) && !app.cache.contains($0) }.compactMap { Int64($0.size ?? "") }.reduce(0, +) }

    var body: some View {
        List {
            if !tracks.isEmpty {
                Section {
                    Button { play(tracks[0]) } label: {
                        Label("Play Folder", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    folderDownloadRow
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                }
            }
            Section { ForEach(contents) { file in row(file) } }
        }
        .listStyle(.plain)
        .refreshable { await app.drive.invalidateAudioIndex(); await refresh() }
        .overlay {
            if isLoading && contents.isEmpty {
                ProgressView("Loading…")
            } else if contents.isEmpty {
                ContentUnavailableView(empty.title, systemImage: empty.symbol, description: Text(empty.message))
            }
        }
        .alert("Drive Audio", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
    }
    /// Track count plus the folder-level offline control: download all,
    /// live progress with cancel, or remove when everything is downloaded.
    private var folderDownloadRow: some View {
        HStack {
            Text("\(tracks.count) track\(tracks.count == 1 ? "" : "s")")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            if let batch = app.downloads.batches[batchID] {
                ProgressView(value: Double(batch.completed + batch.failed), total: Double(batch.total))
                    .frame(width: 80)
                Text("\(batch.completed + batch.failed) of \(batch.total)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button("Cancel", role: .cancel) { app.downloads.cancelBatch(batchID) }
                    .font(.footnote)
            } else if downloadedTracks.count == tracks.count {
                Menu {
                    Button("Remove Downloads", systemImage: "trash", role: .destructive) { app.downloads.deleteAll(downloadedTracks) }
                } label: {
                    Label("Downloaded", systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.green)
                }
            } else {
                Button {
                    if app.player.isOnExpensiveNetwork && pendingBytes > 0 { confirmCellularDownload = true } else { downloadAll() }
                } label: {
                    Label(downloadedTracks.isEmpty ? "Download All" : "Download Remaining", systemImage: "arrow.down.circle")
                        .font(.footnote.weight(.medium))
                }
                .confirmationDialog("Download \(ByteCountFormatter.string(fromByteCount: pendingBytes, countStyle: .file)) over cellular?", isPresented: $confirmCellularDownload, titleVisibility: .visible) {
                    Button("Download") { downloadAll() }
                } message: {
                    Text("You're not on Wi‑Fi. Downloading now will use cellular data and more battery.")
                }
            }
        }
        .buttonStyle(.borderless)
        .animation(.default, value: app.downloads.batches[batchID])
    }
    private func downloadAll() { app.downloadAll(tracks, batchID: batchID) }

    @ViewBuilder private func row(_ file: DriveFile) -> some View {
        if file.isFolder {
            NavigationLink(value: BrowserDestination.folder(file)) {
                HStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.tint)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.name).lineLimit(2)
                        sharingInfo(file)
                    }
                }
            }
        } else {
            let isCurrent = app.player.current?.id == file.id
            Button {
                play(file)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isCurrent ? "speaker.wave.2.fill" : "waveform")
                        .foregroundStyle(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.name)
                            .foregroundStyle(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                            .lineLimit(2)
                        HStack(spacing: 4) {
                            if let size = file.displaySize { Text(size) }
                            if let date = file.modifiedDate {
                                if file.displaySize != nil { Text("·") }
                                Text(date, format: .dateTime.month(.abbreviated).day().year())
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        sharingInfo(file)
                    }
                    Spacer(minLength: 8)
                    if downloadsInProgress.contains(file.id) { ProgressView() }
                    else if app.downloads.contains(file) { Image(systemName: "arrow.down.circle.fill").foregroundStyle(.green).accessibilityLabel("Downloaded") }
                    else if app.cache.contains(file) { Image(systemName: "internaldrive").foregroundStyle(.tertiary).accessibilityLabel("Cached for offline") }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
                .contextMenu { if !app.downloads.contains(file) { Button(app.cache.contains(file) ? "Keep Downloaded" : "Download for Offline", systemImage: "arrow.down.circle") { Task { await download(file) } } } else { Button("Remove Download", systemImage: "trash", role: .destructive) { app.downloads.delete(file) } } }
                .swipeActions { if !app.downloads.contains(file) { Button { Task { await download(file) } } label: { Label(app.cache.contains(file) ? "Keep" : "Download", systemImage: "arrow.down.circle") }.tint(.blue) } }
        }
    }
    @ViewBuilder private func sharingInfo(_ file: DriveFile) -> some View {
        if showsSharingInfo {
            let name = file.sharedByLabel
            let date = file.sharedWithMeDate ?? (file.isFolder ? file.modifiedDate : nil)
            if name != nil || date != nil {
                HStack(spacing: 4) {
                    Image(systemName: "person.crop.circle")
                    if let name { Text(name).lineLimit(1) }
                    if let date {
                        if name != nil { Text("·") }
                        Text(date, format: .dateTime.month(.abbreviated).day().year())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Shared by \(name ?? "unknown")\(date.map { " on \($0.formatted(date: .long, time: .omitted))" } ?? "")")
            }
        }
    }
    private func play(_ file: DriveFile) { Task { do { try await app.play(file, playlist: tracks) } catch { self.error = error.localizedDescription } } }
    private func download(_ file: DriveFile) async { downloadsInProgress.insert(file.id); defer { downloadsInProgress.remove(file.id) }; do { try await app.download(file) } catch { self.error = error.localizedDescription } }
}

struct MiniPlayerView: View {
    @Environment(AppState.self) private var app
    @State private var scrubPosition = 0.0
    @State private var isScrubbing = false

    private var progress: Double {
        guard app.player.duration > 0 else { return 0 }
        return min(max(app.player.currentTime / app.player.duration, 0), 1)
    }
    private var trackPosition: String? {
        guard let current = app.player.current,
              let index = app.player.playlist.firstIndex(of: current),
              app.player.playlist.count > 1 else { return nil }
        return "\(index + 1) of \(app.player.playlist.count)"
    }
    private var playlistTotal: String? {
        let (total, isComplete) = app.player.playlistDuration
        guard total > 0 else { return nil }
        return (isComplete ? "" : "≈") + time(total)
    }
    private var playlistSummary: String? {
        let parts = [trackPosition, playlistTotal].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .foregroundStyle(.tint)
                Text(app.player.current?.name ?? "")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let playlistSummary {
                    Text(playlistSummary)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                        .accessibilityLabel(playlistTotal.map { "Playlist total \($0)" } ?? "")
                }
            }

            // Fixed 0...1 range: SwiftUI's Slider doesn't reliably track a value
            // whose bounds change after creation (the duration arrives late).
            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubPosition : progress },
                    set: { scrubPosition = $0 }
                ),
                in: 0...1,
                onEditingChanged: { editing in
                    isScrubbing = editing
                    if !editing { app.player.seek(to: scrubPosition * app.player.duration) }
                }
            )
            .disabled(app.player.duration <= 0)
            .accessibilityLabel("Playback position")
            .accessibilityValue(time(app.player.currentTime))

            HStack(spacing: 0) {
                Text(time(app.player.currentTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)
                Spacer(minLength: 0)
                transportButton("backward.end.fill", label: "Previous track") { app.player.previous() }
                transportButton("gobackward.15", label: "Back 15 seconds") { app.player.seek(by: -15) }
                transportButton(app.player.isPlaying ? "pause.fill" : "play.fill", label: app.player.isPlaying ? "Pause" : "Play", size: .title) { app.player.toggle() }
                transportButton("goforward.15", label: "Forward 15 seconds") { app.player.seek(by: 15) }
                transportButton("forward.end.fill", label: "Next track") { _ = app.player.skip(forward: true) }
                Spacer(minLength: 0)
                Text("-" + time(max(app.player.duration - app.player.currentTime, 0)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .onChange(of: app.player.current?.id) { _, _ in scrubPosition = 0; isScrubbing = false }
    }

    private func transportButton(_ symbol: String, label: String, size: Font = .title3, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(size)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func time(_ interval: Double) -> String {
        let totalSeconds = max(Int(interval), 0)
        let (hours, minutes, seconds) = (totalSeconds / 3600, totalSeconds / 60 % 60, totalSeconds % 60)
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%d:%02d", minutes, seconds)
    }
}
