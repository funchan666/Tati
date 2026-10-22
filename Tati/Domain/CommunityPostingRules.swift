import Foundation

/// A narrow preflight for obvious abuse, not a substitute for service-side review.
/// Reports intentionally bypass this filter so evidence can be described accurately.
enum CommunityPostingRules {
    static func permits(_ submittedText: String) -> Bool {
        let readable = submittedText
            .replacingOccurrences(of: "[\\u200B-\\u200D\\uFEFF]", with: "", options: .regularExpression)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let prohibitedPatterns = [
            #"\b(pornography|pornographic|nudes|sexting|prostitution)\b"#,
            #"\b(buy|sell|send|share)\s+(nude|naked|sexual)\s+(photos?|pictures?|videos?)\b"#,
            #"\b(kill yourself|rape you|child pornography)\b"#,
            #"(色情交易|裸聊|出售裸照|儿童色情|约炮)"#,
            #"\b(pornografia|pornographique|pornografisch|prostitucion|prostitution)\b"#,
            #"(児童ポルノ|性的搾取)"#
        ]
        return !prohibitedPatterns.contains { readable.range(of: $0, options: .regularExpression) != nil }
    }
}

@MainActor extension MemberKitchenStore {
    func permitsCommunityText(_ text: String) -> Bool {
        guard CommunityPostingRules.permits(text) else {
            tell("Keep it food-focused", "This text cannot be added. Keep the conversation about food, and avoid sexual content, threats or harassment.")
            return false
        }
        return true
    }
}
