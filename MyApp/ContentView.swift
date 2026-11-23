import AppKit
import Combine
import SwiftUI

struct ContentView: View {
    @ObservedObject var job: Transcription
    private final class ViewState: ObservableObject {
        @Published var isTargeted = false
        @Published var advanced = false
        @Published var showingLog = false
        @Published var confirmRemoval = false
    }

    @StateObject private var viewState = ViewState()

    private let formatNames = ["srt": "SubRip subtitles", "vtt": "WebVTT subtitles",
                               "txt": "Plain text", "json": "Transcription data", "tsv": "Timestamp table"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    dropZone
                    options
                    if job.scanning || job.models.isEmpty || job.model?.downloaded == false {
                        configurationNotice
                    }
                    if !job.status.isEmpty {
                        result
                    }
                }
                .padding(24)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            Divider()
            footer
        }
        .alert("Remove \(job.model?.id ?? "model")?", isPresented: $viewState.confirmRemoval) {
            Button("Remove", role: .destructive) { job.removeModel() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("The model will be moved to the Trash.") }
        .frame(minWidth: 500, minHeight: 500)
        .task { if job.configurationState.isEmpty { job.detect() } }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("WhisperDrop").font(.title2.weight(.semibold))
                Text("Transcribe audio and video on this Mac.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .help("WhisperDrop Settings")
            .accessibilityLabel("Settings")
        }
    }

    private var dropZone: some View {
        VStack(spacing: 7) {
            Image(systemName: job.input == nil ? "arrow.down.to.line" : "waveform.badge.magnifyingglass")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            if let input = job.input {
                Text(input.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(input.path)
                HStack(spacing: 5) {
                    if !input.pathExtension.isEmpty {
                        Text(input.pathExtension.uppercased())
                    }
                    if let duration = job.duration {
                        if !input.pathExtension.isEmpty { Text("·") }
                        Text(Self.timeString(Int(duration)))
                            .monospacedDigit()
                    }
                }
                .foregroundStyle(.secondary)
            } else {
                Text("Drop an audio or video file").font(.headline)
                Text("MP4, MOV, MKV, MP3, WAV, M4A and more")
                    .foregroundStyle(.secondary)
            }
            Button(job.input == nil ? "Browse…" : "Replace…") {
                if let file = choosePath(title: "Choose Audio or Video") { job.select(file) }
            }
            .disabled(job.running)
        }
        .frame(maxWidth: .infinity, minHeight: 126)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 13)
                .fill(viewState.isTargeted ? Color.accentColor.opacity(0.13) : Color.primary.opacity(0.025))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(viewState.isTargeted ? Color.accentColor : Color.secondary.opacity(0.42),
                              style: StrokeStyle(lineWidth: 1.25, dash: [5, 4]))
                .allowsHitTesting(false)
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard !job.running, urls.count == 1, let file = urls.first, file.isFileURL else { return false }
            job.select(file)
            return true
        } isTargeted: { viewState.isTargeted = $0 && !job.running }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 13) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 11) {
                GridRow {
                    Text("Model").fontWeight(.medium)
                    Picker("Model", selection: $job.selectedModel) {
                        if job.models.isEmpty {
                            Text(job.scanning ? "Checking local cache…" : "No local models").tag("")
                        }
                        ForEach(job.models) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel("Model")
                    .disabled(job.models.isEmpty || job.downloading)
                    HStack {
                        if job.model?.downloaded == false {
                            Button(job.downloading ? "Working…" : "Download") { job.downloadModel() }
                        }
                        if job.model?.downloaded == true {
                            Button("Remove…") { viewState.confirmRemoval = true }
                        }
                        Button("Import…") {
                            if let file = choosePath(title: "Choose Official GGML Model") { job.importModel(file) }
                        }
                    }
                    .disabled(job.downloading || job.scanning || job.model == nil)
                }
                GridRow {
                    Text("Formats").fontWeight(.medium)
                    HStack(spacing: 12) {
                        ForEach(job.formats.isEmpty ? ["srt"] : job.formats, id: \.self) { format in
                            Toggle(format.uppercased(), isOn: Binding(
                                get: { job.selectedFormats.contains(format) },
                                set: { enabled in
                                    if enabled { job.selectedFormats.insert(format) }
                                    else { job.selectedFormats.remove(format) }
                                }
                            ))
                            .toggleStyle(.checkbox)
                            .fixedSize(horizontal: true, vertical: false)
                            .help(formatNames[format] ?? format.uppercased())
                        }
                    }
                    .disabled(job.formats.isEmpty)
                    .gridCellColumns(2)
                }
                GridRow {
                    Text("Save to").fontWeight(.medium)
                    HStack {
                        Picker("Save to", selection: $job.destination) {
                            ForEach(Transcription.Destination.allCases) { destination in
                                Text(destination.rawValue).tag(destination)
                            }
                        }
                        .labelsHidden()
                        .accessibilityLabel("Save to")
                        if job.destination == .custom {
                            Button("Choose…", action: pickFolder)
                        }
                    }
                }
                if job.destination == .custom, !job.customFolder.isEmpty {
                    GridRow {
                        Color.clear.frame(width: 1, height: 1)
                        Text((job.customFolder as NSString).abbreviatingWithTildeInPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(job.customFolder)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            DisclosureGroup("Advanced Options", isExpanded: $viewState.advanced) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("Language")
                        Picker("Language", selection: $job.language) {
                            Text("Auto-detect").tag("")
                            ForEach(job.languages.keys.sorted {
                                (job.languages[$0] ?? $0) < (job.languages[$1] ?? $1)
                            }, id: \.self) { code in
                                Text((job.languages[code] ?? code).capitalized).tag(code)
                            }
                        }
                        .labelsHidden()
                        .accessibilityLabel("Language")
                        .disabled(job.model?.multilingual != true)
                    }
                    GridRow {
                        Text("Mode")
                        Picker("Mode", selection: Binding(
                            get: { job.model?.translates == true ? job.task : "transcribe" },
                            set: { job.task = $0 }
                        )) {
                            Text("Transcribe").tag("transcribe")
                            if job.model?.translates == true {
                                Text("Translate to English").tag("translate")
                            }
                        }
                        .labelsHidden()
                        .accessibilityLabel("Mode")
                    }
                }
                .padding(.top, 8)
            }
        }
        .disabled(job.running)
    }

    private var configurationNotice: some View {
        HStack(alignment: .firstTextBaseline) {
            Label(job.configurationState.isEmpty ? "Checking local Whisper installation…"
                  : job.configurationState,
                  systemImage: job.scanning ? "hourglass" : "exclamationmark.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            if !job.scanning { SettingsLink { Text("Open Settings") } }
        }
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                if job.status == "Completed" {
                    Label("Completed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else if job.status == "Failed" {
                    Label("Failed", systemImage: "exclamationmark.circle.fill").foregroundStyle(.red)
                } else {
                    Text(job.status)
                }
                Spacer()
                if (job.running || job.downloading), let progress = job.progress {
                    Text("\(progress)%").monospacedDigit()
                }
                Text(Self.timeString(job.elapsed))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Elapsed time \(Self.timeString(job.elapsed))")
            }
            .fontWeight(.medium)
            if job.running || job.downloading {
                if job.downloading, job.totalBytes > 0 {
                    Text("\(ByteCountFormatter.string(fromByteCount: job.downloadedBytes, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: job.totalBytes, countStyle: .file))")
                        .font(.caption).foregroundStyle(.secondary)
                } else if job.downloading, job.downloadedBytes > 0 {
                    Text("\(ByteCountFormatter.string(fromByteCount: job.downloadedBytes, countStyle: .file)) received")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let progress = job.progress {
                    ProgressView(value: Double(progress), total: 100)
                        .accessibilityLabel("Transcription progress")
                } else {
                    ProgressView().progressViewStyle(.linear)
                        .accessibilityLabel(job.status)
                }
            }
            if let error = job.error {
                Text(error).font(.callout).textSelection(.enabled)
                DisclosureGroup("Technical Log", isExpanded: $viewState.showingLog) {
                    ScrollView {
                        Text(job.log.isEmpty ? error : job.log)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 115)
                    if let url = job.logURL {
                        Button("Open Log") { NSWorkspace.shared.open(url) }
                    }
                }
            }
            if !job.outputs.isEmpty, job.status == "Completed" {
                ForEach(job.outputs, id: \.self) { file in
                    Label(file.lastPathComponent, systemImage: "doc.text")
                        .font(.callout)
                        .textSelection(.enabled)
                }
                HStack {
                    Button("Open Output Folder") {
                        if let file = job.outputs.first {
                            NSWorkspace.shared.open(file.deletingLastPathComponent())
                        }
                    }
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting(job.outputs)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
        .onChange(of: job.status) { _, status in
            if status == "Preparing" { viewState.showingLog = false }
        }
    }

    private var footer: some View {
        HStack {
            if job.running, !job.device.isEmpty {
                Text(job.device).font(.caption).foregroundStyle(.secondary)
            } else if job.input != nil, !job.formats.isEmpty, job.selectedFormats.isEmpty {
                Text("Select an output format.").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if job.running || job.downloading {
                Button("Cancel", role: .cancel, action: job.cancel)
                    .disabled(job.status == "Cancelling")
            } else {
                Button("Start Transcription", action: job.start)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!job.ready)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 13)
    }

    private func pickFolder() {
        if let folder = choosePath(title: "Choose Output Folder", files: false, folders: true) {
            job.customFolder = folder.path
        }
    }

    private static func timeString(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes >= 60 { return String(format: "%d:%02d:%02d", minutes / 60, minutes % 60, seconds % 60) }
        return String(format: "%d:%02d", minutes, seconds % 60)
    }
}

@MainActor
func choosePath(title: String, files: Bool = true, folders: Bool = false) -> URL? {
    let panel = NSOpenPanel()
    panel.title = title
    panel.prompt = "Choose"
    panel.allowsMultipleSelection = false
    panel.canChooseFiles = files
    panel.canChooseDirectories = folders
    panel.canCreateDirectories = folders && !files
    return panel.runModal() == .OK ? panel.url : nil
}
