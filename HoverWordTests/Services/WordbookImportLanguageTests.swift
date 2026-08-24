import XCTest
import CoreData
@testable import HoverWord

/// 导入后语言对自动识别集成验证
final class WordbookImportLanguageTests: XCTestCase {

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
        for entityName in ["WordEntry", "Wordbook", "Favorite"] {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            if let objects = try? context.fetch(request) {
                for object in objects { context.delete(object) }
            }
        }
        DataStack.shared.saveContext()
    }

    /// 写临时 TXT 并导入指定词本
    private func importTXT(_ content: String, into wordbook: Wordbook) async throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lang-test-\(UUID().uuidString).txt")
        try content.data(using: .utf8)?.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        try await WordbookService.shared.importFromFile(fileURL: url, to: wordbook)
    }

    /// 导入法语→英语词库：语言对自动设置为 fr→en
    func testImportFrenchSetsLanguagePair() async throws {
        let book = WordbookService.shared.createWordbook(name: "法语本")
        let content = (0..<20).map { i in
            ["bonjour\t/bɔ̃.ʒuʁ/\tint.\thello", "maison\t/mɛ.zɔ̃/\tn.\thouse",
             "amour\t/a.muʁ/\tn.\tlove", "chien\t/ʃjɛ̃/\tn.\tdog"][i % 4]
        }.joined(separator: "\n")
        try await importTXT(content, into: book)

        // 后台上下文写入后，主上下文经 automaticallyMergesChangesFromParent 同步；
        // 轮询等待合并传播（上限 2s）
        let fetched = try await pollLanguagePair(bookId: book.wordbookId)
        XCTAssertEqual(fetched.source, "fr", "导入法语内容后 sourceLang 应自动识别为 fr")
        XCTAssertEqual(fetched.target, "en", "英语释义应识别 targetLang 为 en")
    }

    /// 重新导入英语基础词内容：语言对重算（内容即真相），源语言兜底 en
    func testReimportRecomputesLanguagePair() async throws {
        let book = WordbookService.shared.createWordbook(name: "重算本")
        let french = (0..<10).map { _ in "merci\t/mɛʁ.si/\tint.\tthank you" }.joined(separator: "\n")
        try await importTXT(french, into: book)

        let english = (0..<10).map { i in
            ["opportunity\t/ˌɒpəˈtjuːnəti/\tn.\t机会", "development\t/dɪˈveləpmənt/\tn.\t发展",
             "experience\t/ɪkˈspɪəriəns/\tn.\t经验"][i % 3]
        }.joined(separator: "\n")
        try await importTXT(english, into: book)

        let fetched = try await pollLanguagePair(bookId: book.wordbookId)
        XCTAssertEqual(fetched.source, "en", "重新导入英语内容后语言对应重算")
    }

    /// 手动设置语言对（行内"语言…"路径）
    func testManualLanguageUpdate() async throws {
        let book = WordbookService.shared.createWordbook(name: "手动本")
        await WordbookService.shared.updateWordbookLanguages(
            wordbookId: book.wordbookId, sourceLang: "es", targetLang: "ja"
        )
        let fetched = try await pollLanguagePair(bookId: book.wordbookId)
        XCTAssertEqual(fetched.source, "es")
        XCTAssertEqual(fetched.target, "ja")
    }

    // MARK: - 辅助

    private func pollLanguagePair(bookId: String) async throws -> (source: String, target: String) {
        for _ in 0..<20 {
            let context = DataStack.shared.viewContext
            let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
            request.predicate = NSPredicate(format: "wordbookId == %@", bookId)
            request.fetchLimit = 1
            if let book = (try? context.fetch(request))?.first,
               book.sourceLang != "en" || book.targetLang != "zh-Hans" {
                return (book.sourceLang, book.targetLang)
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        // 超时：返回最终值让断言失败并展示实际内容
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
        request.predicate = NSPredicate(format: "wordbookId == %@", bookId)
        request.fetchLimit = 1
        let book = (try? context.fetch(request))?.first
        return (book?.sourceLang ?? "nil", book?.targetLang ?? "nil")
    }
}
