import XCTest
import CoreData
@testable import HoverWord

/// TXT 词库导出服务验证
///
/// 覆盖：普通词本导出字段/顺序、导出→导入 round-trip 无损、
/// 收藏夹快照导出、文件名清洗、词本不存在错误。
final class WordbookExportServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        DataStack.shared.initialize()
        clearAllData()
        WordbookService.shared.ensureSystemFavorites()
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

    /// 通过导入服务灌入词条（保证与真实导入路径同源）
    private func importLines(_ text: String, wordbook: Wordbook, sectionSize: Int = 20) async throws {
        let data = Data(text.utf8)
        let parsed = try WordbookImportService.parse(data: data)
        try await WordbookImportService.importEntries(parsed, to: wordbook, sectionSize: sectionSize)
    }

    // MARK: - 普通词本导出

    /// 导出字段与顺序正确（orderIndex 升序、8 列 Tab 分隔、nil 字段空串）
    func testExportRegularWordbookFieldsAndOrder() async throws {
        let wordbook = WordbookService.shared.createWordbook(name: "Export源")
        try await importLines(
            "apple\t/ˈæpl/\tn.\t苹果\tv.\t供应\nbanana\t\t\tn香蕉\n",
            wordbook: wordbook
        )

        let data = try await WordbookExportService.export(wordbookId: wordbook.wordbookId)
        let content = String(data: data, encoding: .utf8)!
        let lines = content.split(separator: "\n").map(String.init)

        XCTAssertEqual(lines.count, 2, "2 条词条应导出 2 行")
        XCTAssertEqual(lines[0], "apple\t/ˈæpl/\tn.\t苹果\tv.\t供应\t\t", "含 2/3 组释义的行应为 8 列（缺失列空串）")
        XCTAssertEqual(lines[1], "banana\t\t\tn香蕉\t\t\t\t", "仅第 1 组释义的行后 3 列为空串")
        XCTAssertFalse(content.hasPrefix("\u{FEFF}"), "导出不得带 BOM")
    }

    /// 导出 → 导入 round-trip：字段完全还原
    func testRoundTripImport() async throws {
        let source = WordbookService.shared.createWordbook(name: "RoundTrip源")
        try await importLines(
            "apple\t/ˈæpl/\tn.\t苹果\nbanana\t/bəˈnænə/\tn.\t香蕉\tv.\t发疯\tadj.\t疯狂的\n",
            wordbook: source
        )

        let data = try await WordbookExportService.export(wordbookId: source.wordbookId)

        // 重新解析导出内容
        let reparsed = try WordbookImportService.parse(data: data)
        XCTAssertEqual(reparsed.count, 2)

        XCTAssertEqual(reparsed[0].sourceWord, "apple")
        XCTAssertEqual(reparsed[0].phonetic, "/ˈæpl/")
        XCTAssertEqual(reparsed[0].pos1, "n.")
        XCTAssertEqual(reparsed[0].meaning1, "苹果")
        XCTAssertNil(reparsed[0].pos2)

        XCTAssertEqual(reparsed[1].sourceWord, "banana")
        XCTAssertEqual(reparsed[1].meaning1, "香蕉")
        XCTAssertEqual(reparsed[1].pos2, "v.")
        XCTAssertEqual(reparsed[1].meaning2, "发疯")
        XCTAssertEqual(reparsed[1].pos3, "adj.")
        XCTAssertEqual(reparsed[1].meaning3, "疯狂的")
    }

    // MARK: - 收藏夹导出

    /// 收藏导出按 collectedAt 升序从快照还原 8 字段
    func testExportFavorites() async throws {
        for i in 0..<3 {
            let json: [String: Any] = [
                "phonetic": "/f\(i)/",
                "pos1": "n.",
                "meaning1": "释义\(i)"
            ]
            let detail = try JSONSerialization.data(withJSONObject: json)
            XCTAssertTrue(WordbookService.shared.toggleFavorite(sourceWord: "word\(i)", wordDetail: detail))
        }

        guard let favorites = WordbookService.shared.getFavoritesWordbook() else {
            XCTFail("系统收藏夹单词本不存在")
            return
        }

        let data = try await WordbookExportService.export(wordbookId: favorites.wordbookId)
        let reparsed = try WordbookImportService.parse(data: data)

        XCTAssertEqual(reparsed.count, 3, "3 条收藏应全部导出")
        XCTAssertEqual(Set(reparsed.map { $0.sourceWord }), Set(["word0", "word1", "word2"]))
        let sample = reparsed.first { $0.sourceWord == "word1" }
        XCTAssertEqual(sample?.phonetic, "/f1/")
        XCTAssertEqual(sample?.pos1, "n.")
        XCTAssertEqual(sample?.meaning1, "释义1")
    }

    // MARK: - 边界

    /// 词本不存在时抛 wordbookMissing
    func testExportMissingWordbook() async {
        do {
            _ = try await WordbookExportService.export(wordbookId: "nonexistent-id")
            XCTFail("应抛出 wordbookMissing")
        } catch {
            XCTAssertTrue(error is WordbookExportService.ExportError)
        }
    }

    /// 文件名清洗：非法字符替换为 -，空名兜底
    func testSanitizedFileName() {
        XCTAssertEqual(WordbookExportService.sanitizedFileName(from: "CET-4/核心:词库"), "CET-4-核心-词库")
        XCTAssertEqual(WordbookExportService.sanitizedFileName(from: "我的收藏"), "我的收藏")
        XCTAssertEqual(WordbookExportService.sanitizedFileName(from: ""), "wordbook")
    }
}
