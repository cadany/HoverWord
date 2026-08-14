import Foundation
import CoreData

/// 词条实体
///
/// 存储单个词条的完整信息：源语言词条、注音、最多 3 组词性与释义。
/// 字段不绑定具体语种，通过所属单词本的 sourceLang / targetLang 标识语种。
@objc(WordEntry)
public class WordEntry: NSManagedObject {
}
