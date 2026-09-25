import SwiftUI
import UIKit

/// Text entry for a note at a fixed point in a track. Presented after
/// playback has been paused so the timestamp is exactly where the user heard
/// something; playback resumes when the sheet closes.
struct NoteEditorSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let file: DriveFile
    /// Existing note to edit, or nil to create one at `timestamp`.
    var note: TrackNote? = nil
    @State var timestamp: Double
    @State private var text: String
    @FocusState private var focused: Bool

    init(file: DriveFile, timestamp: Double, note: TrackNote? = nil) {
        self.file = file
        self.note = note
        _timestamp = State(initialValue: note?.timestamp ?? timestamp)
        _text = State(initialValue: note?.text ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What did you hear?", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($focused)
                        .submitLabel(.done)
                } header: {
                    Text(file.name).lineLimit(2).textCase(nil)
                }
                Section("Time in track") {
                    HStack {
                        Text(TrackNote.format(timestamp))
                            .font(.title3.monospacedDigit().weight(.semibold))
                        Spacer()
                        Stepper("", value: $timestamp, in: 0...max(app.player.duration, timestamp), step: 1)
                            .labelsHidden()
                            .accessibilityLabel("Adjust time by one second")
                    }
                }
            }
            .navigationTitle(note == nil ? "Note Here" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let note { app.notes.update(note, text: text, timestamp: timestamp) }
                        else { app.notes.add(text, at: timestamp, to: file, folderName: app.playlistTitle) }
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }
}

/// All notes for one track, with jump-to-time, edit, delete and export.
struct TrackNotesSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let file: DriveFile
    @State private var editing: TrackNote?
    @State private var copied = false

    private var notes: [TrackNote] { app.notes.notes(for: file) }

    var body: some View {
        NavigationStack {
            List {
                ForEach(notes) { note in
                    Button { editing = note } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Button {
                                jump(to: note.timestamp)
                            } label: {
                                Text(note.timestampLabel)
                                    .font(.subheadline.monospacedDigit().weight(.semibold))
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(.tint.opacity(0.15), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Play from \(note.timestampLabel)")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.text)
                                Text(note.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions { Button(role: .destructive) { app.notes.delete(note) } label: { Label("Delete", systemImage: "trash") } }
                }
            }
            .listStyle(.plain)
            .overlay {
                if notes.isEmpty {
                    ContentUnavailableView("No Notes Yet", systemImage: "note.text", description: Text("Tap Note in the player while listening to mark a moment."))
                }
            }
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    NotesExportMenu(text: app.notes.export(track: file), subject: "Notes — \(file.name)")
                        .disabled(notes.isEmpty)
                }
            }
            .sheet(item: $editing) { note in NoteEditorSheet(file: file, timestamp: note.timestamp, note: note) }
        }
        .presentationDetents([.medium, .large])
    }

    private func jump(to time: Double) {
        guard app.player.current?.id == file.id else { return }
        app.player.seek(to: time)
        if !app.player.isPlaying { app.player.toggle() }
    }
}

/// Copy-to-clipboard or share sheet for an export string.
struct NotesExportMenu: View {
    let text: String
    let subject: String
    @State private var copied = false

    var body: some View {
        Menu {
            Button {
                UIPasteboard.general.string = text
                copied = true
                Task { try? await Task.sleep(for: .seconds(2)); copied = false }
            } label: { Label("Copy Notes", systemImage: "doc.on.doc") }
            ShareLink(item: text, subject: Text(subject)) { Label("Share Notes…", systemImage: "square.and.arrow.up") }
        } label: {
            Label(copied ? "Copied" : "Export", systemImage: copied ? "checkmark" : "square.and.arrow.up")
                .labelStyle(.titleAndIcon)
        }
        .accessibilityLabel("Export notes")
    }
}
