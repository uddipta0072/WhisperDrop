import AppKit
import AVFoundation
import Combine
import CryptoKit
import Foundation

struct LocalModel: Identifiable {
    let id: String
    let name: String
    let backendID: String
    let translates: Bool
    let multilingual: Bool
    let downloaded: Bool
}

private final class HTTPSRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url?.scheme?.lowercased() == "https" ? request : nil)
    }
}

@MainActor
final class Transcription: ObservableObject {
    enum Destination: String, CaseIterable, Identifiable {
        case beside = "Beside Original", desktop = "Desktop", custom = "Custom Folder"
        var id: Self { self }
    }
    private let preferences = UserDefaults.standard
    private let catalog = ["tiny", "base.en", "base", "small", "medium", "large-v3-turbo", "large-v3"]
    // SHA-256 values from the model files in ggerganov/whisper.cpp on Hugging Face.
    nonisolated private static let hashes = [
        "tiny": "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21",
        "base.en": "a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002",
        "base": "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe",
        "small": "1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b",
        "medium": "6c14d5adee5f86394037b4e4e8b59f1673b6cee10e3cf0b11bbdbee79c156208",
        "large-v3-turbo": "1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69",
        "large-v3": "64d182b440b98d5203c4f9bd541544d84c605196c4f7b845dfa11fb23594d1e2"
    ]
    nonisolated private static func digest(_ file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var sha = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty { sha.update(data: chunk) }
        return sha.finalize().map { String(format: "%02x", $0) }.joined()
    }
    private var process: Process?
    private let redirectDelegate = HTTPSRedirectDelegate()
    private var networkTask: URLSessionDownloadTask?
    private var networkSession: URLSession?
    private var progressTask: Task<Void, Never>?
    private var downloadTask: Task<Void, Never>?
    private var timer: Task<Void, Never>?
    private var cancelled = false
    private var started = Date()
    private var completionSound: NSSound?
    private var modelDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/WhisperDrop/Models", isDirectory: true)
    }
    private var runtime: URL? { Bundle.main.resourceURL?.appendingPathComponent("NativeRuntime") }
    @Published var updatePending = false
    @Published var input: URL?
    @Published var duration: Double?
    @Published var models: [LocalModel] = []
    @Published var formats = ["srt", "vtt", "txt", "json"]
    @Published var languages = ["en":"English", "es":"Spanish", "fr":"French", "de":"German", "hi":"Hindi", "ja":"Japanese", "zh":"Chinese", "it":"Italian", "pt":"Portuguese", "ru":"Russian", "ko":"Korean"]
    @Published var selectedModel = "base" { didSet { preferences.set(selectedModel, forKey: "nativeModel") } }
    @Published var selectedFormats: Set<String> = ["srt"] { didSet { preferences.set(selectedFormats.sorted(), forKey: "formats") } }
    @Published var destination: Destination = .beside { didSet { preferences.set(destination.rawValue, forKey: "destination") } }
    @Published var customFolder = "" { didSet { preferences.set(customFolder, forKey: "customFolder") } }
    @Published var language = "" { didSet { preferences.set(language, forKey: "language") } }
    @Published var task = "transcribe" { didSet { preferences.set(task, forKey: "task") } }
    @Published private(set) var configurationState = ""
    @Published private(set) var scanning = false
    @Published private(set) var running = false
    @Published private(set) var downloading = false
    @Published private(set) var downloadedBytes: Int64 = 0
    @Published private(set) var totalBytes: Int64 = 0
    @Published private(set) var status = ""
    @Published private(set) var device = ""
    @Published private(set) var progress: Int?
    @Published private(set) var elapsed = 0
    @Published private(set) var outputs: [URL] = []
    @Published private(set) var error: String?
    @Published private(set) var log = ""
    @Published private(set) var logURL: URL?
    var model: LocalModel? { models.first { $0.id == selectedModel } }
    var outputFolder: URL? {
        switch destination {
        case .beside: return input?.deletingLastPathComponent()
        case .desktop: return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        case .custom: return customFolder.isEmpty ? nil : URL(fileURLWithPath: customFolder, isDirectory: true)
        }
    }
    var ready: Bool { !updatePending && !running && !downloading && !scanning && input != nil && outputFolder != nil && model?.downloaded == true && !selectedFormats.isDisjoint(with: formats) && runtimeReady }
    private var runtimeReady: Bool {
        guard let runtime else { return false }
        return ["whisper-cli", "ffmpeg"].allSatisfy { FileManager.default.isExecutableFile(atPath: runtime.appendingPathComponent($0).path) }
    }
    init() {
        selectedModel = preferences.string(forKey: "nativeModel") ?? "base"
        selectedFormats = Set(preferences.stringArray(forKey: "formats") ?? ["srt"])
        destination = Destination(rawValue: preferences.string(forKey: "destination") ?? "") ?? .beside
        customFolder = preferences.string(forKey: "customFolder") ?? ""
        language = preferences.string(forKey: "language") ?? ""
        task = preferences.string(forKey: "task") ?? "transcribe"
    }
    private func modelURL(_ id: String) -> URL { modelDirectory.appendingPathComponent("ggml-\(id).bin") }
    func detect() {
        guard !scanning, !running else { return }
        scanning = true
        let directory = modelDirectory
        let ids = catalog
        configurationState = "Checking local model checksums…"
        Task {
            let valid = await Task.detached(priority: .utility) {
                var result = Set<String>()
                for id in ids {
                    let path = directory.appendingPathComponent("ggml-\(id).bin")
                    if FileManager.default.fileExists(atPath: path.path),
                       (try? Self.digest(path)) == Self.hashes[id] { result.insert(id) }
                }
                return result
            }.value
            models = ids.map { id in
                LocalModel(id: id, name: "\(id)\(valid.contains(id) ? " — Installed" : " — Download")", backendID: id,
                           translates: id != "large-v3-turbo" && id != "base.en", multilingual: id != "base.en", downloaded: valid.contains(id))
            }
            if !ids.contains(selectedModel) { selectedModel = "base" }
            configurationState = runtimeReady ? "Native engine ready. Download or import a verified GGML model." : "Bundled engine or media converter is missing."
            scanning = false
        }
    }
    private func storeVerifiedModel(_ source: URL, id: String) async throws {
        guard let expected = Self.hashes[id] else { throw CocoaError(.fileReadCorruptFile) }
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        let staging = modelDirectory.appendingPathComponent(".import-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: staging) }
        try await Task.detached(priority: .utility) { try FileManager.default.copyItem(at: source, to: staging) }.value
        try Task.checkCancellation()
        let actual = try await Task.detached(priority: .utility) { try Self.digest(staging) }.value
        try Task.checkCancellation()
        guard actual == expected else { throw NSError(domain: "WhisperDrop", code: 3, userInfo: [NSLocalizedDescriptionKey: "The model SHA-256 does not match the official \(id) model. No model was installed."]) }
        // Never overwrite a pre-existing file, including an invalid one.
        try FileManager.default.moveItem(at: staging, to: modelURL(id))
    }
    func importModel(_ source: URL) {
        guard !updatePending, !downloading, !scanning, let model else { return }
        let id = model.id
        downloading = true; error = nil; status = "Importing and verifying \(id)"; progress = nil
        downloadTask = Task {
            let accessed = source.startAccessingSecurityScopedResource()
            defer { if accessed { source.stopAccessingSecurityScopedResource() }; downloading = false; downloadTask = nil }
            do {
                try await storeVerifiedModel(source, id: id)
                status = "Model imported"; detect()
            } catch {
                if Task.isCancelled { status = "Import cancelled" } else { self.error = error.localizedDescription; status = "Failed" }
            }
        }
    }
    func removeModel() {
        guard !running, !downloading, !scanning, let model, model.downloaded else { return }
        do {
            var trashed: NSURL?
            try FileManager.default.trashItem(at: modelURL(model.id), resultingItemURL: &trashed)
            status = "Model moved to Trash"; error = nil; detect()
        } catch {
            self.error = "Could not remove model: \(error.localizedDescription)"; status = "Failed"
        }
    }
    func downloadModel() {
        guard !updatePending, !downloading, !scanning, !running, let model, !model.downloaded else { return }
        let id = model.id
        let target = modelURL(id)
        guard !FileManager.default.fileExists(atPath: target.path) else {
            error = "A file already exists at \(target.path), but its checksum did not match. Move it elsewhere before downloading."; status = "Failed"; return
        }
        guard let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-\(id).bin") else { return }
        downloading = true; error = nil; log = ""; status = "Downloading \(id)"; progress = nil
        downloadedBytes = 0; totalBytes = 0
        downloadTask = Task {
            defer { progressTask?.cancel(); progressTask = nil; networkTask = nil; networkSession?.finishTasksAndInvalidate(); networkSession = nil; downloading = false; downloadTask = nil }
            do {
                try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
                let staging = modelDirectory.appendingPathComponent(".download-\(UUID().uuidString)")
                defer { try? FileManager.default.removeItem(at: staging) }
                let configuration = URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForRequest = 60
                let session = URLSession(configuration: configuration, delegate: redirectDelegate, delegateQueue: nil)
                networkSession = session
                let response: URLResponse = try await withCheckedThrowingContinuation { continuation in
                    let transfer = session.downloadTask(with: url) { temporary, response, failure in
                        if let failure { continuation.resume(throwing: failure); return }
                        guard let temporary, let response else { continuation.resume(throwing: URLError(.unknown)); return }
                        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                            continuation.resume(throwing: NSError(domain: "HTTP", code: code, userInfo: [NSLocalizedDescriptionKey: "Model server returned HTTP \(code)."])); return
                        }
                        do { try FileManager.default.moveItem(at: temporary, to: staging); continuation.resume(returning: response) }
                        catch { continuation.resume(throwing: error) }
                    }
                    networkTask = transfer
                    progressTask = Task {
                        while !Task.isCancelled {
                            downloadedBytes = transfer.countOfBytesReceived
                            totalBytes = max(0, transfer.countOfBytesExpectedToReceive)
                            progress = totalBytes > 0 ? Int(min(100, downloadedBytes * 100 / totalBytes)) : nil
                            try? await Task.sleep(for: .milliseconds(200))
                        }
                    }
                    transfer.resume()
                }
                progressTask?.cancel(); progressTask = nil
                try Task.checkCancellation()
                if let expectedLength = response.expectedContentLength as Int64?, expectedLength > 0 { totalBytes = expectedLength }
                downloadedBytes = (try FileManager.default.attributesOfItem(atPath: staging.path)[.size] as? NSNumber)?.int64Value ?? downloadedBytes
                status = "Verifying \(id)"; progress = nil
                let actual = try await Task.detached(priority: .utility) { try Self.digest(staging) }.value
                try Task.checkCancellation()
                guard actual == Self.hashes[id] else { throw NSError(domain: "WhisperDrop", code: 3, userInfo: [NSLocalizedDescriptionKey: "SHA-256 mismatch for \(id). The downloaded model was not installed."]) }
                try FileManager.default.moveItem(at: staging, to: target)
                selectedModel = id; status = "Model installed"; detect()
            } catch {
                if Task.isCancelled || (error as NSError).code == NSURLErrorCancelled && (error as NSError).domain == NSURLErrorDomain { status = "Download cancelled" }
                else {
                    let detail = error as NSError
                    self.error = "\(detail.localizedDescription) (\(detail.domain), code \(detail.code))"
                    log = "Model: \(id)\nSource: \(url.absoluteString)\nError: \(detail.domain) code \(detail.code)\n\(detail.localizedDescription)\n"
                    status = "Failed"
                }
            }
        }
    }
    func select(_ file: URL) {
        guard !running, file.isFileURL, FileManager.default.isReadableFile(atPath: file.path) else { return }
        input = file; duration = nil; outputs = []; status = ""; error = nil; elapsed = 0
        Task { if let value = try? await AVURLAsset(url: file).load(.duration), input == file, value.seconds.isFinite { duration = value.seconds } }
    }
    func start() {
        guard ready, let input, let outputFolder, let model, let runtime else { return }
        running = true; cancelled = false; outputs = []; error = nil; log = ""; elapsed = 0; progress = nil; device = "Apple Silicon"; status = "Preparing"; started = Date()
        timer = Task { while !Task.isCancelled { try? await Task.sleep(for: .seconds(1)); elapsed = Int(Date().timeIntervalSince(started)) } }
        let chosenFormats = formats.filter(selectedFormats.contains)
        let modelFile = modelURL(model.id)
        let selectedLanguage = model.multilingual ? (language.isEmpty ? "auto" : language) : "en"
        let translate = model.translates && task == "translate"
        Task {
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent("WhisperDrop-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: temp); timer?.cancel(); timer = nil; running = false; process = nil }
            do {
                try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
                let wav = temp.appendingPathComponent("audio.wav")
                try await run(runtime.appendingPathComponent("ffmpeg"), ["-nostdin", "-hide_banner", "-loglevel", "error", "-protocol_whitelist", "file,pipe", "-i", input.path, "-map", "0:a:0", "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", wav.path], temp)
                if cancelled { throw CancellationError() }
                status = "Transcribing"
                let prefix = temp.appendingPathComponent("transcript")
                var args = ["-m", modelFile.path, "-f", wav.path, "-l", selectedLanguage, "-of", prefix.path]
                if translate { args.append("-tr") }
                for format in chosenFormats { args.append(format == "json" ? "-oj" : "-o\(format)") }
                try await run(runtime.appendingPathComponent("whisper-cli"), args, temp)
                if cancelled { throw CancellationError() }
                status = "Writing Files"
                var number = 1
                while true {
                    let stem = input.deletingPathExtension().lastPathComponent + (number == 1 ? "" : " (\(number))")
                    var created: [URL] = []
                    do {
                        for format in chosenFormats {
                            let source = prefix.appendingPathExtension(format)
                            let target = outputFolder.appendingPathComponent(stem).appendingPathExtension(format)
                            try FileManager.default.copyItem(at: source, to: target)
                            created.append(target)
                        }
                        outputs = created; break
                    } catch {
                        for url in created { try? FileManager.default.removeItem(at: url) }
                        if (error as NSError).domain == NSCocoaErrorDomain && (error as NSError).code == NSFileWriteFileExistsError { number += 1; continue }
                        throw error
                    }
                }
                status = "Completed"; completionSound = NSSound(named: "Glass"); _ = completionSound?.play()
            } catch is CancellationError { status = "Cancelled" }
            catch { status = "Failed"; self.error = error.localizedDescription }
        }
    }
    private func run(_ executable: URL, _ arguments: [String], _ temp: URL) async throws {
        let logFile = temp.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: logFile.path, contents: nil)
        let handle = try FileHandle(forWritingTo: logFile)
        let child = Process(); child.executableURL = executable; child.arguments = arguments; child.standardOutput = handle; child.standardError = handle; child.standardInput = FileHandle.nullDevice
        process = child
        try child.run()
        let code = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { child.waitUntilExit(); continuation.resume(returning: child.terminationStatus) }
        }
        try handle.close(); process = nil
        log += (try? String(contentsOf: logFile, encoding: .utf8)) ?? ""
        if cancelled { throw CancellationError() }
        guard code == 0 else { throw NSError(domain: "WhisperDrop", code: Int(code), userInfo: [NSLocalizedDescriptionKey: "\(executable.lastPathComponent) failed (exit \(code)). See the technical log."]) }
    }
    func cancel() {
        if downloading { status = "Cancelling"; networkTask?.cancel(); downloadTask?.cancel(); return }
        guard running else { return }; cancelled = true; status = "Cancelling"; if let process, process.isRunning { process.terminate() }
    }
}
