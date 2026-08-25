import Foundation

/// 过渡内容模型
///
/// 封装单词切换时的内容数据，作为动效的输入。
/// 包含单词、音标、释义等信息，供动效实现使用。
struct TransitionContent: Sendable {
    /// 单词文本
    let word: String
    /// 音标文本（可选）
    let phonetic: String?
    /// 释义文本（已格式化，如 "n. 苹果 / v. 应用"）
    let meaning: String

    /// 初始化过渡内容
    /// - Parameters:
    ///   - word: 单词文本
    ///   - phonetic: 音标文本
    ///   - meaning: 释义文本
    init(word: String, phonetic: String?, meaning: String) {
        self.word = word
        self.phonetic = phonetic
        self.meaning = meaning
    }

    /// 从 WordEntry 创建过渡内容
    /// - Parameter entry: 单词条目
    /// - Returns: 过渡内容实例
    static func from(wordEntry entry: WordEntry) -> TransitionContent {
        // 格式化释义：将所有非空释义用 " / " 拼接
        let pairs: [(String?, String?)] = [
            (entry.pos1, entry.meaning1),
            (entry.pos2, entry.meaning2),
            (entry.pos3, entry.meaning3)
        ]
        let formatted: [String] = pairs.compactMap { pos, meaning in
            guard let meaning = meaning, !meaning.isEmpty else { return nil }
            if let pos = pos, !pos.isEmpty {
                return "\(pos) \(meaning)"
            }
            return meaning
        }
        let meaningText = formatted.joined(separator: " / ")

        return TransitionContent(
            word: entry.sourceWord,
            phonetic: entry.phonetic,
            meaning: meaningText
        )
    }
}

// MARK: - Equatable

extension TransitionContent: Equatable {
    static func == (lhs: TransitionContent, rhs: TransitionContent) -> Bool {
        return lhs.word == rhs.word
            && lhs.phonetic == rhs.phonetic
            && lhs.meaning == rhs.meaning
    }
}
