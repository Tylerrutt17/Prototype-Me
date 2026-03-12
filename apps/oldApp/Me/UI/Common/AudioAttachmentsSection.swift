import AVFoundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AudioAttachmentsSection: View {
    private enum ActiveSheet: String, Identifiable {
        case record
        case importFile
        var id: String { rawValue }
    }

    private let parentId: String
    private let kind: AudioAttachmentKind
    private let kindRawValue: String

    @Environment(\.modelContext) private var context
    @StateObject private var playback = AudioPlaybackController()
    @State private var activeSheet: ActiveSheet?
    @State private var errorMessage: String?
    @State private var deleteTarget: AudioAttachment?

    @Query private var attachments: [AudioAttachment]

    init(intervention: Intervention) {
        let id = intervention.id
        self.parentId = id
        self.kind = .directive
        self.kindRawValue = AudioAttachmentKind.directive.rawValue
        _attachments = Query(filter: #Predicate { $0.parentId == id && $0.kindRaw == "directive" },
                             sort: \AudioAttachment.createdAt)
    }

    init(note: NotePage) {
        let id = note.id
        self.parentId = id
        self.kind = .note
        self.kindRawValue = AudioAttachmentKind.note.rawValue
        _attachments = Query(filter: #Predicate { $0.parentId == id && $0.kindRaw == "note" },
                             sort: \AudioAttachment.createdAt)
    }

    var body: some View {
        Section("Voice Memos") {
            if attachments.isEmpty {
                Text("Attach a memo by importing from Files or recording.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(attachments, id: \.id) { attachment in
                    HStack {
                        Button {
                            playback.togglePlay(attachment: attachment)
                        } label: {
                            Image(systemName: playback.currentlyPlayingId == attachment.id ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 26))
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(attachment.displayName)
                            Text("\(formatDuration(displayDuration(for: attachment))) • \(formatSize(attachment.fileSizeBytes))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            deleteTarget = attachment
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Button {
                    activeSheet = .importFile
                } label: {
                    Label("Import audio", systemImage: "square.and.arrow.down")
                }.disabled(activeSheet != nil)
                Spacer()
                Button {
                    activeSheet = .record
                } label: {
                    Label("Record", systemImage: "mic")
                }.disabled(activeSheet != nil)
            }
        }
        .alert("Audio Error", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            if let message = errorMessage { Text(message) }
        }
        .confirmationDialog("Delete this voice memo?", isPresented: Binding(get: {
            deleteTarget != nil
        }, set: { newVal in
            if !newVal { deleteTarget = nil }
        }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let target = deleteTarget { delete(attachment: target) }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        }
        .fileImporter(isPresented: Binding(get: {
            activeSheet == .importFile
        }, set: { newVal in
            if !newVal, activeSheet == .importFile { activeSheet = nil }
        }), allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url):
                Task { await handleImport(url: url) }
                activeSheet = nil
            case .failure:
                errorMessage = "Could not import that file."
                activeSheet = nil
            }
        }
        .sheet(item: Binding(get: {
            activeSheet == .record ? ActiveSheet.record : nil
        }, set: { _ in
            activeSheet = nil
        })) { _ in
            AudioRecorderSheet { url, duration, name in
                let fileName = name.isEmpty ? "Recording" : name
                Task { await handleImportedFile(url: url,
                                                duration: duration,
                                                suggestedName: "\(fileName).m4a") }
                activeSheet = nil
            }
        }
    }

    private func delete(attachment: AudioAttachment) {
        AudioAttachmentStore.shared.remove(fileName: attachment.fileName)
        context.delete(attachment)
        try? context.save()
        if playback.currentlyPlayingId == attachment.id {
            playback.stop()
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let intVal = Int(seconds.rounded())
        let minutes = intVal / 60
        let secs = intVal % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1024 { return String(format: "%.0f KB", kb) }
        let mb = kb / 1024.0
        return String(format: "%.1f MB", mb)
    }

    private func displayDuration(for attachment: AudioAttachment) -> Double {
        if attachment.durationSeconds > 0 { return attachment.durationSeconds }
        if let url = try? AudioAttachmentStore.shared.url(for: attachment.fileName) {
            let asset = AVURLAsset(url: url)
            let seconds = CMTimeGetSeconds(asset.duration)
            return seconds.isFinite ? seconds : 0
        }
        return 0
    }

    private func handleImport(url: URL) async {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        await handleImportedFile(url: url, duration: duration, suggestedName: url.lastPathComponent)
    }

    @MainActor
    private func handleImportedFile(url: URL, duration: Double, suggestedName: String) async {
        do {
            let store = AudioAttachmentStore.shared
            let (fileName, size) = try store.copyIn(from: url, suggestedName: suggestedName)

            let attachment = AudioAttachment(fileName: fileName,
                                             displayName: suggestedName,
                                             durationSeconds: duration,
                                             fileSizeBytes: Int(size),
                                             kind: kind,
                                             parentId: parentId,
                                             createdAt: Date())
            context.insert(attachment)
            try context.save()
        } catch AudioAttachmentStoreError.fileTooLarge {
            errorMessage = "That file is too large (max 30 MB)."
        } catch {
            errorMessage = "Could not save that audio file."
        }
    }
}

private struct AudioRecorderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = AudioRecorderController()
    @State private var recordingName: String = "Recording"
    let onSaved: (URL, Double, String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Recording")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(timeString(recorder.elapsed))
                        .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                }

                Circle()
                    .trim(from: 0, to: min(1, recorder.elapsed / 60))
                    .stroke(AngularGradient(gradient: Gradient(colors: [.red, .orange, .red]),
                                            center: .center),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .overlay(
                        Circle()
                            .fill(recorder.isRecording ? Color.red.opacity(0.15) : Color.gray.opacity(0.12))
                            .frame(width: 160, height: 160)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("Recording name", text: $recordingName)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                }
                .padding(.horizontal, 8)

                HStack(spacing: 16) {
                    Button(role: .cancel) {
                        recorder.cancel()
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                    }

                    if recorder.isRecording {
                        Button {
                            if let result = recorder.stop() {
                                onSaved(result.url, result.duration, sanitizedName(recordingName))
                            }
                            dismiss()
                        } label: {
                            Label("Stop", systemImage: "stop.circle.fill")
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(Color.red)
                                .foregroundStyle(.white)
                                .cornerRadius(14)
                        }
                    } else {
                        Button {
                            Task {
                                do {
                                    _ = try await recorder.start()
                                } catch {
                                    recorder.errorMessage = "Microphone permission or recording failed."
                                }
                            }
                        } label: {
                            Label("Record", systemImage: "circle.fill")
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .cornerRadius(14)
                        }
                    }
                }

                if let error = recorder.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .padding(.top, 4)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .navigationTitle("Record memo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        recorder.cancel()
                        dismiss()
                    }
                }
            }
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let intVal = Int(seconds.rounded())
        let minutes = intVal / 60
        let secs = intVal % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func sanitizedName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Recording" }
        return trimmed
    }
}
