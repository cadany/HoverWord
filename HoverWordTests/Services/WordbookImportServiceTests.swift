import XCTest
@testable import HoverWord

/// 词库导入功能验证
///
/// 对应任务 3.8：正常文件、空文件、格式错误（精准行号）、编码错误、10000 条大文件。
final class WordbookImportServiceTests: XCTestCase {

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

    func testParseEmptyFile() throws {
        let data = "".data(using: .utf8)!

        let entries = try WordbookImportService.parse(data: data)

        XCTAssertTrue(entries.isEmpty, "空文件应返回空数组")
    }

    func testParseOnlyBlankLines() throws {
        let data = "\n\n\n".data(using: .utf8)!

        let entries = try WordbookImportService.parse(data: data)

        XCTAssertTrue(entries.isEmpty, "仅空行的文件应返回空数组")
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
}
