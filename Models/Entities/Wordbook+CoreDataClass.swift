import Foundation
import CoreData

/// 单词本实体
///
/// 存储单词本名称、源/目标语言、启用状态、是否系统内置、创建时间。
/// 与 WordEntry 为一对多级联删除关系。
@objc(Wordbook)
public class Wordbook: NSManagedObject {
}
