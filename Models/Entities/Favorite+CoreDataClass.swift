import Foundation
import CoreData

/// 收藏实体
///
/// 按源语言词条精确匹配，存储词条完整信息 JSON 与收藏时间。
/// 同一词条在全应用范围内仅保留一条收藏记录。
@objc(Favorite)
public class Favorite: NSManagedObject {
}
