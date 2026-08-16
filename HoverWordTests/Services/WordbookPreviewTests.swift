import XCTest
import CoreData
@testable import HoverWord

/// 单词本预览分页 fetch 验证
///
/// 验证 getEntriesPaginated / updateEntry / deleteEntry 的正确性。
final class WordbookPreviewTests: XCTestCase {

    override func setUp() {
        super.setUp()
        DataStack.shared.initialize()
        clearAllData()
    }

    override func tearDown() {
        clearAllData()
        super.tearDown()
    }

    private func clearAllData() {
        let context = DataStack.shared.viewContext
        for entityName in ["WordEntry", "Wordbook", "Favorite"] {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            if let objects = try? context.fetch(request) {
                for object in objects { context.delete(object) }
            }
        }
        DataStack.shared.saveContext()
    }

    /// 创建含 N 个词条的单词本
    private func createWordbookWithEntries(count: Int) -> Wordbook {
        let context = DataStack.shared.viewContext
        let wordbook = Wordbook(context: context)
        wordbook.wordbookId = "preview-test-wb"
        wordbook.name = "预览测试"
        wordbook.sourceLang = "en"
        wordbook.targetLang = "zh-Hans"
        wordbook.isEnabled = true
        wordbook.isSystem = false
        wordbook.createdAt = Date()

        for i in 0..<count {
            let entry = WordEntry(context: context)
            entry.wordId = "pwe-\(i)"
            entry.sourceWord = "word\(i)"
            entry.phonetic = "/w\(i)/"
            entry.pos1 = "n."
            entry.meaning1 = "释义\(i)"
            entry.sectionIndex = Int32(i / 10)
            entry.orderIndex = Int32(i)
            entry.wordbook = wordbook
        }

        DataStack.shared.saveContext()
        return wordbook
    }

    // MARK: - 分页 fetch

    func testPaginatedFetchFirstPage() {
        let wordbook = createWordbookWithEntries(count: 250)

        let result = WordbookService.shared.getEntriesPaginated(
            for: wordbook, page: 0, pageSize: 100
        )

        XCTAssertEqual(result.entries.count, 100, "第一页应返回 100 条")
        XCTAssertEqual(result.totalPages, 3, "250 条 / 100 每页 = 3 页")
        XCTAssertEqual(result.entries.first?.sourceWord, "word0")
    }

    func testPaginatedFetchLastPage() {
        let wordbook = createWordbookWithEntries(count: 250)

        let result = WordbookService.shared.getEntriesPaginated(
            for: wordbook, page: 2, pageSize: 100
        )

        XCTAssertEqual(result.entries.count, 50, "最后一页应返回 50 条")
        XCTAssertEqual(result.totalPages, 3)
    }

    func testPaginatedFetchEmpty() {
        let context = DataStack.shared.viewContext
        let wordbook = Wordbook(context: context)
        wordbook.wordbookId = "empty-wb"
        wordbook.name = "空单词本"
        wordbook.sourceLang = "en"
        wordbook.targetLang = "zh-Hans"
        wordbook.isEnabled = false
        wordbook.isSystem = false
        wordbook.createdAt = Date()
        DataStack.shared.saveContext()

        let result = WordbookService.shared.getEntriesPaginated(
            for: wordbook, page: 0, pageSize: 100
        )

        XCTAssertEqual(result.entries.count, 0)
        XCTAssertEqual(result.totalPages, 1, "空单词本应返回 1 页（最小值）")
    }

    func testPaginatedFetchExactMultiple() {
        let wordbook = createWordbookWithEntries(count: 200)

        let result = WordbookService.shared.getEntriesPaginated(
            for: wordbook, page: 0, pageSize: 100
        )

        XCTAssertEqual(result.totalPages, 2, "200 条 / 100 每页 = 恰好 2 页")
    }

    // MARK: - 词条更新

    func testUpdateEntry() {
        let wordbook = createWordbookWithEntries(count: 5)

        WordbookService.shared.updateEntry(
            wordId: "pwe-0",
            sourceWord: "updated_word",
            phonetic: "/ʌpdɛɪtɪd/",
            pos1: "v.",
            meaning1: "更新"
        )

        // 重新获取验证
        let result = WordbookService.shared.getEntriesPaginated(
            for: wordbook, page: 0, pageSize: 100
        )
        let updated = result.entries.first { $0.wordId == "pwe-0" }
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.sourceWord, "updated_word")
        XCTAssertEqual(updated?.phonetic, "/ʌpdɛɪtɪd/")
        XCTAssertEqual(updated?.pos1, "v.")
        XCTAssertEqual(updated?.meaning1, "更新")
    }

    // MARK: - 词条删除

    func testDeleteEntry() {
        let wordbook = createWordbookWithEntries(count: 5)

        let beforeCount = WordbookService.shared.getEntryCount(for: wordbook)
        XCTAssertEqual(beforeCount, 5)

        WordbookService.shared.deleteEntry(wordId: "pwe-2")

        let afterCount = WordbookService.shared.getEntryCount(for: wordbook)
        XCTAssertEqual(afterCount, 4)

        // 验证删除的是正确的词条
        let result = WordbookService.shared.getEntriesPaginated(
            for: wordbook, page: 0, pageSize: 100
        )
        let deleted = result.entries.first { $0.wordId == "pwe-2" }
        XCTAssertNil(deleted, "已删除的词条不应出现在列表中")
    }
}
