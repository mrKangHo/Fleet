import Foundation

/// 선택 가능한 음성 합성 보이스 옵션
public struct SpeechVoiceOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let isEnhanced: Bool

    public init(id: String, name: String, isEnhanced: Bool) {
        self.id = id
        self.name = name
        self.isEnhanced = isEnhanced
    }
}
