import SwiftUI
import Translation

extension View {
    // translationTask only exists on macOS 15+; on 14 the Apple provider is skipped.
    @ViewBuilder
    func appleTranslation(_ model: TranslatorModel) -> some View {
        if #available(macOS 15, *) {
            self.translationTask(model.appleConfig) { session in
                await model.runApple(session: session)
            }
        } else {
            self
        }
    }
}
