import SwiftUI

@main
struct MyApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var appDelegate
    @StateObject private var job: Transcription
    @StateObject private var updates: UpdateCoordinator

    init() {
        let job = Transcription()
        _job = StateObject(wrappedValue: job)
        _updates = StateObject(wrappedValue: UpdateCoordinator(job: job))
    }

    var body: some Scene {
        Window("WhisperDrop", id: "main") {
            ContentView(job: job)
                .onAppear { appDelegate.job = job }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…", action: updates.checkForUpdates)
                    .disabled(!updates.canCheck)
            }
        }
        .defaultSize(width: 540, height: 600)

        Settings {
            ConfigurationView(job: job)
        }
    }
}

private struct ConfigurationView: View {
    @ObservedObject var job: Transcription
    var body: some View {
        Form {
            Section("Native Whisper") {
                Text(job.configurationState).textSelection(.enabled)
                Text("Models are stored in ~/Library/Application Support/WhisperDrop/Models. Choose a model in the main window to download it.")
                    .foregroundStyle(.secondary)
                Button("Check Configuration", action: job.detect).disabled(job.running || job.downloading)
            }
        }
        .formStyle(.grouped)
        .frame(width: 550, height: 240)
    }
}
