import XCTest
@testable import HoverWord

/// ContentVisibility 枚举验证：Codable 往返、CaseIterable 完整性
final class ContentVisibilityTests: XCTestCase {

    func testCodableRoundTrip() {
        for mode in ContentVisibility.allCases {
            let data = try? JSONEncoder().encode(mode)
            XCTAssertNotNil(data, "\(mode) 应可编码")
            let decoded = try? JSONDecoder().decode(ContentVisibility.self, from: data!)
            XCTAssertEqual(decoded, mode, "\(mode) 解码后应与原值一致")
        }
    }

    func testRawValues() {
        // 原始值即持久化格式，变更会破坏旧数据兼容
        XCTAssertEqual(ContentVisibility.always.rawValue, "always")
        XCTAssertEqual(ContentVisibility.hover.rawValue, "hover")
        XCTAssertEqual(ContentVisibility.hidden.rawValue, "hidden")
    }

    func testCaseIterableCoversAllModes() {
        XCTAssertEqual(ContentVisibility.allCases.count, 3,
                       "显示模式应有且仅有 always/hover/hidden 三态")
        XCTAssertEqual(Set(ContentVisibility.allCases),
                       [.always, .hover, .hidden])
    }

    func testDecodeFromPersistedString() {
        // 模拟从 UserDefaults 读出的 JSON 字符串解码
        let json = "\"hover\"".data(using: .utf8)!
        let mode = try? JSONDecoder().decode(ContentVisibility.self, from: json)
        XCTAssertEqual(mode, .hover)
    }
}
