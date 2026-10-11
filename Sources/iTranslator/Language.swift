import Foundation

struct Language: Hashable, Identifiable {
    let id: String
    let name: String
    let locale: Locale.Language
    let llmName: String

    static let english = Language(id: "en", name: "English", locale: .init(identifier: "en"), llmName: "English")
    static let chinese = Language(id: "zh-CN", name: "中文 (简体)", locale: .init(identifier: "zh-Hans"), llmName: "Simplified Chinese")

    static let all: [Language] = [english, chinese]
}
