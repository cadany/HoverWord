import XCTest
import CoreData
@testable import HoverWord

/// 收藏夹单词本背记链路验证
///
/// 验证收藏夹单词本的计数、Section 计算、词条转换，以及启用条件。
final class WordbookServiceFavoritesTests: XCTestCase {

    // MARK: - 生命周期

    override func setUp() {
        super.setUp()
        DataStack.shared.initialize()
        clearAllData()
        // 清空后再创建系统收藏夹
        WordbookService.shared.ensureSystemFavorites()
        // 重置 AppSettings 到默认值，防止其他测试泄漏的状态影响
        AppSettings.shared.sectionSize = Constants.defaultSectionSize
    }

    override func tearDown() {
        clearAllData()
        super.tearDown()
    }

    private func clearAllData() {
        let context = DataStack.shared.viewContext
        let entities = ["WordEntry", "Wordbook", "Favorite"]
        for entityName in entities {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            if let objects = try? context.fetch(fetchRequest) {
                for object in objects {
                    context.delete(object)
                }
            }
        }
        DataStack.shared.saveContext()
    }

    // MARK: - 辅助

    /// 收藏一个单词
    private func addFavorite(sourceWord: String, phonetic: String? = nil, meaning: String? = nil) {
        var json: [String: Any] = ["sourceWord": sourceWord]
        if let phonetic = phonetic { json["phonetic"] = phonetic }
        if let meaning = meaning { json["meaning1"] = meaning }
        let data = try? JSONSerialization.data(withJSONObject: json)

        _ = WordbookService.shared.toggleFavorite(sourceWord: sourceWord, wordDetail: data)
    }

    // MARK: - 收藏夹计数

    /// 收藏 3 个单词后，getEntryCount 和 getFavoriteCount 均返回 3
    func testFavoritesWordbookRecitation() throws {
        // 收藏 3 个单词
        addFavorite(sourceWord: "apple", phonetic: "/ˈæpl/", meaning: "苹果")
        addFavorite(sourceWord: "banana", phonetic: "/bəˈnænə/", meaning: "香蕉")
        addFavorite(sourceWord: "cherry", meaning: "樱桃")

        // 获取收藏夹单词本
        guard let favoritesWordbook = WordbookService.shared.getFavoritesWordbook() else {
            XCTFail("系统收藏夹单词本不存在")
            return
        }

        // 验证计数
        XCTAssertEqual(WordbookService.shared.getFavoriteCount(), 3, "应有 3 条收藏")
        XCTAssertEqual(
            WordbookService.shared.getEntryCount(for: favoritesWordbook), 3,
            "收藏夹 getEntryCount 应返回收藏总数"
        )

        // 验证 Section 数量（默认 sectionSize=20，3 条 → 1 个 Section）
        XCTAssertEqual(
            WordbookService.shared.getSectionCount(for: favoritesWordbook), 1,
            "3 条收藏应产生 1 个 Section"
        )

        // 验证 getEntries 返回可消费的 WordEntry 数组
        let entries = WordbookService.shared.getEntries(for: favoritesWordbook, sectionIndex: 0)
        XCTAssertEqual(entries.count, 3, "Section 0 应包含全部 3 个词条")

        // 验证转换后的 WordEntry 字段正确
        let sourceWords = Set(entries.map { $0.sourceWord })
        XCTAssertEqual(sourceWords, Set(["apple", "banana", "cherry"]))

        // 验证每个 entry 有独立的 wordId 和正确的 sectionIndex
        for entry in entries {
            XCTAssertFalse(entry.wordId.isEmpty, "转换后的 wordId 不应为空")
            XCTAssertEqual(entry.sectionIndex, 0, "sectionIndex 应为 0")
            // 验证不挂载到任何 wordbook（游离状态）
            XCTAssertNil(entry.wordbook, "转换后的 WordEntry 不应挂载到 wordbook 关系")
        }

        // 验证字段解码
        let appleEntry = entries.first { $0.sourceWord == "apple" }
        XCTAssertNotNil(appleEntry)
        XCTAssertEqual(appleEntry?.phonetic, "/ˈæpl/")
        XCTAssertEqual(appleEntry?.meaning1, "苹果")
    }

    /// 收藏 0 个单词时，启用收藏夹单词本应返回 false
    func testFavoritesWordbookEnableWithEmpty() {
        // 确保收藏夹为空
        XCTAssertEqual(WordbookService.shared.getFavoriteCount(), 0)

        guard let favoritesWordbook = WordbookService.shared.getFavoritesWordbook() else {
            XCTFail("系统收藏夹单词本不存在")
            return
        }

        // 空收藏夹不应能启用
        let result = WordbookService.shared.setWordbookEnabled(favoritesWordbook, enabled: true)
        XCTAssertFalse(result, "空收藏夹单词本不应能启用")
        XCTAssertFalse(favoritesWordbook.isEnabled, "启用失败后 isEnabled 应为 false")
    }

    /// 收藏 3 个单词后，收藏夹单词本应能成功启用
    func testFavoritesWordbookEnableWithFavorites() {
        addFavorite(sourceWord: "apple", meaning: "苹果")
        addFavorite(sourceWord: "banana", meaning: "香蕉")
        addFavorite(sourceWord: "cherry", meaning: "樱桃")

        guard let favoritesWordbook = WordbookService.shared.getFavoritesWordbook() else {
            XCTFail("系统收藏夹单词本不存在")
            return
        }

        let result = WordbookService.shared.setWordbookEnabled(favoritesWordbook, enabled: true)
        XCTAssertTrue(result, "有收藏时应能成功启用收藏夹单词本")
        XCTAssertTrue(favoritesWordbook.isEnabled, "启用后 isEnabled 应为 true")
    }

    /// 收藏超过 sectionSize 时，Section 数量应正确计算
    func testFavoritesMultipleSections() {
        // 临时设置 sectionSize 为 2 以便测试多 Section
        let originalSize = AppSettings.shared.sectionSize
        AppSettings.shared.sectionSize = 2

        // 收藏 5 个单词 → 应产生 3 个 Section（2+2+1）
        for i in 0..<5 {
            addFavorite(sourceWord: "word\(i)", meaning: "释义\(i)")
        }

        guard let favoritesWordbook = WordbookService.shared.getFavoritesWordbook() else {
            XCTFail("系统收藏夹单词本不存在")
            return
        }

        XCTAssertEqual(
            WordbookService.shared.getSectionCount(for: favoritesWordbook), 3,
            "5 条收藏 + sectionSize=2 应产生 3 个 Section"
        )

        // 验证各 Section 的词条数量
        let section0 = WordbookService.shared.getEntries(for: favoritesWordbook, sectionIndex: 0)
        let section1 = WordbookService.shared.getEntries(for: favoritesWordbook, sectionIndex: 1)
        let section2 = WordbookService.shared.getEntries(for: favoritesWordbook, sectionIndex: 2)
        XCTAssertEqual(section0.count, 2, "Section 0 应有 2 条")
        XCTAssertEqual(section1.count, 2, "Section 1 应有 2 条")
        XCTAssertEqual(section2.count, 1, "Section 2 应有 1 条")

        // 恢复设置
        AppSettings.shared.sectionSize = originalSize
    }
}
