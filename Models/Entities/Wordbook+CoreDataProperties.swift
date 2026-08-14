import Foundation
import CoreData

extension Wordbook {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Wordbook> {
        return NSFetchRequest<Wordbook>(entityName: "Wordbook")
    }

    /// 单词本唯一标识
    @NSManaged public var wordbookId: String
    /// 单词本名称
    @NSManaged public var name: String
    /// 源语言代码（v0.1 固定为 "en"）
    @NSManaged public var sourceLang: String
    /// 目标语言代码（v0.1 固定为 "zh-Hans"）
    @NSManaged public var targetLang: String
    /// 是否启用参与背记
    @NSManaged public var isEnabled: Bool
    /// 是否为系统内置单词本（如收藏夹）
    @NSManaged public var isSystem: Bool
    /// 创建时间
    @NSManaged public var createdAt: Date?
    /// 所属词条集合（级联删除）
    @NSManaged public var entries: NSOrderedSet?
}

// MARK: - 有序集合访问器

extension Wordbook {

    @objc(addEntriesObject:)
    @NSManaged public func addToEntries(_ value: WordEntry)

    @objc(removeEntriesObject:)
    @NSManaged public func removeFromEntries(_ value: WordEntry)

    @objc(addEntries:)
    @NSManaged public func addToEntries(_ values: NSSet)

    @objc(removeEntries:)
    @NSManaged public func removeFromEntries(_ values: NSSet)
}
