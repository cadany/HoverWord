import Foundation
import CoreData

extension Favorite {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Favorite> {
        return NSFetchRequest<Favorite>(entityName: "Favorite")
    }

    /// 收藏记录唯一标识
    @NSManaged public var favoriteId: String
    /// 源语言词条（匹配依据，精确匹配）
    @NSManaged public var sourceWord: String
    /// 词条完整信息（JSON 编码的二进制数据）
    @NSManaged public var wordDetail: Data?
    /// 收藏时间
    @NSManaged public var collectedAt: Date?
}
