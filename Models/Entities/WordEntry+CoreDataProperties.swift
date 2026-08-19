import Foundation
import CoreData

extension WordEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<WordEntry> {
        return NSFetchRequest<WordEntry>(entityName: "WordEntry")
    }

    /// 词条唯一标识
    @NSManaged public var wordId: String
    /// 所属 Section 序号（从 0 开始）
    @NSManaged public var sectionIndex: Int32
    /// 导入时的文件行序（用于顺序播放）
    @NSManaged public var orderIndex: Int32
    /// 词条在原始 TXT 文件中的真实行号（从 1 起计，含被跳过的空行）；
    /// v0.1 老数据为 0，UI 显示为 "-"
    @NSManaged public var sourceLineNumber: Int32
    /// 源语言词条（核心背记单词）
    @NSManaged public var sourceWord: String
    /// 源语言注音 / 音标
    @NSManaged public var phonetic: String?
    /// 词性 1
    @NSManaged public var pos1: String?
    /// 释义 1
    @NSManaged public var meaning1: String?
    /// 词性 2
    @NSManaged public var pos2: String?
    /// 释义 2
    @NSManaged public var meaning2: String?
    /// 词性 3
    @NSManaged public var pos3: String?
    /// 释义 3
    @NSManaged public var meaning3: String?
    /// 所属单词本
    @NSManaged public var wordbook: Wordbook?
}
