import SwiftUI
import Translation

final class SettingsState: ObservableObject {
    @Published var show = false {
        didSet { NotificationCenter.default.post(name: .settingsToggled, object: show) }
    }
    @Published var baseURL = LLMSettings.baseURL { didSet { LLMSettings.baseURL = baseURL } }
    @Published var apiKey = LLMSettings.apiKey { didSet { LLMSettings.apiKey = apiKey } }
    @Published var llmModel = LLMSettings.model { didSet { LLMSettings.model = llmModel } }
    @Published var order = ProviderSettings.order { didSet { ProviderSettings.order = order } }
    @Published var disabled = ProviderSettings.disabled { didSet { ProviderSettings.disabled = disabled } }

    func move(_ p: Provider, by offset: Int) {
        guard let i = order.firstIndex(of: p) else { return }
        let j = i + offset
        guard order.indices.contains(j) else { return }
        order.swapAt(i, j)
    }

    func enabledBinding(_ p: Provider) -> Binding<Bool> {
        Binding(
            get: { p.isSupported && !self.disabled.contains(p) },
            set: { on in
                if on { self.disabled.remove(p) } else { self.disabled.insert(p) }
            })
    }
}

struct TranslatorView: View {
    @ObservedObject var model: TranslatorModel
    @StateObject private var s = SettingsState()
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                languagePicker($model.source)
                Button { model.swapLanguages() } label: { Image(systemName: "arrow.left.arrow.right") }
                    .buttonStyle(.borderless)
                    .help("Swap languages")
                languagePicker($model.target)
            }

            TextEditor(text: $model.input)
                .font(.body)
                .focused($inputFocused)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .textBackgroundColor).opacity(0.9)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.1)))
                .frame(height: 100)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05))
                ScrollView {
                    Group {
                        if !model.errorText.isEmpty {
                            Text(model.errorText).foregroundStyle(.red).font(.caption)
                        } else {
                            Text(model.output).textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                if model.isLoading {
                    ProgressView().controlSize(.small).padding(8).frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(maxHeight: .infinity)

            HStack {
                Text(model.provider.isEmpty ? "" : "via \(model.provider)")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { copyOutput() } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless).help("Copy translation")
                    .disabled(model.output.isEmpty)
                Button { s.show.toggle() } label: { Image(systemName: "gearshape") }
                    .buttonStyle(.borderless).help("Settings")
                Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                    .buttonStyle(.borderless).help("Quit")
            }

            if s.show {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Provider order (tried top to bottom)")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(s.order) { p in
                        HStack(spacing: 6) {
                            Toggle(p.isSupported ? p.title : "\(p.title) (requires macOS 15)", isOn: s.enabledBinding(p))
                                .disabled(!p.isSupported)
                            Spacer()
                            Button { s.move(p, by: -1) } label: { Image(systemName: "chevron.up") }
                                .disabled(p == s.order.first)
                            Button { s.move(p, by: 1) } label: { Image(systemName: "chevron.down") }
                                .disabled(p == s.order.last)
                        }
                        .buttonStyle(.borderless)
                    }
                    Divider().padding(.vertical, 2)
                    Text("LLM (OpenAI-compatible)")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("Base URL", text: $s.baseURL)
                    SecureField("API Key", text: $s.apiKey)
                    TextField("Model", text: $s.llmModel)
                }
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .frame(width: 340, height: s.show ? 580 : 360)
        .onAppear { inputFocused = true }
        .appleTranslation(model)
    }

    private func languagePicker(_ selection: Binding<Language>) -> some View {
        Picker("", selection: selection) {
            ForEach(Language.all) { Text($0.name).tag($0) }
        }
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }

    private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.output, forType: .string)
    }
}
