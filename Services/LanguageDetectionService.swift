import Foundation
import NaturalLanguage

/// 词本语言自动识别服务
///
/// 基于系统 NLLanguageRecognizer（NaturalLanguage 框架，离线、零第三方依赖）。
/// 实测策略（2026-08-23，真实多语种词库验证）：
/// - 单词检测不可靠（water→荷兰语、水→中文），须多样本拼接检测
/// - 释义列检测目标语种比源词列更稳（4/4 全对）
/// - 注音列不可参与（IPA 符号会把识别器带偏，如英语词+IPA→丹麦语），
///   由调用方保证只传源词列或释义列
/// - 置信度低于阈值回退默认值（英语基础词表会被误判成印尼语，en 兜底恰好覆盖）
class LanguageDetectionService {

    /// 检测结果
    struct DetectionResult {
        /// BCP-47 语言代码（与 sourceLang/targetLang 存储同构，如 "en"/"zh-Hans"）
        let language: String
        /// 置信度 0-1
        let confidence: Double
    }

    /// 对文本样本做语言检测（拼接全部样本送检）
    ///
    /// - Parameter samples: 词条文本数组（源词列或释义列，不含注音）
    /// - Returns: 检测结果；样本为空或识别器无结果返回 nil
    static func detect(from samples: [String]) -> DetectionResult? {
        let text = samples
            .prefix(Constants.languageDetectionSampleCount)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !text.isEmpty else { return nil }

        let recognizer = NLLanguageRecognizer()
        // 候选约束到注册表语种：小词汇量/重复样本会带置信度地误判到注册表外
        // 语种（如实测 4 词循环的英语释义被判成丹麦语），约束后噪声语种被排除
        recognizer.languageConstraints = Constants.supportedWordLanguages
            .compactMap { NLLanguage(rawValue: $0) }
        recognizer.processString(text)
        guard let dominant = recognizer.dominantLanguage else { return nil }

        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        let confidence = hypotheses[dominant] ?? 0
        return DetectionResult(language: dominant.rawValue, confidence: confidence)
    }

    /// 按检测结果解析源语言，低置信度/无结果回退默认值
    static func sourceLanguage(from samples: [String]) -> String {
        guard let result = detect(from: samples),
              result.confidence >= Constants.languageDetectionConfidenceThreshold else {
            return Constants.defaultSourceLang
        }
        return result.language
    }

    /// 按检测结果解析目标语言，低置信度/无结果回退默认值
    static func targetLanguage(from samples: [String]) -> String {
        guard let result = detect(from: samples),
              result.confidence >= Constants.languageDetectionConfidenceThreshold else {
            return Constants.defaultTargetLang
        }
        return result.language
    }
}
