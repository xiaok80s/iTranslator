import Foundation
import SwiftUI
import Translation

@MainActor
final class TranslatorModel: ObservableObject {
    @Published var source: Language = .english { didSet { if oldValue != source { scheduleTranslate(immediately: true) } } }
    @Published var target: Language = .chinese { didSet { if oldValue != target { scheduleTranslate(immediately: true) } } }
    @Published var input = "" { didSet { if oldValue != input { scheduleTranslate() } } }
    @Published var output = ""
    @Published var provider = ""
    @Published var isLoading = false
    @Published var errorText = ""

    // Apple Translation (macOS 15+) runs inside a SwiftUI .translationTask, so the view drives the session.
    @Published var appleConfigStorage: Any?
    @available(macOS 15, *)
    var appleConfig: TranslationSession.Configuration? {
        get { appleConfigStorage as? TranslationSession.Configuration }
        set { appleConfigStorage = newValue }
    }
    private var appleText = ""
    private var appleContinuation: CheckedContinuation<String, Error>?
    private var appleRequestID = 0

    private var task: Task<Void, Never>?

    func swapLanguages() {
        let (s, t) = (source, target)
        let newInput = output.isEmpty ? input : output
        source = t
        target = s
        input = newInput
    }

    private func scheduleTranslate(immediately: Bool = false) {
        task?.cancel()
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            output = ""; provider = ""; errorText = ""; isLoading = false
            return
        }
        isLoading = true
        task = Task { [source, target] in
            if !immediately {
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            if Task.isCancelled { return }
            await run(text, source, target)
        }
    }

    private func run(_ text: String, _ from: Language, _ to: Language) async {
        var lastError = ""
        let providers = ProviderSettings.active
        guard !providers.isEmpty else {
            output = ""; provider = ""; errorText = "No translation provider enabled"; isLoading = false
            return
        }
        for p in providers {
            if Task.isCancelled { return }
            let name = p.title
            do {
                let result: String
                switch p {
                case .google:
                    result = try await GoogleTranslator.translate(text, from: from, to: to)
                case .apple:
                    guard #available(macOS 15, *) else { throw TranslationError(message: "requires macOS 15") }
                    result = try await appleTranslate(text, from, to)
                case .llm:
                    result = try await LLMTranslator.translate(text, from: from, to: to)
                }
                if Task.isCancelled { return }
                output = result; provider = name; errorText = ""; isLoading = false
                return
            } catch {
                if Task.isCancelled { return }
                lastError = "\(name): \(error.localizedDescription)"
            }
        }
        output = ""; provider = ""; errorText = lastError; isLoading = false
    }

    @available(macOS 15, *)
    private func appleTranslate(_ text: String, _ from: Language, _ to: Language) async throws -> String {
        finishApple(.failure(CancellationError()))
        appleText = text
        appleRequestID += 1
        let requestID = appleRequestID
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                appleContinuation = cont
                // Reuse the config and invalidate it so the same language pair re-triggers the task.
                if var config = appleConfig, config.source == from.locale, config.target == to.locale {
                    config.invalidate()
                    appleConfig = config
                } else {
                    appleConfig = TranslationSession.Configuration(source: from.locale, target: to.locale)
                }
                // Generous: the first use may wait on the language pack download dialog.
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 45_000_000_000)
                    guard let self, self.appleRequestID == requestID else { return }
                    self.finishApple(.failure(TranslationError(message: "timed out (language pack not installed?)")))
                }
            }
        } onCancel: {
            Task { @MainActor in self.finishApple(.failure(CancellationError())) }
        }
    }

    @available(macOS 15, *)
    func runApple(session: TranslationSession) async {
        let text = appleText
        do {
            let resp = try await session.translate(text)
            finishApple(.success(resp.targetText))
        } catch {
            finishApple(.failure(error))
        }
    }

    private func finishApple(_ result: Result<String, Error>) {
        guard let cont = appleContinuation else { return }
        appleContinuation = nil
        cont.resume(with: result)
    }

    // True while Apple may be showing a language-download dialog that steals focus from the panel.
    var appleBusy: Bool { appleContinuation != nil }
}
