import SwiftUI

/// Everything the app keeps on disk, with the controls to reclaim it.
struct StorageView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var confirmRemoveAll = false

    private var downloads: [DownloadRecord] { app.downloads.records.sorted { ($0.bytes ?? 0) > ($1.bytes ?? 0) } }
    private var unavailable: [DownloadRecord] { app.downloads.unavailable }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Downloads", value: StorageUtility.format(app.downloads.totalBytes))
                    LabeledContent("Played cache", value: StorageUtility.format(app.cache.totalBytes))
                    LabeledContent("Free on this iPhone", value: StorageUtility.format(StorageUtility.availableForOpportunisticUse))
                } footer: {
                    Text("Downloads and cached tracks are kept out of iCloud backup; they can always be fetched again from Drive. Notes and favorites are tiny and are backed up.")
                }

                Section {
                    Picker("Cache limit", selection: Binding(get: { app.cache.limit }, set: { app.cache.limit = $0 })) {
                        ForEach(PlaybackCache.limitOptions, id: \.self) { Text(StorageUtility.format($0)).tag($0) }
                    }
                    Button("Clear Played Cache", role: .destructive) { app.cache.clear() }
                        .disabled(app.cache.totalBytes == 0)
                } header: {
                    Text("Played cache")
                } footer: {
                    Text("Tracks you play on Wi‑Fi are cached so the next listen is instant. Least recently played tracks are removed first when the limit is reached, and caching pauses when the phone has under 1 GB free.")
                }

                if !unavailable.isEmpty {
                    Section {
                        ForEach(unavailable) { record in row(record) }
                        Button("Remove All Unavailable (\(StorageUtility.format(unavailable.reduce(0) { $0 + ($1.bytes ?? 0) })))", role: .destructive) { app.downloads.deleteUnavailable() }
                    } header: {
                        Text("No longer in Drive")
                    } footer: {
                        Text("These downloads were deleted, trashed or unshared in Google Drive. Your copies are kept until you remove them.")
                    }
                }

                Section {
                    if downloads.isEmpty {
                        Text("No downloads").foregroundStyle(.secondary)
                    } else {
                        ForEach(downloads.filter { $0.unavailableSince == nil }) { record in row(record) }
                    }
                } header: {
                    HStack {
                        Text("Downloads")
                        Spacer()
                        if app.isSweeping { ProgressView().controlSize(.mini) }
                        else { Button("Check with Drive") { Task { await app.sweepStorage(force: true) } }.font(.caption).textCase(nil) }
                    }
                } footer: {
                    Text("Swipe to remove a download. The app checks downloads against Drive about once a day on Wi‑Fi.")
                }
            }
            .navigationTitle("Storage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Remove All Downloads", role: .destructive) { confirmRemoveAll = true }
                        .disabled(downloads.isEmpty)
                }
            }
            .confirmationDialog("Remove all \(downloads.count) downloads (\(StorageUtility.format(app.downloads.totalBytes)))?", isPresented: $confirmRemoveAll, titleVisibility: .visible) {
                Button("Remove All", role: .destructive) { for record in downloads { app.downloads.delete(record: record) } }
            } message: {
                Text("Tracks can be downloaded again from Drive. Notes are not affected.")
            }
        }
    }

    private func row(_ record: DownloadRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.fileName).lineLimit(2)
                Text(record.completedAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(StorageUtility.format(record.bytes ?? 0))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .swipeActions { Button(role: .destructive) { app.downloads.delete(record: record) } label: { Label("Remove", systemImage: "trash") } }
    }
}
