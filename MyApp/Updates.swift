import AppKit
import Combine
import Foundation
import SwiftUI
#if canImport(Sparkle)
import Sparkle
#endif

/// The updater remains off until a release supplies both an HTTPS feed and its Ed25519 public key.
@MainActor
final class UpdateCoordinator: NSObject, ObservableObject {
    @Published private(set) var canCheck = false
    private let job: Transcription
    #if canImport(Sparkle)
    private var controller: SPUStandardUpdaterController?
    private var observation: AnyCancellable?
    private var runningObservation: AnyCancellable?
    private var deferredInstall: (() -> Void)?
    #endif

    init(job: Transcription) {
        self.job = job
        super.init()
        #if canImport(Sparkle)
        runningObservation = job.$running.combineLatest(job.$downloading)
            .sink { [weak self] running, downloading in
                guard !running, !downloading else { return }
                Task { @MainActor [weak self] in
                    guard let self, !self.job.running, !self.job.downloading,
                          let resume = self.deferredInstall else { return }
                    self.deferredInstall = nil
                    resume()
                }
            }
        guard let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let url = URL(string: feed), url.scheme?.lowercased() == "https", url.host != nil,
              let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              let decodedKey = Data(base64Encoded: publicKey), decodedKey.count == 32,
              Bundle.main.object(forInfoDictionaryKey: "SUAllowsAutomaticUpdates") as? Bool == false,
              Bundle.main.object(forInfoDictionaryKey: "SUVerifyUpdateBeforeExtraction") as? Bool == true,
              Bundle.main.object(forInfoDictionaryKey: "SURequireSignedFeed") as? Bool == true,
              (Bundle.main.object(forInfoDictionaryKey: "SUSignedFeedFailureExpirationInterval") as? NSNumber)?.intValue == 0 else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        self.controller = controller
        observation = controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] value in self?.canCheck = value }
        controller.startUpdater()
        #endif
    }

    func checkForUpdates() {
        #if canImport(Sparkle)
        controller?.checkForUpdates(nil)
        #endif
    }
}

#if canImport(Sparkle)
extension UpdateCoordinator: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate item: SUAppcastItem,
                 updateCheck: SPUUpdateCheck) throws {
        guard let archive = item.fileURL, archive.scheme?.lowercased() == "https", archive.host != nil,
              item.releaseNotesURL.map({ $0.scheme?.lowercased() == "https" && $0.host != nil }) ?? true else {
            throw NSError(domain: "WhisperDrop.Updates", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "The update or release notes do not use HTTPS."])
        }
    }

    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem,
                 untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        guard job.running || job.downloading else { return false }
        job.updatePending = true
        deferredInstall = installHandler
        return true
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        deferredInstall = nil
        job.updatePending = false
    }
}
#endif

/// Sparkle may request termination through paths that do not call its relaunch delegate.
@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    weak var job: Transcription?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let job, job.running || job.downloading else { return .terminateNow }
        return .terminateCancel
    }
}
