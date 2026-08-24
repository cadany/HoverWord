import XCTest
@testable import HoverWord

/// 语言自动识别验证（NLLanguageRecognizer 封装策略）
///
/// 语料取自真实多语种词库（2026-08-23 实测校准）：
/// 多样本拼接可靠（fr/es/ja ≥0.90）、英语基础词表会误判（兜底 en）、
/// 释义列检测目标语种最稳。
final class LanguageDetectionServiceTests: XCTestCase {

    // MARK: - 源词列检测

    /// 法语样本 → fr
    func testFrenchSource() {
        let words = ["bonjour", "merci", "eau", "pain", "maison", "ami", "amour", "livre", "chat", "chien",
                     "fleur", "arbre", "soleil", "lune", "ciel", "mer", "montagne", "ville", "rue", "voiture"]
        XCTAssertEqual(LanguageDetectionService.sourceLanguage(from: words), "fr")
    }

    /// 西班牙语样本 → es
    func testSpanishSource() {
        let words = ["hola", "gracias", "agua", "pan", "casa", "amigo", "amor", "libro", "gato", "perro",
                     "flor", "árbol", "sol", "luna", "cielo", "mar", "montaña", "ciudad", "calle", "coche"]
        XCTAssertEqual(LanguageDetectionService.sourceLanguage(from: words), "es")
    }

    /// 日语样本（含假名，汉字+假名混排消歧）→ ja
    func testJapaneseSource() {
        let words = ["水", "パン", "家", "友達", "食べる", "飲む", "話す", "見る", "行く", "来る",
                     "する", "です", "持つ", "大きい", "小さい", "美しい", "学校", "仕事", "時間", "毎日"]
        XCTAssertEqual(LanguageDetectionService.sourceLanguage(from: words), "ja")
    }

    /// 英语高频基础词表（实测会被误判成印尼语等，置信度不足）→ 兜底 en
    func testEnglishBasicWordsFallback() {
        let words = ["water", "bread", "house", "friend", "love", "book", "cat", "dog", "flower", "tree",
                     "sun", "moon", "sky", "sea", "mountain", "city", "street", "car", "train", "airplane"]
        XCTAssertEqual(LanguageDetectionService.sourceLanguage(from: words), "en",
                       "英语基础词表检测不可靠，必须兜底 en")
    }

    // MARK: - 目标语检测

    /// 日文释义 → ja
    func testJapaneseMeanings() {
        let meanings = ["水", "パン", "家", "友達", "愛", "本", "猫", "犬", "花", "木",
                        "太陽", "月", "空", "海", "山", "都市", "通り", "車", "電車", "飛行機"]
        XCTAssertEqual(LanguageDetectionService.targetLanguage(from: meanings), "ja")
    }

    /// 英文释义 → en
    func testEnglishMeanings() {
        let meanings = ["hello", "thank you", "yes", "no", "water", "bread", "house", "friend", "love", "book",
                        "cat", "dog", "flower", "tree", "sun", "moon", "sky", "sea", "mountain", "city"]
        XCTAssertEqual(LanguageDetectionService.targetLanguage(from: meanings), "en")
    }

    // MARK: - 边界

    /// 空样本 → 无结果（调用方保持默认）
    func testEmptySamples() {
        XCTAssertNil(LanguageDetectionService.detect(from: []))
        XCTAssertNil(LanguageDetectionService.detect(from: ["", "  "]))
        // 空样本走兜底路径而非崩溃
        XCTAssertEqual(LanguageDetectionService.sourceLanguage(from: []), Constants.defaultSourceLang)
    }
}
