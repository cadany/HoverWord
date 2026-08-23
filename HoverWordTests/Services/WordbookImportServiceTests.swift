import XCTest
import CoreData
@testable import HoverWord

/// 词库导入功能验证
///
/// 对应任务 3.8：正常文件、空文件、格式错误（精准行号）、编码错误、10000 条大文件。
final class WordbookImportServiceTests: XCTestCase {

    // MARK: - 生命周期（Core Data 写入测试需要）

    override func setUp() {
        super.setUp()
        DataStack.shared.initialize()
        clearAllData()
        // 错误文案断言依赖中文本地化：固定语言，
        // 隔离测试宿主进程从 UserDefaults 载入的用户界面语言设置
        AppSettings.shared.uiLanguage = "zh-Hans"
    }

    override func tearDown() {
        clearAllData()
        AppSettings.shared.uiLanguage = L10n.systemLanguage
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

    // MARK: - 正常解析

    func testParseValidFile() throws {
        // 标准 3 字段行：apple / ˈæpl / n. 苹果
        let content = "apple\t/ˈæpl/\tn.\t苹果"
        let data = content.data(using: .utf8)!

        let entries = try WordbookImportService.parse(data: data)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].sourceWord, "apple")
        XCTAssertEqual(entries[0].phonetic, "/ˈæpl/")
        XCTAssertEqual(entries[0].pos1, "n.")
        XCTAssertEqual(entries[0].meaning1, "苹果")
    }

    func testParseMultipleLines() throws {
        let content = "apple\t/ˈæpl/\tn.\t苹果\nbanana\t/bəˈnænə/\tn.\t香蕉\ncherry\t\t\t樱桃"
        let data = content.data(using: .utf8)!

        let entries = try WordbookImportService.parse(data: data)

        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].sourceWord, "apple")
        XCTAssertEqual(entries[1].sourceWord, "banana")
        XCTAssertEqual(entries[2].sourceWord, "cherry")
        XCTAssertEqual(entries[2].meaning1, "樱桃")
        XCTAssertNil(entries[2].phonetic, "空字段应为 nil")
    }

    func testParseFullFields() throws {
        // 全部 8 个字段
        let content = "run\t\trvi.\t跑\tvt.\t经营\tn.\t跑步"
        let data = content.data(using: .utf8)!

        let entries = try WordbookImportService.parse(data: data)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].pos1, "rvi.")
        XCTAssertEqual(entries[0].meaning1, "跑")
        XCTAssertEqual(entries[0].pos2, "vt.")
        XCTAssertEqual(entries[0].meaning2, "经营")
        XCTAssertEqual(entries[0].pos3, "n.")
        XCTAssertEqual(entries[0].meaning3, "跑步")
    }

    func testParseEmptyLinesSkipped() throws {
        let content = "apple\t\tn.\t苹果\n\n\nbanana\t\tn.\t香蕉\n"
        let data = content.data(using: .utf8)!

        let entries = try WordbookImportService.parse(data: data)

        XCTAssertEqual(entries.count, 2, "空行应被跳过")
    }

    // MARK: - 空文件

    func testParseEmptyFile() {
        let data = "".data(using: .utf8)!

        XCTAssertThrowsError(try WordbookImportService.parse(data: data)) { error in
            guard case WordbookImportService.ImportError.emptyFile = error else {
                XCTFail("空文件应抛出 emptyFile，实际: \(error)")
                return
            }
        }
    }

    func testParseOnlyBlankLines() {
        let data = "\n\n\n".data(using: .utf8)!

        XCTAssertThrowsError(try WordbookImportService.parse(data: data)) { error in
            guard case WordbookImportService.ImportError.emptyFile = error else {
                XCTFail("仅空行的文件应抛出 emptyFile，实际: \(error)")
                return
            }
        }
    }

    // MARK: - 格式错误（精准行号）

    func testParseMissingWord() {
        // 第 2 行缺少源语言词条
        let content = "apple\t\tn.\t苹果\n\t\tn.\t香蕉"
        let data = content.data(using: .utf8)!

        XCTAssertThrowsError(try WordbookImportService.parse(data: data)) { error in
            guard case WordbookImportService.ImportError.formatError(let line, let reason) = error else {
                XCTFail("应为 formatError 类型")
                return
            }
            XCTAssertEqual(line, 2, "错误行号应为 2")
            XCTAssertTrue(reason.contains("词条"), "错误原因应提及词条")
        }
    }

    func testParseMissingMeaning() {
        // 第 3 行缺少释义 1
        let content = "apple\t\tn.\t苹果\nbanana\t\tn.\t香蕉\ncherry\t\tn."
        let data = content.data(using: .utf8)!

        XCTAssertThrowsError(try WordbookImportService.parse(data: data)) { error in
            guard case WordbookImportService.ImportError.formatError(let line, _) = error else {
                XCTFail("应为 formatError 类型")
                return
            }
            XCTAssertEqual(line, 3, "错误行号应为 3")
        }
    }

    func testParseInsufficientFields() {
        // 第 1 行只有 2 个字段
        let content = "apple\t/ˈæpl/"
        let data = content.data(using: .utf8)!

        XCTAssertThrowsError(try WordbookImportService.parse(data: data)) { error in
            guard case WordbookImportService.ImportError.formatError(let line, _) = error else {
                XCTFail("应为 formatError 类型")
                return
            }
            XCTAssertEqual(line, 1, "错误行号应为 1")
        }
    }

    // MARK: - 编码错误

    func testParseInvalidEncoding() {
        // 非 UTF-8 数据
        let data = Data([0xFF, 0xFE, 0xFD, 0xFC])

        XCTAssertThrowsError(try WordbookImportService.parse(data: data)) { error in
            guard case WordbookImportService.ImportError.invalidEncoding = error else {
                XCTFail("应为 invalidEncoding 类型")
                return
            }
        }
    }

    // MARK: - 大文件性能

    func testImportPerformance10000Entries() throws {
        // 生成 10000 行数据
        var lines: [String] = []
        for i in 0..<Constants.importBenchmarkCount {
            lines.append("word\(i)\t/phonetic\(i)/\tn.\t释义\(i)")
        }
        let content = lines.joined(separator: "\n")
        let data = content.data(using: .utf8)!

        // 解析性能测试
        measure {
            do {
                let entries = try WordbookImportService.parse(data: data)
                XCTAssertEqual(entries.count, Constants.importBenchmarkCount)
            } catch {
                XCTFail("解析失败: \(error)")
            }
        }
    }

    // MARK: - orderIndex 写入验证

    /// 导入后词条 orderIndex 值与文件行序一致
    func testImportWritesOrderIndex() async throws {
        // 准备内容：5 个单词，文件顺序为 zebra, apple, mango, banana, cherry
        let content = """
        zebra\t\t\tn.\t斑马
        apple\t\t\tn.\t苹果
        mango\t\t\tn.\t芒果
        banana\t\t\tn.\t香蕉
        cherry\t\t\tn.\t樱桃
        """
        let data = content.data(using: .utf8)!
        let parsed = try WordbookImportService.parse(data: data)

        // 创建测试单词本
        let wordbook = WordbookService.shared.createWordbook(name: "测试排序")

        // 执行导入
        try await WordbookImportService.importEntries(parsed, to: wordbook, sectionSize: 20)

        // 直接查询数据库，按 orderIndex 排序
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<WordEntry> = WordEntry.fetchRequest()
        request.predicate = NSPredicate(format: "wordbook.wordbookId == %@", wordbook.wordbookId)
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]

        let entries = try context.fetch(request)
        XCTAssertEqual(entries.count, 5)

        // 验证 orderIndex 与文件行序一致
        let expectedOrder: [String] = ["zebra", "apple", "mango", "banana", "cherry"]
        for (i, entry) in entries.enumerated() {
            XCTAssertEqual(entry.orderIndex, Int32(i), "第 \(i) 个词条 orderIndex 应为 \(i)")
            XCTAssertEqual(entry.sourceWord, expectedOrder[i], "第 \(i) 个词条 sourceWord 应为 \(expectedOrder[i])")
        }
    }

    /// getEntries 返回结果按 orderIndex 排序，而非 wordId（UUID）
    func testGetEntriesSortedByOrderIndex() async throws {
        // 准备内容：故意让字母序与文件序不同
        let content = """
        zebra\t\t\tn.\t斑马
        apple\t\t\tn.\t苹果
        mango\t\t\tn.\t芒果
        """
        let data = content.data(using: .utf8)!
        let parsed = try WordbookImportService.parse(data: data)

        let wordbook = WordbookService.shared.createWordbook(name: "排序验证")
        try await WordbookImportService.importEntries(parsed, to: wordbook, sectionSize: 20)

        // 通过 getEntries 获取（应返回 orderIndex 排序结果）
        let entries = WordbookService.shared.getEntries(for: wordbook, sectionIndex: 0)
        XCTAssertEqual(entries.count, 3)

        // 验证顺序为文件行序（zebra, apple, mango），而非字母序（apple, mango, zebra）
        XCTAssertEqual(entries[0].sourceWord, "zebra")
        XCTAssertEqual(entries[1].sourceWord, "apple")
        XCTAssertEqual(entries[2].sourceWord, "mango")
    }
}
