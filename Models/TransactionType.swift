import Foundation

/// 交易类型枚举
enum TransactionType: String, Codable {
    case income      // 收入
    case expense     // 支出
    case excluded    // 不计入
}
