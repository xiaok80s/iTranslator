import Foundation

struct TranslationError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum GoogleTranslator {
    static func translate(_ text: String, from: Language, to: Language) async throws -> String {
        // POST form body: strict escaping (&, +, # etc.) and no URL length limit for long text.
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s }
        let form = [("client", "gtx"), ("sl", from.id), ("tl", to.id), ("dt", "t"), ("q", text)]
            .map { "\($0.0)=\(enc($0.1))" }.joined(separator: "&")
        var req = URLRequest(url: URL(string: "https://translate.googleapis.com/translate_a/single")!)
        req.httpMethod = "POST"
        req.httpBody = Data(form.utf8)
        req.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 8
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 else { throw TranslationError(message: "HTTP \(status)") }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [Any],
              let segments = root.first as? [[Any]]
        else { throw TranslationError(message: "unexpected response") }
        let result = segments.compactMap { $0.first as? String }.joined()
        guard !result.isEmpty else { throw TranslationError(message: "empty result") }
        return result
    }
}

enum Provider: String, CaseIterable, Identifiable {
    case google, apple, llm
    var id: String { rawValue }
    var title: String {
        switch self {
        case .google: return "Google"
        case .apple: return "Apple"
        case .llm: return "LLM"
        }
    }
    var isSupported: Bool {
        switch self {
        case .apple:
            if #available(macOS 15, *) { return true } else { return false }
        default: return true
        }
    }
}

enum ProviderSettings {
    private static let orderKey = "providerOrder"
    private static let disabledKey = "providerDisabled"

    // Saved order, with any missing providers appended so new ones always appear.
    static var order: [Provider] {
        get {
            let saved = (UserDefaults.standard.stringArray(forKey: orderKey) ?? []).compactMap(Provider.init(rawValue:))
            var result: [Provider] = []
            for p in saved + Provider.allCases where !result.contains(p) { result.append(p) }
            return result
        }
        set { UserDefaults.standard.set(newValue.map(\.rawValue), forKey: orderKey) }
    }
    static var disabled: Set<Provider> {
        get { Set((UserDefaults.standard.stringArray(forKey: disabledKey) ?? []).compactMap(Provider.init(rawValue:))) }
        set { UserDefaults.standard.set(newValue.map(\.rawValue), forKey: disabledKey) }
    }
    static var active: [Provider] { order.filter { $0.isSupported && !disabled.contains($0) } }
}

enum LLMSettings {
    private static let env = ProcessInfo.processInfo.environment
    static var baseURL: String {
        get { UserDefaults.standard.string(forKey: "llmBaseURL") ?? env["OPENAI_BASE_URL"] ?? "https://api.openai.com/v1" }
        set { UserDefaults.standard.set(newValue, forKey: "llmBaseURL") }
    }
    static var apiKey: String {
        get { UserDefaults.standard.string(forKey: "llmAPIKey") ?? env["OPENAI_API_KEY"] ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "llmAPIKey") }
    }
    static var model: String {
        get { UserDefaults.standard.string(forKey: "llmModel") ?? env["OPENAI_MODEL"] ?? "gpt-4o-mini" }
        set { UserDefaults.standard.set(newValue, forKey: "llmModel") }
    }
}

enum LLMTranslator {
    static func translate(_ text: String, from: Language, to: Language) async throws -> String {
        guard !LLMSettings.apiKey.isEmpty else { throw TranslationError(message: "API key not configured") }
        let base = LLMSettings.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + "/chat/completions") else { throw TranslationError(message: "invalid base URL") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("Bearer \(LLMSettings.apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": LLMSettings.model,
            "temperature": 0,
            "messages": [
                ["role": "system", "content": "You are a translator. Translate the user's text from \(from.llmName) to \(to.llmName). Output only the translation."],
                ["role": "user", "content": text],
            ],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let content = (choices.first?["message"] as? [String: Any])?["content"] as? String
        else { throw TranslationError(message: "request failed") }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
