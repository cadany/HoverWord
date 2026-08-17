import Foundation
import CoreData

/// 词条实体
///
/// 存储单个词条的完整信息：源语言词条、注音、最多 3 组词性与释义。
/// 字段不绑定具体语种，通过所属单词本的 sourceLang / targetLang 标识语种。
@objc(WordEntry)
public class WordEntry: NSManagedObject {
}

// MARK: - 收藏信息编码

extension WordEntry {

    /// 将词条完整信息编码为 JSON 二进制数据，用于收藏记录的 wordDetail 字段
    func encodeWordDetail() -> Data? {
        var detail: [String: Any?] = [
            "wordId": wordId,
            "sourceWord": sourceWord,
            "phonetic": phonetic,
            "pos1": pos1, "meaning1": meaning1,
            "pos2": pos2, "meaning2": meaning2,
            "pos3": pos3, "meaning3": meaning3
        ]
        // 移除 nil 值，确保 JSON 序列化不会失败
        detail = detail.compactMapValues { $0 }
        return try? JSONSerialization.data(withJSONObject: detail)
    }
}
