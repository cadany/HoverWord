import XCTest
@testable import HoverWord

/// 动效参数字典测试
///
/// 对应任务 1.7：TransitionParameters 的 get/set/clamp 功能验证
final class TransitionParametersTests: XCTestCase {

    func testSetAndGet() {
        var params = TransitionParameters()

        // 设置参数
        params.set("duration", 0.5)
        params.set("intensity", 1.5)

        // 获取参数
        XCTAssertEqual(params.get("duration"), 0.5)
        XCTAssertEqual(params.get("intensity"), 1.5)
    }

    func testGetWithDefaultValue() {
        var params = TransitionParameters()

        // 设置一个参数
        params.set("duration", 0.5)

        // 获取已设置的参数
        XCTAssertEqual(params.get("duration", defaultValue: 1.0), 0.5)

        // 获取未设置的参数，应该返回默认值
        XCTAssertEqual(params.get("nonexistent", defaultValue: 1.0), 1.0)
    }

    func testSetClamped() {
        var params = TransitionParameters()

        // 测试 clamp 到范围内
        let range = 0.2...0.5

        // 在范围内
        let result1 = params.setClamped("duration", 0.3, range: range)
        XCTAssertEqual(result1, 0.3)
        XCTAssertEqual(params.get("duration"), 0.3)

        // 低于下界，应该 clamp 到 0.2
        let result2 = params.setClamped("duration", 0.1, range: range)
        XCTAssertEqual(result2, 0.2)
        XCTAssertEqual(params.get("duration"), 0.2)

        // 高于上界，应该 clamp 到 0.5
        let result3 = params.setClamped("duration", 0.6, range: range)
        XCTAssertEqual(result3, 0.5)
        XCTAssertEqual(params.get("duration"), 0.5)
    }

    func testContains() {
        var params = TransitionParameters()

        // 未设置时不包含
        XCTAssertFalse(params.contains("duration"))

        // 设置后包含
        params.set("duration", 0.5)
        XCTAssertTrue(params.contains("duration"))
    }

    func testRemove() {
        var params = TransitionParameters()

        // 设置参数
        params.set("duration", 0.5)
        XCTAssertTrue(params.contains("duration"))

        // 移除参数
        params.remove("duration")
        XCTAssertFalse(params.contains("duration"))
    }

    func testRemoveAll() {
        var params = TransitionParameters()

        // 设置多个参数
        params.set("duration", 0.5)
        params.set("intensity", 1.5)
        params.set("speed", 2.0)

        XCTAssertEqual(params.count, 3)

        // 移除所有
        params.removeAll()
        XCTAssertEqual(params.count, 0)
    }

    func testCodable() {
        var params = TransitionParameters()
        params.set("duration", 0.5)
        params.set("intensity", 1.5)

        // 编码
        let encoder = JSONEncoder()
        let data = try? encoder.encode(params)
        XCTAssertNotNil(data)

        // 解码
        let decoder = JSONDecoder()
        let decoded = try? decoder.decode(TransitionParameters.self, from: data!)
        XCTAssertNotNil(decoded)

        // 验证解码后的值
        XCTAssertEqual(decoded?.get("duration"), 0.5)
        XCTAssertEqual(decoded?.get("intensity"), 1.5)
    }
}
